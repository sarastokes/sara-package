classdef ResponseFigure < symphonyui.core.FigureHandler
    % 28Aug2017 - SSP - replaced ResponseWithStimFigure, added spike detect

    properties
        device
        stimTrace
        sweepColor
        stimColor
        storedSweepColor
        stimTitle
    end

    properties (Access = private)
        handles
        storedSweep
        detection = false
    end

    methods
        function obj = ResponseFigure(device, varargin)
            obj.device = device;

            ip = inputParser();
            addParameter(ip, 'stimTrace', [], @(x)isvector(x));
            addParameter(ip, 'sweepColor', 'k', @(x)ischar(x) || isvector(x));
            addParameter(ip, 'stimColor', 'k', @(x)ischar(x) || isvector(x));
            addParameter(ip, 'storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
            addParameter(ip, 'stimTitle', [], @(x)ischar(x));
            parse(ip, varargin{:});

            obj.stimTrace = ip.Results.stimTrace;
            obj.sweepColor = ip.Results.sweepColor;
            obj.storedSweepColor = ip.Results.storedSweepColor;
            obj.stimColor = ip.Results.stimColor;
            obj.stimTitle = ip.Results.stimTitle;

            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            storeSweepButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Store Sweep',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelectedStoreSweep);
            setIconImage(storeSweepButton,...
                symphonyui.app.App.getResource('icons', 'sweep_store.png'));

            spikeButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Detect Spikes',...
                'Separator', 'on',...
                'ClickedCallback', @obj.toggleDetection);
            setIconImage(spikeButton, [iconDir, 'spike.png']);

            obj.handles.ax.resp = subplot(4,1,1:3,...
                'Parent', obj.figureHandle,...
                'FontName', 'roboto',...
                'FontSize', 10,...
                'XTickMode', 'auto');
            xlabel(obj.handles.ax.resp, 'sec');


            if isempty(obj.stimTitle)
                obj.setTitle([obj.device.name ' Response']);
            else
                obj.setTitle(obj.stimTitle);
            end

            obj.handles.ax.stim = subplot(4,1,4,...
                'Parent', obj.figureHandle,...
                'FontName', 'Roboto',...
                'FontSize', 10,...
                'XTickMode', 'auto',...
                'XTick', [], 'XColor', 'w');


            set(obj.figureHandle,...
                'Name', 'Response Figure',...
                'Color', 'w');
        end

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.handles.ax.resp, t);
        end

        function clear(obj)
            cla(obj.handles.ax.resp); cla(obj.handles.ax.stim);
            obj.handles.resp = []; obj.handles.stim = [];
            obj.handles.spikes = [];
        end

        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end

            obj.handles.spikes = [];

            response = epoch.getResponse(obj.device);
            [quantities, units] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;

            if numel(quantities) > 0
                x = (1:numel(quantities)) / sampleRate;
                y = quantities;
            else
                x = [];
                y = [];
            end

            % plot sweep
            if isempty(obj.handles.resp)
                obj.handles.resp = line(x, y,...
                    'Parent', obj.handles.ax.resp,...
                    'Color', obj.sweepColor);
                c = uicontextmenu();
                uimenu(c, 'Label', 'Get Spikes',...
                    'Callback', @obj.spikesNow);
                obj.handles.resp.UiContextMenu = c;
            else
                set(obj.handles.resp, 'XData', x, 'YData', y);
            end
            ylabel(obj.handles.ax.resp, units,...
                'Interpreter', 'none');

            % detect spikes
            if obj.detection
                spikes = getSpikes(y);
                if isempty(obj.handles.spikes)
                    obj.handles.spikes = line(x, spikes,...
                        'Parent', obj.handles.ax.resp,...
                        'Color', 'b', 'Marker', 'o',...
                        'LineStyle', 'none');
                else
                    set(obj.handles.ax.spikes,...
                        'XData', x, 'YData', y);
                end
            end

            % plot stimuli
            if ~isempty(obj.stimTrace)
                if isempty(obj.handles.stim)
                    obj.handles.stim = line(x, stim,...
                        'Parent', obj.handles.ax.stim,...
                        'Color', obj.stimColor,...
                        'LineWidth', 1.5);
                else
                    set(obj.handles.stim, 'XData', x,...
                        'YData', obj.stimTrace);
                end
            end
            if y(1) == 0
                ylabel(obj.handles.ax.stim, 'Intensity');
            else
                ylabel(obj.handles.ax.stim, 'Contrast');
            end
        end % handleEpoch
    end % methods

    methods (Access = private) % Callback methods
        function toggleDetection(obj, ~, ~)
            % TOGGLEDETECTION  Change spike detection setting
            if obj.detection
                obj.detection = false;
                obj.handles.spikes = [];
            else
                obj.detection = true;
            end
        end % toggleDetection

        function onSelected_storeSweep(obj, ~, ~)
            % ONSELECTEDSTORESWEEP  Stores sweeps between figure calls
            if ~isempty(obj.storedSweep)
                delete(obj.storedSweep);
            end
            obj.storedSweep = copyobj(obj.sweep, obj.axesHandle);
            set(obj.storedSweep,...
                'Color', obj.storedSweepColor,...
                'HandleVisibility', 'off');
        end % onSelected_storeSweep

        function spikesNow(obj, ~, ~)
            % SPIKESNOW  Get spikes for currently displayed response
            spikes = getSpikes(get(obj.handles.resp, 'YData'));
            obj.handles.spikes = line('Parent', obj.handles.ax.resp,...
                'XData', get(obj.handles.resp, 'XData'),...
                'YData', spikes, 'Marker', 'o', 'Color', 'b',...
                'LineStyle', 'none');
        end % spikesNow
    end % methods

    methods (Static)
        function spikes = getSpikes(response)
            % GETSPIKES  SpikeDetectorOnline with hard coded sampleRate
            response = wavefilter(response(:)', 6);
            S = spikeDetectorOnline(response);
            spikesBinary = zeros(size(response));
            spikesBinary(S.sp) = 1;
            spikes = spikesBinary * 10000;
        end % getSpikes
    end % static methods
end % classdef
