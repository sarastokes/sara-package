classdef BarCenteringFigure < symphonyui.core.FigureHandler
    % 10Jul2017 - SSP - created
    
    properties (SetAccess = private)
        % required
        device
        preTime
        stimTime
        temporalFrequency
        % optional:
        onlineAnalysis
    end
    
    properties (Access = private)
        % stores all the UI handles
        handles
        % keep track of the epochs
        epochNum
        % store the F1, F2 etc
        cellData        
        % this is pulled from epoch.parameters
        searchAxis
    end
    
    properties (Constant)
        RES = {'F1', 'F2', 'P1', 'P2'}
        DEMOMODE = false
        BINRATE = 60
    end
    
    methods
        function obj = BarCenteringFigure(device, preTime, stimTime, temporalFrequency, varargin)
            obj.device = device;
            obj.preTime = preTime;
            obj.stimTime = stimTime;
            obj.temporalFrequency = temporalFrequency;
            
            ip = inputParser();
            ip.addParameter('onlineAnalysis', 'spikes', @(x)ischar(x));
            ip.parse(varargin{:});
            obj.onlineAnalysis = ip.Results.onlineAnalysis;
            
            obj.epochNum = 0;
            
            obj.cellData = struct();
            obj.cellData.xpts = [];
            obj.cellData.ypts = [];
            obj.handles.upsampy = [];
            obj.handles.upsampy = [];
            for ii = 1:length(obj.RES)
                obj.cellData.([obj.RES{ii}, 'X']) = [];
                obj.cellData.([obj.RES{ii}, 'Y']) = [];
                obj.handles.(lower([obj.RES{ii}, 'x'])) = [];
                obj.handles.(lower([obj.RES{ii}, 'y'])) = [];
            end
            
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle, 'Color', 'w',...
                'Name', 'Bar Centering Figure');

            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

            pcolorButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'interpolate & pcolor',...
                'ClickedCallback', @obj.onSelected_interpolate);
            setIconImage(pcolorButton, [iconDir, 'pcolor.png']);
            
            surfButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'interpolate & surf',...
                'ClickedCallback', @obj.onSelected_interpolate);
            setIconImage(surfButton, [iconDir, 'surf.png']);
            
            sendButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'send to workspace',...
                'ClickedCallback', @obj.onSelected_sendButton);
            setIconImage(sendButton, [iconDir, 'send.png']);
            
            interpXButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'x',...
                'ClickedCallback', @obj.onSelected_peakInterp);
            setIconImage(interpXButton, [iconDir, 'alien.png']);

            interpYButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'y',...
                'ClickedCallback', @obj.onSelected_peakInterp);
            setIconImage(interpYButton, [iconDir, 'alien.png']);
            
            % Layouts
            mainLayout = uix.HBox('Parent', obj.figureHandle);
            f1Layout = uix.VBox('Parent', mainLayout);
            f2Layout = uix.VBox('Parent', mainLayout);
            
            % X-axis plots
            obj.handles.F1X = axes('Parent', f1Layout);
            title(obj.handles.F1X, 'X-axis centering');
            ylabel(obj.handles.F1X, 'spikes/sec');
            
            obj.handles.P1X = axes('Parent', f1Layout,...
                'YLim', [-180 180]);
            xlabel(obj.handles.P1X, 'position (um)');
            ylabel(obj.handles.P1X, 'phase');
            
            % Y-axis plots
            obj.handles.F1Y = axes('Parent', f2Layout);
            title(obj.handles.F1Y, 'Y-axis centering');
            ylabel(obj.handles.F1Y, 'spikes/sec');
            
            obj.handles.P1Y = axes('Parent', f2Layout,...
                'YLim', [-180 180]);
            xlabel(obj.handles.P1Y, 'position (um)');
            ylabel(obj.handles.P1Y, 'phase');
            
            % Receptive field plot
            obj.handles.im = axes('Parent', mainLayout);
            xlabel(obj.handles.im, 'x-axis');
            ylabel(obj.handles.im, 'y-axis');
            axis(obj.handles.im, 'square');
            
            % Display settings
            set(findall(obj.figureHandle, 'Type', 'uipushtool'),...
                'Separator', 'on');
            set(findall(obj.figureHandle, 'Type', 'axes'),...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            set(findall(obj.figureHandle, 'Type', 'uix.Box'),...
                'BackgroundColor', 'w');

            % Layout sizing
            set(f1Layout, 'Heights', [-2 -1]);
            set(f2Layout, 'Heights', [-2 -1]);
            set(mainLayout, 'Widths', [-1 -1 -0.5]);
        end % createUi

        function handleEpoch(obj, epoch)
            
            obj.epochNum = obj.epochNum + 1;
            
            % get the response
            response = epoch.getResponse(obj.device);
            epochResponse = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            if strcmp(obj.onlineAnalysis, 'spikes')
                epochResponse = wavefilter(epochResponse(:)', 6);
                S = spikeDetectorOnline(epochResponse);
                spikesBinary = zeros(size(epochResponse));
                spikesBinary(S.sp) = 1;
                epochResponse = spikesBinary * sampleRate;
            end
            
            responseTrace = epochResponse(obj.preTime/1000*sampleRate+1 : end);
            
            binWidth = sampleRate / obj.BINRATE; % Bin at 60 Hz.
            numBins = floor(obj.stimTime/1000 * obj.BINRATE);
            binData = zeros(1, numBins);
            for k = 1 : numBins
                index = round((k-1)*binWidth+1 : k*binWidth);
                binData(k) = mean(responseTrace(index));
            end
            binsPerCycle = obj.BINRATE / obj.temporalFrequency;
            numCycles = floor(length(binData)/binsPerCycle);
            cycleData = zeros(1, floor(binsPerCycle));
            
            for k = 1 : numCycles
                index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
                cycleData = cycleData + binData(index);
            end
            cycleData = cycleData / k;
            ft = fft(cycleData);
            
            % update the plots and cellData
            obj.searchAxis = epoch.parameters('searchAxis');
            switch obj.searchAxis
                case 'xaxis'
                    obj.cellData.xpts = [obj.cellData.xpts,...
                        epoch.parameters('position')];
                    obj.cellData.F1X = cat(2, obj.cellData.F1X,...
                        abs(ft(2))/length(cycleData*2));
                    obj.cellData.F2X = cat(2, obj.cellData.F2X,... 
                        abs(ft(3))/length(cycleData*2));
                    obj.cellData.P1X = cat(2, obj.cellData.P1X,...
                        angle(ft(2)) * 180/pi);
                    obj.cellData.P2X = cat(2, obj.cellData.P2X,...
                        angle(ft(3)) * 180/pi);
                    
                    for ii = 1:length(obj.RES)
                        ind = sprintf('%sX', obj.RES{ii});
                        if isempty(obj.handles.(lower(ind)))
                            ind2 = ind; ind2(2) = '1';
                            obj.handles.(lower(ind)) = line(...
                                'Parent', obj.handles.(ind2),...
                                'XData', obj.cellData.xpts,...
                                'YData', obj.cellData.(ind),...
                                'Color', obj.getColor(obj.RES{ii}),...
                                'Marker', 'o',...
                                'LineWidth', obj.getLW(obj.RES{ii}));
                        else
                            set(obj.handles.(lower(ind)),...
                                'XData', obj.cellData.xpts,...
                                'YData', obj.cellData.(ind));
                        end
                    end
                case 'yaxis'
                    obj.cellData.ypts = [obj.cellData.ypts,...
                        epoch.parameters('position')];
                    obj.cellData.F1Y = cat(2, obj.cellData.F1Y,...
                        abs(ft(2))/length(cycleData*2));
                    obj.cellData.F2Y = cat(2, obj.cellData.F2Y,...
                        abs(ft(3))/length(cycleData*2));
                    obj.cellData.P1Y = cat(2, obj.cellData.P1Y,...
                        angle(ft(2)) * 180/pi);
                    obj.cellData.P2Y = cat(2, obj.cellData.P2Y,...
                        angle(ft(3)) * 180/pi);
                    
                    for ii = 1:length(obj.RES)
                        ind = sprintf('%sY', obj.RES{ii});
                        if isempty(obj.handles.(lower(ind)))
                            ind2 = ind; ind2(2) = '1';
                            obj.handles.(lower(ind)) = line(...
                                'Parent', obj.handles.(ind2),...
                                'XData', obj.cellData.ypts,...
                                'YData', obj.cellData.(ind),...
                                'Color', obj.getColor(obj.RES{ii}),...
                                'Marker', 'o',...
                                'LineWidth', obj.getLW(obj.RES{ii}));
                        else
                            set(obj.handles.(lower(ind)),...
                                'XData', obj.cellData.ypts,...
                                'YData', obj.cellData.(ind));
                        end
                    end
            end
        end % handleEpoch
    end % methods
    
    methods
        function onSelected_peakInterp(obj, src, ~)
            % PEAKINTERP  Upsample data points and return the peak
            ind = src.TooltipString;
            f = sprintf('f1%s', ind);
            
            x = obj.handles.(f).XData;
            y = obj.handles.(f).YData;
            upsampX = 5 * numel(x);
            upsampY = interp1(x, y, upsampX, 'spline');
            pk = max(upsampY);
            title(obj.handles.(f), '%s-axis peak = %u',... 
                ind, pk);
            fprintf('%s - peak for %s axis is %u\n',... 
                datestr(now), ind, pk);
            obj.handles.(['upsamp' ind]) = line(...
                'Parent', obj.handles.(f),...
                'XData', upsampX,...
                'YData', upsampY,...
                'Color', [0 0.8 0.3],...
                'LineWidth', 1);
        end
        
        function onSelected_interpolate(obj, src, ~)
            x = [obj.handles.f1x.XData, zeros(size(obj.handles.f1y.XData))];
            y = [zeros(size(obj.handles.f1x.XData)), obj.handles.f1y.XData];
            
            scInt = scatteredInterpolant(x', y',...
                [obj.handles.f1x.YData obj.handles.f1y.YData]');
            
            [newX, newY] = meshgrid(linspace(min(x), max(x), 100),...
                linspace(min(y), max(y), 100));
            
            newMap = scInt(newX, newY);
            
            switch src.TooltipString
                case 'interpolate & pcolor'
                    im = pcolor(obj.handles.im, newMap);
                case 'interpolate & surf'
                    im = surf(obj.handles.im, newMap);
                    zlabel('spikes/sec');
            end

            shading(obj.handles.im, 'interp');  
            colormap(obj.handles.im, 'viridis');

            set(obj.handles.im,...
                'XTick', obj.handles.f1x.XData,...
                'XTickLabel', obj.handles.f1x.XData,...
                'YTick', obj.handles.f1y.XData,...
                'YTickLabel', obj.handles.f1y.XData);
        end
        
        function onSelected_sendButton(obj, ~, ~)
            outputStruct.cellData = obj.cellData;
            outputStruct.handles = obj.handles;
            answer = inputdlg('Send to workspaces as: ',...
                'Variable name dialog', 1, {'r'});
            assignin('base', sprintf('%s', answer{1}), outputStruct);
            fprintf('%s - figure data sent as %s',...
                datestr(now), answer{1});
        end
    end
    
    methods (Static)
        function co = getColor(res)
            switch res
                case {'F1', 'P1'}
                    co = 'k';
                otherwise
                    co = [0.5 0.5 0.5];
            end
        end
        
        function lw = getLW(res)
            switch res
                case {'F1', 'P1'}
                    lw = 1.5;
                otherwise
                    lw = 1;
            end
        end
    end
end
