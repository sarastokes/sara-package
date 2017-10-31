classdef ResponseFigure < symphonyui.core.FigureHandler
    % 28Aug2017 - SSP - replaced ResponseWithStimFigure, added spike detect
    % 2Oct2017 - SSP - added spike detection features
    
    properties
        % Required:
        device
        % Optional
        stimTrace
        stimTitle
        
        sweepColor
        stimColor
        storedSweepColor
    end
    
    properties (Access = private)
        % Current response
        sweep
        stimSweep
        spikeSweep
        
        % Holds UI handles
        handles = struct();
        % T/F - detect and plot spikes
        detection = false;
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
            
            % ------------------------------------------------- toolbar ---
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
            
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            storeSweepButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Store Sweep',...
                'ClickedCallback', @obj.onSelectedStoreSweep);
            setIconImage(storeSweepButton,...
                symphonyui.app.App.getResource('icons', 'sweep_store.png'));
            
            clearSweepButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Clear Sweep',...
                'ClickedCallback', @obj.onSelectedClearSweep);
            setIconImage(clearSweepButton,...
                symphonyui.app.App.getResource('icons', 'sweep_clear.png'));
            
            spikeButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Detect Spikes',...
                'ClickedCallback', @obj.toggleDetection);
            setIconImage(spikeButton, [iconDir, 'spike.png']);
            
            % ------------------------------------------------- handles ---
            obj.handles.ax.resp = subplot(4,1,1:3,...
                'Parent', obj.figureHandle);
            xlabel(obj.handles.ax.resp, 'sec');
            
            if ~isempty(obj.stimTitle)
                obj.setTitle(obj.stimTitle);
            end
            
            obj.handles.ax.stim = subplot(4,1,4,...
                'Parent', obj.figureHandle,...
                'XTick', [], 'XColor', 'w', 'YLim', [0 1]);
            
            set(obj.figureHandle,...
                'Name', 'Response Figure',...
                'Color', 'w');
            
            set(findall(obj.figureHandle, 'Type', 'axes'),...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            set(findall(obj.figureHandle, 'Type', 'uipushtool'),...
                'Separator', 'on');
            
            obj.sweep = [];
            obj.spikeSweep = [];
            obj.stimSweep = [];
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.handles.ax.resp, t);
        end
        
        function clear(obj)
            cla(obj.handles.ax.resp);
            cla(obj.handles.ax.stim);
            obj.sweep = [];
            obj.spikeSweep = [];
            obj.stimSweep = [];
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            obj.spikeSweep = [];
            
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
            if isempty(obj.sweep)
                obj.sweep = line(x, y,...
                    'Parent', obj.handles.ax.resp,...
                    'Color', obj.sweepColor);
                c = uicontextmenu('Parent', obj.figureHandle);
                uimenu(c, 'Label', 'Get Spikes',...
                    'Callback', @obj.spikesNow);
                uimenu(c, 'Label', 'Remove Spikes',...
                    'Callback', @obj.rmSpikes);
                obj.sweep.UIContextMenu = c;
            else
                set(obj.sweep, 'XData', x, 'YData', y);
            end
            ylabel(obj.handles.ax.resp, units,...
                'Interpreter', 'none');
            
            % Detect the spikes
            if obj.detection
                spikes = obj.getSpikes(y);
                if isempty(obj.spikeSweep)
                    obj.spikeSweep = line(x, spikes,...
                        'Parent', obj.handles.ax.resp,...
                        'Color', 'b', 'Marker', 'o',...
                        'LineStyle', 'none');
                else
                    set(obj.handles.ax.spikes,...
                        'XData', x, 'YData', y);
                end
            end
            
            % Plot the stimuli
            if ~isempty(obj.stimTrace)
                xs = linspace(0, max(x), length(obj.stimTrace));
                if isempty(obj.stimSweep)
                    obj.stimSweep = line(...
                        'Parent', obj.handles.ax.stim,...
                        'XData', xs, 'YData', obj.stimTrace,...
                        'Color', obj.stimColor,...
                        'LineWidth', 1.5);
                else
                    set(obj.stimSweep,...
                        'XData', xs,...
                        'YData', obj.stimTrace);
                end
            end
            if y(1) == 0
                ylabel(obj.handles.ax.stim, 'Intensity');
            else
                ylabel(obj.handles.ax.stim, 'Contrast');
            end
        end
    end
    
    % Callback methods
    methods (Access = private)
        function toggleDetection(obj, src, ~)
            % TOGGLEDETECTION  Change spike detection setting
            if obj.detection
                obj.detection = false;
                set(src, 'TooltipString', 'Detect Spikes')
                obj.spikeSweep = [];
            else
                obj.detection = true;
                set(src, 'TooltipString', 'Stop Detecting Spikes');
            end
        end
        
        function onSelectedStoreSweep(obj, ~, ~)
            % ONSELECTEDSTORESWEEP  Calls method to store sweeps
            obj.storeSweep();
        end
        
        function onSelectedClearSweep(obj, ~, ~)
            % ONSELECTEDCLEARSWEEP  Calls method to clear sweeps
            obj.clearSweep();
        end
        
        function spikesNow(obj, ~, ~)
            % SPIKESNOW  Get spikes for currently displayed response
            [~, spikeTimes] = obj.getSpikes(get(obj.sweep, 'YData'));
            obj.spikeSweep = line('Parent', obj.handles.ax.resp,...
                'XData', obj.sweep.XData(spikeTimes),...
                'YData', ones(size(spikeTimes)),...
                'Marker', 'o',...
                'Color', 'b',...
                'LineStyle', 'none');
        end
        
        function rmSpikes(obj, ~, ~)
            % RMSPIKES Remove spikes from currently displayed response
            if ~isempty(obj.spikeSweep)
                obj.spikeSweep = [];
            end
        end
    end
    
    methods (Access = private)
        function clearSweep(obj)
            stored = obj.storedSweep();
            if ~isempty(stored)
                delete(stored.line);
            end
            
            obj.storedSweep([]);
        end
        
        function storeSweep(obj)
            obj.clearSweep();
            
            store = obj.sweep;
            if ~isempty(store)
                store.line = copyobj(obj.sweep.line, obj.handles.ax.resp);
                set(store.line, ...
                    'Color', obj.storedSweepColor, ...
                    'HandleVisibility', 'off');
            end
            obj.storedSweep(store);
        end
    end
    
    methods (Static)
        function sweep = storedSweep(sweep)
            % This method stores a sweep across figure handlers.
            persistent stored;
            if nargin > 0
                stored = sweep;
            end
            sweep = stored;
        end
        
        function [spikesBinary, spikeTimes] = getSpikes(response)
            % GETSPIKES  SpikeDetectorOnline with hard coded sampleRate
            response = wavefilter(response(:)', 6);
            S = spikeDetectorOnline(response);
            spikeTimes = S.sp;
            spikesBinary = zeros(size(response));
            spikesBinary(spikeTimes) = 1;
            spikesBinary = spikesBinary * 10000;
        end
    end
end
