classdef SpikeResponseFigure < symphonyui.core.FigureHandler
    % This figure is essentially the response figure with public properties
    % storing the spike binary and spike times. This figure should be used
    % when a protocol has multiple figures - rather than recalculating
    % spikes for each figure, just provide the SpikeResponseFigure handle
    % as an input to the other figures.
    %
    % TODO: store spikes with stored sweep
    %
    % 19Oct2017 - SSP - modified from my ResponseFigure

    properties (SetAccess = private)
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
        % Line handle for most recent response
        sweep
        % Holds UI handles
        handles = struct();
        spikeButton
        displayMode = true;
    end

    % The spike data available to other figures
    properties (SetAccess = private, GetAccess = public)
        % Spike binary with epochs as rows
        spikeMatrix = [];
        % Each cell contains the spike times of an epoch
        spikeTimes = {};
    end
    
    properties (Constant = true, Access = private)
        ICONDIR = [fileparts(fileparts(mfilename('fullpath'))), '\+icons\'];
    end
    
    methods
        function obj = SpikeResponseFigure(device, varargin)
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

            set(obj.figureHandle,...
                'Name', 'Spike Response Figure',...
                'Color', 'w');

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
            
            obj.spikeButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Display Spikes',...
                'ClickedCallback', @obj.toggleDisplay);
            setIconImage(obj.spikeButton, [iconDir, 'add_spike.png']);
            
            % ------------------------------------------------- handles ---                        
            if ~isempty(obj.stimTrace)
                obj.handles.ax.resp = subplot(4,1,1:3,...
                    'Parent', obj.figureHandle);
                obj.handles.ax.stim = subplot(4,1,4,...
                    'Parent', obj.figureHandle,...
                    'XTick', [], 'XColor', 'w');
                obj.handles.stim = [];
            else    
                obj.handles.ax.resp = axes(...
                    'Parent', obj.figureHandle);       
            end
            xlabel(obj.handles.ax.resp, 'sec');

            if isempty(obj.stimTitle)
                obj.setTitle([obj.device.name ' Response']);
            else
                obj.setTitle(obj.stimTitle);
            end

            set(findall(obj.figureHandle, 'Type', 'axes'),...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'XTickMode', 'auto');
            set(findall(obj.figureHandle, 'Type', 'uipushtool'),...
                'Separator', 'on');
            
            obj.sweep = [];
            obj.handles.spikes = [];
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.handles.ax.resp, t);
        end
        
        function clear(obj)
            cla(obj.handles.ax.resp); 
            if ~isempty(obj.stimTrace)
                cla(obj.handles.ax.stim);
                obj.handles.stim = [];
            end
            obj.sweep = []; 
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
            [spikes, sTimes] = obj.getSpikes(y);
            obj.spikeMatrix = cat(1, obj.spikeMatrix, spikes);
            obj.spikeTimes = cat(1, obj.spikeTimes, sTimes);

            % Display the spikes
            if obj.displayMode && ~isempty(sTimes)
                if isempty(obj.handles.spikes)
                    obj.handles.spikes = line(...
                        'Parent', obj.handles.ax.resp,...
                        'XData', x(sTimes),...
                        'YData', ones(size(sTimes)),...
                        'Color', [0 0.8 0.3],...
                        'Marker', 'o',...
                        'LineStyle', 'none');
                else
                    set(obj.handles.ax.spikes,...
                        'XData', x, 'YData', y);
                end
            end
            
            % Plot the stimuli
            if ~isempty(obj.stimTrace)
                xs = linspace(0, max(x), length(obj.stimTrace));
                if isempty(obj.handles.stim)
                    obj.handles.stim = line(...
                        'Parent', obj.handles.ax.stim,...
                        'XData', xs, 'YData', obj.stimTrace,...
                        'Color', obj.stimColor,...
                        'LineWidth', 1.5);
                else
                    set(obj.handles.stim,...
                        'XData', xs,...
                        'YData', obj.stimTrace);
                end
                if y(1) == 0
                    ylabel(obj.handles.ax.stim, 'Intensity');
                else
                    ylabel(obj.handles.ax.stim, 'Contrast');
                end
            end
        end
    end
    
    % Callback methods
    methods (Access = private)
        function toggleDisplay(obj, src, ~)
            % TOGGLEDISPLAY  Change spike display setting
            if obj.displayMode
                obj.displayMode = false;
                obj.handles.spikes = [];
                set(src, 'TooltipString', 'Detect Spikes');
                setIconImage(obj.spikeButton, [obj.ICONDIR, 'spike.png']);
            else
                obj.displayMode = true;
                set(src, 'TooltipString', 'Stop Detecting Spikes');
                setIconImage(obj.spikeButton, [obj.ICONDIR, 'rm_spikes.png']);
            end
        end
        
        function onSelectedStoreSweep(obj, ~, ~)
            % ONSELECTEDSTORESWEEP  Stores sweeps between figure calls
            if ~isempty(obj.storedSweep)
                delete(obj.storedSweep);
            end
            obj.storedSweep = copyobj(obj.sweep, obj.handles.ax.resp);
            set(obj.storedSweep,...
                'Color', obj.storedSweepColor,...
                'HandleVisibility', 'off');
        end
        
        function onSelectedClearSweep(obj, ~, ~)
            obj.clearSweep();
        end
    end

    methods (Access = private)      
        function spikesNow(obj, ~, ~)
            % SPIKESNOW  Get spikes for currently displayed response
            obj.handles.spikes = line(...
                'Parent', obj.handles.ax.resp,...
                'XData', obj.sweep.XData(obj.spikeTimes{end}),...
                'YData', ones(size(obj.spikeTimes{end})),...
                'Marker', 'o',...
                'Color', 'b',...
                'LineStyle', 'none');
        end % spikesNow
        
        function rmSpikes(obj, ~, ~)
            % RMSPIKES Remove spikes from currently displayed response
            if isfield(obj.handles, 'spikes') && ~isempty(obj.handles.spikes)
                obj.handles.spikes = [];
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
            if ~isempty(spikeTimes)
                spikesBinary(spikeTimes) = 1;
            end
            spikesBinary = spikesBinary * 10000;
        end
    end
end
