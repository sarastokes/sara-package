classdef BarCenteringFigure < symphonyui.core.FigureHandler
    % 10Jul2017 - SSP - created
    
    properties (SetAccess = private)
        % required
        device
        preTime
        stimTime
        temporalFrequency
        % optional:
        recordingType
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
    end
    
    methods
        function obj = BarCenteringFigure(device, preTime, stimTime, temporalFrequency, varargin)
            obj.device = device;
            obj.preTime = preTime;
            obj.stimTime = stimTime;
            obj.temporalFrequency = temporalFrequency;
            
            ip = inputParser();
            ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            
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
        end % constructor
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle, 'Color', 'w',...
                'Name', 'Bar Centering Figure');
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            pcolorButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'interpolate & pcolor',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelected_interpolate);
            setIconImage(pcolorButton, [iconDir, 'pcolor.png']);
            
            surfButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'interpolate & surf',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelected_interpolate);
            setIconImage(surfButton, [iconDir, 'surf.png']);
            
            sendButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'send to workspace',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelected_sendButton);
            setIconImage(sendButton,...
                symphonyui.app.App.getResource('icons', 'modules.png'));
            
            interpXButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'x',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelected_peakInterp);
            setIconImage(interpXButton,...
                symphonyui.app.App.getResource('icons', 'modules.png'));
            interpYButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'y',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelected_peakInterp);
            setIconImage(interpYButton,...
                symphonyui.app.App.getResource('icons', 'modules.png'));  
            
            
            mainLayout = uix.HBox('Parent', obj.figureHandle);
            f1Layout = uix.VBox('Parent', mainLayout);
            f2Layout = uix.VBox('Parent', mainLayout);
            
            obj.handles.F1X = axes('Parent', f1Layout,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            title(obj.handles.F1X, 'X-axis centering');
            ylabel(obj.handles.F1X, 'spikes/sec');
            
            obj.handles.P1X = axes('Parent', f1Layout,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'YLim', [-180 180],...
                'XTickMode', 'auto');
            xlabel(obj.handles.P1X, 'position (um)');
            ylabel(obj.handles.P1X, 'phase');
            set(f1Layout, 'Heights', [-2 -1]);
            
            obj.handles.F1Y = axes('Parent', f2Layout,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            title(obj.handles.F1Y, 'Y-axis centering');
            ylabel(obj.handles.F1Y, 'spikes/sec');
            
            obj.handles.P1Y = axes('Parent', f2Layout,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto',...
                'YLim', [-180 180]);
            xlabel(obj.handles.P1Y, 'position (um)');
            ylabel(obj.handles.P1Y, 'phase');
            set(f2Layout, 'Heights', [-2 -1]);
            
            obj.handles.im = axes('Parent', mainLayout,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            xlabel(obj.handles.im, 'x-axis');
            ylabel(obj.handles.im, 'y-axis');
            axis(obj.handles.im, 'square');
            
            set(mainLayout, 'Widths', [-1 -1 -0.5]);
        end % createUi
        
        function handleEpoch(obj, epoch)
            
            obj.epochNum = obj.epochNum + 1;
            
            % get the response
            response = epoch.getResponse(obj.device);
            epochResponse = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            if strcmp(obj.recordingType, 'extracellular')
                epochResponse = wavefilter(epochResponse(:)', 6);
                S = spikeDetectorOnline(epochResponse);
                spikesBinary = zeros(size(epochResponse));
                spikesBinary(S.sp) = 1;
                epochResponse = spikesBinary * sampleRate;
            end
            
            responseTrace = epochResponse(obj.preTime/1000*sampleRate+1 : end);
            
            binRate = 60;
            binWidth = sampleRate / binRate; % Bin at 60 Hz.
            numBins = floor(obj.stimTime/1000 * binRate);
            binData = zeros(1, numBins);
            for k = 1 : numBins
                index = round((k-1)*binWidth+1 : k*binWidth);
                binData(k) = mean(responseTrace(index));
            end
            binsPerCycle = binRate / obj.temporalFrequency;
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
            obj.searchAxis = obj.searchAxis;
            switch obj.searchAxis
                case 'xaxis'
                    obj.cellData.xpts = [obj.cellData.xpts, obj.umPerPix(epoch.parameters('position'))];
                    obj.cellData.F1X = cat(2, obj.cellData.F1X, abs(ft(2))/length(cycleData*2));
                    obj.cellData.F2X = cat(2, obj.cellData.F2X, abs(ft(3))/length(cycleData*2));
                    obj.cellData.P1X = cat(2, obj.cellData.P1X, angle(ft(2)) * 180/pi);
                    obj.cellData.P2X = cat(2, obj.cellData.P2X, angle(ft(3)) * 180/pi);
                    % 			end
                    
                    for ii = 1:length(obj.RES)
                        ind = sprintf('%sX', obj.RES{ii});
                        if isempty(obj.handles.(lower(ind)))
                            ind2 = ind; ind2(2) = '1';
                            obj.handles.(lower(ind)) = line('Parent', obj.handles.(ind2),...
                                'XData', obj.cellData.xpts, 'YData', obj.cellData.(ind),...
                                'Color', obj.getColor(obj.RES{ii}), 'Marker', 'o',...
                                'LineWidth', obj.getLW(obj.RES{ii}));
                        else
                            set(obj.handles.(lower(ind)),...
                                'XData', obj.cellData.xpts, 'YData', obj.cellData.(ind));
                        end
                    end
                case 'yaxis'
                    obj.cellData.ypts = [obj.cellData.ypts, obj.umPerPix(epoch.parameters('position'))];
                    obj.cellData.F1Y = cat(2, obj.cellData.F1Y, abs(ft(2))/length(cycleData*2));
                    obj.cellData.F2Y = cat(2, obj.cellData.F2Y, abs(ft(3))/length(cycleData*2));
                    obj.cellData.P1Y = cat(2, obj.cellData.P1Y, angle(ft(2)) * 180/pi);
                    obj.cellData.P2Y = cat(2, obj.cellData.P2Y, angle(ft(3)) * 180/pi);
                    
                    for ii = 1:length(obj.RES)
                        ind = sprintf('%sY', obj.RES{ii});
                        if isempty(obj.handles.(lower(ind)))
                            ind2 = ind; ind2(2) = '1';
                            obj.handles.(lower(ind)) = line('Parent', obj.handles.(ind2),...
                                'XData', obj.cellData.ypts, 'YData', obj.cellData.(ind),...
                                'Color', obj.getColor(obj.RES{ii}), 'Marker', 'o',...
                                'LineWidth', obj.getLW(obj.RES{ii}));
                        else
                            set(obj.handles.(lower(ind)),...
                                'XData', obj.cellData.ypts, 'YData', obj.cellData.(ind));
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
            % p = sprintf('p1%s', obj.searchAxis(1));
            
            x = obj.handles.(f).XData;
            y = obj.handles.(f).YData;
            upsampX = 5 * numel(x);
            upsampY = interp1(x, y, upsampX, 'spline');
            pk = max(upsampY);
            title(obj.handles.(f), '%s-axis peak = %u',... 
                ind, pk);
            fprintf('%s - peak for %s axis is %u\n',... 
                datestr(now), ind, pk);
            obj.handles.(['upsamp' ind]) = line('Parent', obj.handles.(f),...
                'XData', upsampX, 'YData', upsampY,...
                'Color', [0 0.8 0.3], 'LineWidth', 1);
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
            try
                shading(obj.handles.im, 'interp');
            catch
                shading(im, 'interp');
            end
            try
                colormap(obj.handles.im, 'viridis');
            catch
                colormap(im, 'viridis');
            end
            try
                set(obj.handles.im, 'XTick', obj.handles.f1x.XData, 'XTickLabel', obj.handles.f1x.XData,...
                'YTick', obj.handles.f1y.XData, 'YTickLabel', obj.handles.f1y.XData);
            catch
                fprintf('error in BarCenteringFigure line 288\n');
            end
        end % onSelected_interpolate
        
        function onSelected_sendButton(obj, ~, ~)
            outputStruct.cellData = obj.cellData;
            outputStruct.handles = obj.handles;
            answer = inputdlg('Send to workspaces as: ',...
                'Variable name dialog', 1, {'r'});
            assignin('base', sprintf('%s', answer{1}), outputStruct);
            fprintf('%s - figure data sent as %s', datestr(now), answer{1});
        end % onSelected_debugButton
    end % methods private
    
    methods (Static)
        function um = umPerPix(pix)
            % assuming it's 10x
            um = 0.8 * pix;
        end % umPerPix
        
        function co = getColor(res)
            switch res
                case {'F1', 'P1'}
                    co = 'k';
                otherwise
                    co = [0.5 0.5 0.5];
            end
        end % getColor
        
        function lw = getLW(res)
            switch res
                case {'F1', 'P1'}
                    lw = 1.5;
                otherwise
                    lw = 1;
            end
        end % get LW
    end % methods static
end % classdef
