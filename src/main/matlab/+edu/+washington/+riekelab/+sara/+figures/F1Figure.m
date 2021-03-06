classdef F1Figure < symphonyui.core.FigureHandler
    % TODO: clean this up
    
    properties (SetAccess = private)
        device
        xvals               % this is bar positions, spatialFreqs, radii, etc...
        onlineAnalysis
        preTime
        stimTime
        temporalFrequency   % don't pass if temporalFrequency = xvals
        plotColor
        numReps   % pass if numReps would ever be >1, otherwise numReps = 1
        waitTime
        titlestr
    end
    
    properties (Access = private)
        axesHandle
        sweep
        xaxis
        xpt
        sequence
        F1amp
        F1phase
        repsPerX
        epochNum
        fa
        pa
        fitParams
        fitHandle
    end

    properties (Constant = true, Hidden = true)
        BINRATE = 60
    end
    
    methods
        function obj = F1Figure(device, xvals, onlineAnalysis, preTime, stimTime, varargin)
            obj.device = device;
            obj.xvals = xvals;
            obj.onlineAnalysis = onlineAnalysis;
            obj.preTime = preTime;
            obj.stimTime = stimTime;
            
            ip = inputParser();
            ip.addParameter('temporalFrequency', [], @(x)ischar(x) || isvector(x));
            ip.addParameter('plotColor', [0 0 0], @(x)ischar(x) || isvector(x));
            ip.addParameter('numReps', 1, @(x)isnumeric(x) || isvector(x));
            ip.addParameter('waitTime', 0, @(x)isfloat(x));
            ip.addParameter('titlestr', [], @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.temporalFrequency = ip.Results.temporalFrequency;
            obj.waitTime = ip.Results.waitTime;
            obj.titlestr = ip.Results.titlestr;
            
            obj.numReps = ip.Results.numReps;
            obj.plotColor = zeros(2,3);
            obj.plotColor(1,:) = ip.Results.plotColor;
            obj.plotColor(2,:) = obj.plotColor(1,:) + (0.5 * (1-obj.plotColor(1,:)));
            
            ct = obj.xvals(:) * ones(1, obj.numReps);
            obj.sequence = sort(ct(:));
            
            obj.xaxis = unique(obj.sequence);
            % init f1 params
            obj.F1amp = zeros(size(obj.xvals));
            obj.F1phase = zeros(size(obj.xvals));
            
            obj.repsPerX = zeros(size(obj.xaxis));
            
            % epoch counter
            obj.epochNum = 0;
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            storeSweepButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Store Sweep', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedStoreSweep);
            setIconImage(storeSweepButton, symphonyui.app.App.getResource('icons/sweep_store.png'));
            switchAxisButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Switch axis',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelectedSwitchAxis);
            setIconImage(switchAxisButton, symphonyui.app.App.getResource('icons/sweep_store.png'));
            
            obj.axesHandle(1) = subplot(3,1,1:2,...
                'Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            ylabel(obj.axesHandle(1), 'f1 amp');
            
            obj.axesHandle(2) = subplot(4,1,4,...
                'Parent', obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            ylabel(obj.axesHandle(2), 'f1 phase');
            
            % for cone contrasts
            if abs(max(obj.xvals)) + abs(min(obj.xvals)) <= 2 || min(obj.xvals) < 0
                set(obj.axesHandle, 'XScale', 'linear');
            else
                set(obj.axesHandle, 'XScale', 'log');
            end
            
            set(obj.figureHandle, 'Color', 'w');
            if ~isempty(obj.titlestr)
                obj.setTitle(obj.titlestr);
            end
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandle(1), t);
        end
        
        function clear(obj)
            cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
            obj.F1amp = []; obj.F1phase = [];
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            obj.epochNum = obj.epochNum + 1;
            
            % handle protocols with changing temporal frequencies
            if isempty(obj.temporalFrequency)
                tempFreq = epoch.parameters('temporalFrequency');
            else
                tempFreq = obj.temporalFrequency;
            end
            
            response = epoch.getResponse(obj.device);
            responseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            responseTrace = edu.washington.riekelab.sara.util.processData(...
                responseTrace, obj.onlineAnalysis,...
                'preTime', obj.preTime, 'sampleRate', sampleRate);
            
            % Get the F1 amplitude and phase.
            responseTrace = responseTrace((obj.preTime+obj.waitTime)/1000*sampleRate+1 : end);
            binWidth = sampleRate / obj.BINRATE; % Bin at 60 Hz.
            numBins = floor((obj.stimTime-obj.waitTime)/1000 * obj.BINRATE);
            binData = zeros(1, numBins);
            for k = 1 : numBins
                index = round((k-1)*binWidth+1 : k*binWidth);
                binData(k) = mean(responseTrace(index));
            end
            binsPerCycle = obj.BINRATE / tempFreq;
            numCycles = floor(length(binData)/binsPerCycle);
            % catch error with temporal tuning curve protocol
            if numCycles == 0
                error('Make sure stimTime is long enough for at least 1 complete cycle');
            end
            cycleData = zeros(1, floor(binsPerCycle));
            for k = 1 : numCycles
                index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
                cycleData = cycleData + binData(index);
            end
            cycleData = cycleData / k;
            
            ft = fft(cycleData);
            
            f1amp = abs(ft(2))/length(ft)*2;
            f1phase = angle(ft(2)) * 180/pi;
            
            obj.F1amp(obj.epochNum) = f1amp;
            obj.F1phase(obj.epochNum) = f1phase;
            
            if isempty(obj.fa)
                obj.fa = line(obj.xaxis, obj.F1amp, 'parent', obj.axesHandle(1));
                set(obj.fa, 'Color', obj.plotColor(1,:), 'linewidth', 1, 'marker', 'o');
            else
                set(obj.fa, 'XData', obj.xaxis, 'YData', obj.F1amp);
                try
                    set(obj.axesHandle(1), 'XLim', [floor(min(obj.xaxis)) ceil(max(obj.xaxis))]);
                catch
                    set(obj.axesHandle(1), 'Xlim', [1 length(obj.F1amp)]);
                end
            end
            
            if isempty(obj.pa)
                obj.pa = line(obj.xaxis, obj.F1phase, 'parent', obj.axesHandle(2));
                set(obj.pa, 'Color', obj.plotColor(1,:), 'linewidth', 1, 'marker', 'o');
            else
                set(obj.pa, 'XData', obj.xaxis, 'YData', obj.F1phase);
            end
            try
                set(obj.axesHandle(2), 'XLim', [floor(min(obj.xaxis)) ceil(max(obj.xaxis))]);
            catch
                set(obj.axesHandle(2), 'XLim', [1 length(obj.F1amp)]);
            end
            
        end
    end
    
    methods (Access = private)
        function onSelectedStoreSweep(obj,~,~)
            outputStruct.F1 = obj.F1amp;
            outputStruct.P1 = obj.F1phase;
            answer = inputdlg('Save to workspace as:', 'save dialog', 1, {'r'});
            fprintf('%s new F1 data named %s\n', datestr(now), answer{1});
            assignin('base', sprintf('%s', answer{1}), outputStruct);
        end
        
        function onSelectedSwitchAxis(obj,~,~)
            if strcmp(get(obj.axesHandle(1), 'YScale'), 'log');
                set(findobj(obj.figureHandle, 'Type', 'axes'),...
                    'YScale', 'linear')
            else
                set(findobj(obj.figureHandle, 'Type', 'axes'),...
                    'YScale', 'log');
            end
        end
        
        
    end % methods
end % classdef
