classdef ConeFilterFigure < symphonyui.core.FigureHandler
    %
    properties (SetAccess = private)
        % required:
        device
        filtWheel
        frameMonitor
        preTime
        stimTime
        stDev
        % optional:
        recordingType
        frameDwell
        frameRate
    end
    
    properties
        % contains all UI handles
        handles
        
        % keeps track epochs
        epochNum
        
        % analysis is stored here
        cellData
        
        % currentCone as number
        coneInd % current cone as #
        
        nextStimulus % holds future parameters
        nextCone % a list of next chromaticClass
        nextStimTime % how long the next stim will be
        
        % protocol control properties
        ignoreNextEpoch = false
        addNullEpoch = false
        ledNeedsToChange = false
        protocolShouldStop = false
    end
    
    properties (Constant)
        % how long the null epochs should run for
        NULLTIME = 500
        
        % not really worth making an editable parameter right now
        BINSPERFRAME = 6
        FILTERLENGTH = 1000
        
        % green LED code is potentially problematic. option to disable
        LEDMONITOR = true
        
        % cone options.. might add LM-iso at some point
        CONES = 'lmsa'
        
        % generate some fake filters + NLs for debugging
        DEMOMODE = false
        DEMOGAUSS = false
    end
    
    
    methods
        function obj = ConeFilterFigure(device, frameMonitor, filtWheel, preTime, stimTime, varargin)
            obj.device = device;
            obj.frameMonitor = frameMonitor;
            obj.filtWheel = filtWheel;
            obj.preTime = preTime;
            obj.stimTime = stimTime;
            
            ip = inputParser();
            ip.addParameter('stDev', 0.3, @(x)isnumeric(x));
            ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
            ip.addParameter('frameDwell', 1, @(x)isnumeric(x));
            ip.addParameter('frameRate', 60, @(x)isnumeric(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.frameDwell = ip.Results.frameDwell;
            obj.frameRate = ip.Results.frameRate;
            obj.stDev = ip.Results.stDev;
            
            obj.epochNum = 0;
            
            obj.createUi();
            
            obj.cellData.filterMap = containers.Map;
            obj.cellData.xnlMap = containers.Map;
            obj.cellData.ynlMap = containers.Map;
            
            % set to zero which flags new cone type
            for ii = 1:length(obj.CONES)
                obj.cellData.filterMap(obj.CONES(ii)) = 0;
                obj.cellData.xnlMap(obj.CONES(ii)) = 0;
                obj.cellData.ynlMap(obj.CONES(ii)) = 0;
            end
            % this figure controls two protocol parameters:
            obj.nextStimulus.cone = [];
            obj.nextStimulus.stimTime = [];
            
            % this waits until more stimuli are added to the queue
            obj.waitIfNecessary();
            
            if ~isvalid(obj)
                fprintf('Not valid object\n');
                return;
            end
            
            % this runs at the very end of each epoch, sets the next epoch
            obj.assignNextStimulus();
            
            % reflect in the ui
            obj.updateUi();
        end % constructor
        
        function createUi(obj)
            import appbox.*;
            
            % toolbar
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            
            debugButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'send obj to wkspace',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelected_debugButton);
            setIconImage(debugButton, symphonyui.app.App.getResource('icons', 'modules.png'));
            
            set(obj.figureHandle, 'Name', 'Cone Filter Figure',...
                'Color', 'w',...
                'NumberTitle', 'off');
            
            % basic layouts
            mainLayout = uix.HBox('Parent', obj.figureHandle);
            resultLayout = uix.VBox('Parent', mainLayout);
            plotLayout = uix.HBoxFlex('Parent', resultLayout);
            dataLayout = uix.HBox('Parent', resultLayout);
            uiLayout = uix.VBox('Parent', mainLayout);
            set(mainLayout, 'Widths', [-4 -1]);
            
            % axes:
            obj.handles.ax.lf = axes('Parent', plotLayout,...
                'XTickMode', 'auto',...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            xlabel(obj.handles.ax.lf, 'Time (ms)');
            title(obj.handles.ax.lf, 'Linear Filter');
            obj.handles.ax.nl = axes('Parent', plotLayout,...
                'XTickMode', 'auto',...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            set(plotLayout, 'Widths', [-1.5 -1]);
            xlabel(obj.handles.ax.nl, 'Linear prediction');
            ylabel(obj.handles.ax.nl, 'Meaured');
            title(obj.handles.ax.nl, 'Noninearity');
            
            % data table
            obj.handles.dataTable = uitable('Parent', dataLayout);
            set(obj.handles.dataTable, 'Data', zeros(4,4),...
                'ColumnName', {'N','T2P', 'ZC', 'BI'},...
                'RowName', {'L', 'M', 'S', 'A'},...
                'ColumnEditable', false);
            
            paramLayout = uix.VBox('Parent', dataLayout,...
                'Spacing', 5, 'Padding', 5);
            xlimLayout = uix.HBox('Parent', paramLayout);
            
            obj.handles.pb.changeXLim = uicontrol('Parent', xlimLayout,...
                'Style', 'push',...
                'String', 'Change xlim',...
                'Callback', @obj.onSelected_changeXLim);
            obj.handles.ed.changeXLim = uicontrol('Parent', xlimLayout,...
                'Style', 'edit',...
                'String', '1000');
            set(xlimLayout, 'Widths', [-3 -1]);
            
            smoothLayout = uix.HBox('Parent', paramLayout);
            obj.handles.cb.smoothFilt = uicontrol('Parent', smoothLayout,...
                'String', 'Smooth filters',...
                'Style', 'checkbox',...
                'Callback', @obj.onSelected_smoothFilt);
            obj.handles.ed.smoothFac = uicontrol('Parent', smoothLayout,...
                'Style', 'edit',...
                'String', '0');
            set(smoothLayout, 'Widths', [-3 -1]);
            
            obj.handles.cb.normPlot = uicontrol('Parent', paramLayout,...
                'String', 'Normalize',...
                'Style', 'checkbox',...
                'Callback', @obj.onSelected_normPlot);
            
            % init some plot flags
            obj.handles.flags.smoothFilt = false;
            obj.handles.flags.normPlot = false;
            
            set(paramLayout, 'Heights', [-1 -1 -1]);
            set(resultLayout, 'Heights', [-1.5 -1]);
            set(dataLayout, 'Widths', [-2 -1]);
            
            % display edit boxes
            uicontrol('Parent', uiLayout,...
                'Style', 'text',...
                'String', 'Stimulus queue:');
            obj.handles.tx.queue = uicontrol('Parent', uiLayout,...
                'Style', 'text',...
                'String', '');
            obj.handles.ed.queue = uicontrol('Parent', uiLayout,...
                'Style', 'edit',...
                'String', '');
            obj.handles.pb.addToQueue = uicontrol('Parent', uiLayout,...
                'Style', 'push',...
                'String', 'UpdateQueue',...
                'Callback', @obj.onSelected_updateQueue);
            obj.handles.pb.clearQueue = uicontrol('Parent', uiLayout,...
                'Style', 'push',...
                'String', 'Clear queue',...
                'Callback', @obj.onSelected_clearQueue);
            
            % protocol displays
            obj.handles.tx.curEpoch = uicontrol('Parent', uiLayout,...
                'Style', 'text',...
                'String', 'Current Epoch: -');
            obj.handles.tx.nextEpoch = uicontrol('Parent', uiLayout,...
                'Style', 'text',...
                'String', 'Next Epoch: -');
            % protocol control buttons
            uicontrol('Parent', uiLayout,...
                'Style', 'push',...
                'String', 'Resume Protocol',...
                'Callback', @(a,b) obj.resumeProtocol());
        end % createUi
        
        function handleEpoch(obj, epoch)
            % basic plan: each epoch gets a newFilter which is added to existing filters in cellData
            if obj.ignoreNextEpoch
                disp('ignoring epoch');
                epoch.shouldBePersisted = false;
                obj.assignNextStimulus();
                obj.ignoreNextEpoch = false;
                return;
            end
            
            obj.epochNum = obj.epochNum + 1;
            cone = epoch.parameters('coneClass');
            fprintf('figure - handleEpoch - protocol saved %s\n', cone);
            
            %% ANALYSIS ---------------------------------------------
            if obj.DEMOMODE
                % make a fake filter
                pts = linspace(-1, 1, obj.BINSPERFRAME * obj.frameRate + 1);
                newFilter = diff(normpdf(pts, 0, (0.1*obj.coneInd)));
                % add some variability so they aren't overlapping
                newFilter = ((0.1*obj.coneInd) * randi(10)) .* newFilter;
                % make it an M-center OFF cell
                if obj.coneInd == 2 || obj.coneInd == 4
                    newFilter = -1 * newFilter;
                end
                xpts = 1:length(newFilter);
                
                % make a fake nonlinearity
                yBin = normcdf(pts, 0, (0.1*obj.coneInd));
                xBin = pts;
            else % use actual spikes
                if obj.DEMOGAUSS
                    load('C:\Users\Sara Patterson\Documents\MATLAB\demoGauss.mat')
                    epochResponseTrace = demoGauss.resp(obj.epochNum, :);
                    currentNoiseSeed = demoGauss.seed(obj.epochNum);
                    sampleRate = 10000;
                else
                    % this is where the real linear filter analysis goes
                    response = epoch.getResponse(obj.device);
                    epochResponseTrace = response.getData();
                    sampleRate = response.sampleRate.quantityInBaseUnits;
                    currentNoiseSeed = epoch.parameters('seed');
                end
                prePts = sampleRate * obj.preTime/1000;

                numFrames = floor(obj.stimTime/1000 * obj.frameRate) / obj.frameDwell;
                
                binRate = obj.BINSPERFRAME * obj.frameRate;
                plotLngth = round(binRate*0.5);
                % numBins = floor(obj.stimTime/1000 * binRate);
                % binSize = sampleRate / binRate;
                % resp = zeros(1, numBins);
                resp = responseByType(epochResponseTrace, obj.recordingType, obj.preTime, sampleRate);
                
                % 			S = spikeDetectorOnline(epochResponseTrace);
                % 			spikeTimes = S.sp;
                % 			spikes = zeros(size(response));
                % 			spikes(spikeTimes) = 1;
                
                % data = spikes(obj.preTime/1000 * sampleRate+1:end);
                % bin the data
                resp = BinSpikeRate(resp(prePts+1:end), binRate, sampleRate);
                resp = resp(:)';
                fprintf('response is %u,%u\n',size(resp));
                
                % noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);
                % stimulus = obj.stDev * noiseStream.randn(1, numBins/obj.BINSPERFRAME);
                stimulus = getGaussianNoiseFrames(numFrames, obj.frameDwell, obj.stDev, currentNoiseSeed);
                
                if binRate > obj.frameRate
                    n = round(binRate / obj.frameRate);
                    stimulus = ones(n,1)*stimulus(:)';
                    stimulus = stimulus(:);
                end
                
                % 			if obj.BINSPERFRAME > 1
                % 					stimulus = ones(obj.BINSPERFRAME,1) * stimulus;
                % 					stimulus = stimulus(:)';
                %             end
                resp = resp(1 : length(stimulus));
                fprintf('stimulus is %u,%u\n', size(stimulus));
                
                % get rid of the first 0.5 sec
                stimulus(1:round(binRate/2)) = 0;
                resp(1:round(binRate/2)) = 0;
                
                newFilter = real(ifft(fft([resp(:)', zeros(1,60)]) .* conj(fft([stimulus(:)', zeros(1,60)]))));
                
                xpts = linspace(0, length(newFilter), obj.BINSPERFRAME * obj.frameRate);
                
            end % demo mode if
            
%% ------------------------------------------------------ store filter -----
            if obj.cellData.filterMap(cone) == 0
                obj.cellData.filterMap(cone) = newFilter;
                obj.handles.lf(obj.coneInd) = line('Parent', obj.handles.ax.lf,...
                    'XData', (1:plotLngth)/binRate, 'YData', newFilter(1:plotLngth),...
                    'Color', getPlotColor(cone), 'LineWidth', 1);
            else
                tmp = mean(obj.cellData.filterMap(cone), 1);
                obj.cellData.filterMap(cone) = [obj.cellData.filterMap(cone); newFilter];
                set(obj.handles.lf(obj.coneInd), 'YData', tmp(1:plotLngth));
            end
            
%% ------------------------------------------------------- nonlinearity ----
            if ~obj.DEMOMODE
                % Re-bin the response for the nonlinearity.
                resp = binData(resp, 60, binRate);
                size(fft([stimulus(:)', zeros(1,100)]))
                size(newFilter(:)')
                
                
                % Convolve stimulus with filter to get generator signal.
                try
                    pred = ifft(fft([stimulus(:)' zeros(1,60)]) .* fft(newFilter(:)'));
                    plotNL = true;
                    pred = binData(pred, 60, binRate);
                    pred = pred(:)';
                catch
                    plotNL = false;
                end
                
                
                
                % Get the binned nonlinearity.
            end % if not demomode
            if plotNL
                if obj.cellData.ynlMap(cone) == 0
                    if ~obj.DEMOMODE
                        obj.cellData.ynlMap(cone) = resp(:)';
                        obj.cellData.xnlMap(cone)  = pred(1:length(resp));
                        [xBin, yBin] = obj.getNL(obj.cellData.xnlMap(cone), obj.cellData.ynlMap(cone));
                    else
                        obj.cellData.xnlMap(cone) = xBin;
                        obj.cellData.ynlMap(cone) = yBin;
                    end
                    obj.handles.nl(obj.coneInd) = line('Parent', obj.handles.ax.nl,...
                        'XData', xBin, 'YData', yBin,...
                        'Color', getPlotColor(cone),...
                        'Marker', '.', 'LineStyle', 'none');
                else % existing
                    if ~obj.DEMOMODE
                        obj.cellData.xnlMap(cone) = [obj.cellData.xnlMap(cone), pred(1 : length(resp))];
                        obj.cellData.ynlMap(cone) = [obj.cellData.ynlMap(cone), resp(:)'];
                        [xBin, yBin] = obj.getNL(obj.cellData.xnlMap(cone), obj.cellData.ynlMap(cone));
                    else
                        obj.cellData.xnlMap(cone) = [obj.cellData.xnlMap(cone); xBin];
                        obj.cellData.ynlMap(cone) = [obj.cellData.ynlMap(cone); yBin];
                    end
                    set(obj.handles.nl(obj.coneInd),...
                        'XData', xBin, 'YData',yBin);
                end
            end
            
%% ----------------------------------------------------- filter stats ------
            % calculate time to peak, zero cross, biphasic index
            if abs(min(newFilter)) > max(newFilter)
                filterSign = -1;
                t = (newFilter > 0);
                t(1:find(newFilter == min(newFilter), 1)) = 0;
                t = find(t == 1, 1);
                if ~isempty(t)
                    zc = t/length(newFilter) * obj.FILTERLENGTH;
                else
                    zc = 0;
                end
            else
                filterSign = 1;
                t = (newFilter < 0);
                t(1:find(newFilter == max(newFilter), 1)) = 0;
                t = find(t == 1, 1);
                if ~isempty(t)
                    zc = t/length(newFilter) * obj.FILTERLENGTH;
                else
                    zc = 0;
                end
            end
            
            [loc, pk] = peakfinder(newFilter, [], [], filterSign);
            [~, ind] = max(abs(pk));
            try
                t2p = xpts(loc(ind));
            catch
                t2p = 0;
            end
            try
                bi = abs(min(newFilter)/max(newFilter));
            catch
                bi = 0;
            end
%% ------------------------------------------------------------ graphs -----
            % add to plots
            obj.updateFilterPlot();
            % send stats to the data table
            try
                obj.updateDataTable([t2p, zc, bi]);
            catch
                [t2p zc bi]
            end
            
%% ------------------------------------------------------------- stimuli ---
            obj.waitIfNecessary();
            
            if ~isempty(obj.nextStimulus.cone) && obj.LEDMONITOR
                obj.checkNextCone();
            end
            
            if ~isvalid(obj)
                return;
            end
            
            % set the next epoch's stimulus
            obj.assignNextStimulus();
            
            % reflect in the ui
            obj.updateUi();
        end % handleEpoch
        
%% -------------------------------------------------------------- callbacks ----
        function onSelected_normPlot(obj,~,~)
            if get(obj.handles.cb.normPlot, 'Value') == get(obj, 'Max')
                obj.handles.flags.normPlot = true;
            else
                obj.handles.flags.normPlot = false;
            end
            
            obj.updateFilterPlot();
        end % onChanged_normPlot
        
        function onSelected_smoothFilt(obj,~,~)
            if get(obj.handles.cb.smoothFilt, 'Value') == 1
                obj.handles.flags.smoothFilt = true;
                try
                    obj.handles.values.smoothFac = str2double(get(obj.handles.ed.smoothFac, 'String'));
                catch
                    warndlg('Check smooth factor, setting smoothFilt to false');
                    obj.handles.flags.smoothFilt = false;
                    set(obj.handles.cb.smoothFilt, 'Value', 0);
                    return;
                end
            else
                obj.handles.flags.smoothFilt = false;
            end
            
            obj.updateFilterPlot();
        end % onChanged_smoothFilt
        
        function onSelected_changeXLim(obj,~,~)
            % possibly just put this in updateFilterPlot()
            % not sure how much time this would even save...
            set(obj.handles.ax.lf, 'XLim',...
                [0 str2double(get(obj.handles.ed.changeXLim, 'String'))]);
        end % changeXLim
        
        function onSelected_updateQueue(obj,~,~)
            % appends to existing queue
            x = get(obj.handles.tx.queue, 'String');
            x = [x get(obj.handles.ed.queue, 'String')];
            set(obj.handles.tx.queue, 'String', x);
            obj.addStimuli(get(obj.handles.ed.queue, 'String'));
        end % updateQueue
        
        function onSelected_clearQueue(obj,~,~)
            obj.nextStimulus.cone = [];
            obj.nextStimulus.stimTime = [];
            obj.updateUi();
        end % clearQueue
        
%% ------------------------------------------------ main -----------
        function updateFilterPlot(obj)
            % this method applies smooth, normalize, etc to exisiting plot
            lines = findall(obj.handles.ax.lf, 'Type', 'line');
            % check for smooth plot
            if ~isempty(lines)
                if obj.handles.flags.smoothFilt
                    for ii = 1:numel(lines)
                        set(lines(ii), 'YData', smooth(lines(ii).YData, obj.smoothFac));
                    end
                end
                if obj.handles.flags.normPlot
                    for ii = 1:numel(lines)
                        set(lines(ii), 'YData', lines(ii).YData / max(abs(lines(ii).YData)));
                    end
                end
            end
        end % updateFilterPlot
        
        
        function updateDataTable(obj, stats)
            % stats should be [t2p zc bi]
            tableData = get(obj.handles.dataTable, 'Data');
            if tableData(obj.coneInd, 1) == 0
                for ii = 2:4
                    tableData(obj.coneInd, 2:4) = stats;
                end
            else
                for ii = 2:4
                    tableData(obj.coneInd, ii) = obj.stepMean(tableData(obj.coneInd, ii),...
                        tableData(obj.coneInd, 1), stats(1,ii-1));
                end
            end
            % update count after used for variables
            tableData(obj.coneInd, 1) = tableData(obj.coneInd, 1) + 1;
            
            set(obj.handles.dataTable, 'Data', tableData);
        end % updateDataTable
        
        function updateUi(obj)
            % this is called after the next stimulus has been assigned in handleEpoch
            if obj.ignoreNextEpoch
                obj.handles.tx.curEpoch.String = ['NULL - ' num2str(obj.nextStimTime) 's'];
            else
                obj.handles.tx.curEpoch.String = obj.nextCone;
            end
            
            % show the next stimulus
            if isempty(obj.nextStimulus.cone)
                obj.handles.tx.nextEpoch.String = 'no next stim!';
            else
                obj.handles.tx.nextEpoch.String = obj.nextStimulus.cone(1);
            end
            
            % update stimulus queue:
            % this will reflect epochNum + 2
            obj.handles.tx.queue.String = obj.nextStimulus.cone;
        end % updateUi
        
%% ------------------------------------------------------- support --------
        function clearFigure(obj)
            if obj.epochNum > 1
                obj.saveDlg();
            end
            obj.resetPlots();
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.cellData = [];
            obj.epochNum = 0;
            obj.protocolShouldStop = false;
            obj.nextStimulus.cone = [];
            obj.nextStimulus.stimTime = [];
        end % resetPlots
        
        function saveDlg(obj)
            selection = questdlg('Save the data?', 'Save dialog',...
                'Yes', 'No', 'Yes');
            if strcmp(selection, 'Yes')
                outputStruct = obj.cellData;
                answer = inputdlg('Send cellData to workspaces as: ',...
                    'Naming Dialog', 1, {'r'});
                assignin('base', sprintf('%s', answer{1}), outputStruct);
                fprintf('%s - figure data sent as %s', datestr(now), answer{1});
            end
        end % saveDlg
        
%% ------------------------------------------------ protocol --------
        function checkNextCone(obj)
            % this method will remind when the green LED needs to change
            
            obj.ledNeedsToChange = false;
            % get the filter wheel
            fw = obj.filtWheel;
            if ~isempty(fw)
                % get the current green LED setting
                greenLEDName = obj.filtWheel.getGreenLEDName();
                % check to see if it's compatible with currentCone
                % if not show a message box that pauses protocol
                if strcmp(greenLEDName, 'Green_505nm')
                    if ~strcmp(obj.nextStimulus.cone(1), 's')
                        obj.ledNeedsToChange = true;
                        msgbox('Change green LED to Green_570nm', 'LED monitor');
                        obj.waitForLED();
                        % fw.setGreenLEDName('Green_570nm');
                    end
                elseif strcmp(greenLEDName, 'Green_570nm')
                    if strcmp(obj.nextStimulus.cone(1), 's')
                        obj.ledNeedsToChange = true;
                        msgbox('Change green LED to Green_505nm', 'LED monitor');
                        obj.waitForLED();
                    end
                end
            end
        end % checkNextCone
        
        function addStimuli(obj, newCones)
            % TODO: some kind of input validation?
            % add to stimulus queue
            obj.nextStimulus.cone = [obj.nextStimulus.cone newCones];
            obj.nextStimulus.stimTime = obj.stimTime + zeros(size(obj.nextStimulus.cone));
            % reflect changes in the stimulus queue
            set(obj.handles.tx.queue, 'String', obj.nextStimulus.cone);
        end % addStimuli
        
        
        function assignNextStimulus(obj)
            % sets up the next epoch at the end of handleEpoch
            if obj.addNullEpoch
                disp('adding null epoch - no stimuli');
                obj.ignoreNextEpoch = true;
                obj.addNullEpoch = false;
                % add an extra stimulus with different stim time
                obj.nextStimulus.stimTime = [obj.NULLTIME, obj.nextStimulus.stimTime];
                obj.nextStimulus.cone = [obj.nextStimulus.cone(1), obj.nextStimulus.cone];
            elseif obj.ledNeedsToChange
                % keeping these two apart for now
                disp('adding null epoch - led change');
                obj.ignoreNextEpoch = true;
                obj.addNullEpoch = false;
                % add an extra stimulus with different stim time
                obj.nextStimulus.stimTime = [obj.NULLTIME, obj.nextStimulus.stimTime];
                obj.nextStimulus.cone = [obj.nextStimulus.cone(1), obj.nextStimulus.cone];
            else
                disp('adding normal epoch');
                obj.ignoreNextEpoch = false;
                obj.addNullEpoch = false;
            end
            
            % just chromatic class for now
            fprintf('figure - setting next cone to %s\n', obj.nextStimulus.cone(1));
            fprintf('figure - setting stim time to %u\n', obj.nextStimulus.stimTime(1));
            obj.nextCone = obj.nextStimulus.cone(1);
            obj.nextStimTime = obj.nextStimulus.stimTime(1);
            % set the coneInd
            obj.coneInd = strfind(obj.CONES, obj.nextCone);
            
            % move queue up
            obj.nextStimulus.cone(1) = [];
            obj.nextStimulus.stimTime(1) = [];
        end % assignNextStimulus
        
        function resumeProtocol(obj)
            if isempty(obj.nextStimulus.cone)
                disp('empty stimulus list');
            else
                uiresume(obj.figureHandle);
                set(obj.figureHandle, 'Name', 'Cone Filter Figure');
            end
        end % resumeProtocol
        
        function waitIfNecessary(obj)
            if isempty(obj.nextStimulus.cone)
                disp('waiting for input');
                set(obj.figureHandle, 'Name', 'Cone Filter Figure: PAUSED FOR STIM');
                obj.addNullEpoch = true;
                uiwait(obj.figureHandle);
            end
        end % waitIfNecessary
        
        function waitForLED(obj)
            disp('waiting for LED change');
            set(obj.figureHandle, 'Name', 'Cone Filter Figure: PAUSED FOR LED');
            obj.addNullEpoch = true;
            uiwait(obj.figureHandle);
        end % waitForLED
    end % methods
    
%% ------------------------------------------------ toolbar ------------
    methods (Access = private)
        function onSelected_debugButton(obj, ~, ~)
            outputStruct = obj;
            answer = inputdlg('Send to workspaces as: ',...
                'Debug Dialog', 1, {'r'});
            assignin('base', sprintf('%s', answer{1}), outputStruct);
            fprintf('%s - figure data sent as %s', datestr(now), answer{1});
        end % onSelected_debugButton
        
        % TODO: remove bad trace option, fit LMS
    end % methods private
    
    methods (Static)
        % random methods for convinience. slowly moving elsewhere
        function newMean = stepMean(prevMean, prevN, newValue)
            x = prevMean * prevN;
            newMean = (x + newValue)/(prevN + 1);
        end % stepMean
        
        function [xBin, yBin] = getNL(P, R)
            nlBins = 200; % maybe make constant parameter?
            [a, b] = sort(P(:));
            xSort = a;
            ySort = R(b);
            
            valsPerBin = floor(length(xSort) / nlBins);
            xBin = mean(reshape(xSort(1: nlBins*valsPerBin), valsPerBin, nlBins));
            yBin = mean(reshape(ySort(1: nlBins*valsPerBin), valsPerBin, nlBins));
        end % getNL
    end % methods static
end % classdef
