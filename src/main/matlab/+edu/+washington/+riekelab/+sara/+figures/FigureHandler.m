classdef (Abstract) FigureHandler < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        device
    end
    
    properties (Access = protected)
        toolbar
        epochNum = 0;

        % set at the beginning of each epoch
        lastResponse
        sampleRate
    end
    
    properties (Constant = true, Hidden = true, Access = protected)
        CMAPS = {'bone', 'cubicl', 'viridis', 'bluered', 'parula'};
        ICONDIR = [fileparts(fileparts(mfilename('fullpath'))), '+\icons\'];
    end
    
    methods
        function obj = FigureHandler(device)
            % Parse standard input parameters
            obj.device = device;
        end
        
        function createUi(obj)
            import appbox.*;

            % Set up figure defaults
            set(obj.figureHandle,...
                'Color', 'w', 'XTickMode', 'auto',...
                'DefaultAxesFontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'DefaultAxesFontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'DefaultAxesFontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'));
            
            % create a toolbar and a button to send data to workspace
            obj.toolbar.root = findall(obj.figureHandle, 'Type', 'toolbar');    

            obj.toolbar.sendButton = uipushtool(...
                'Parent', obj.toolbar.root,...
                'TooltipString', 'Send to workspace',...
                'Separator', 'on',...
                'ClickedCallback', @obj.sendData);
            setIconImage(obj.toolbar.sendButton, [obj.ICONDIR, 'send.png']);             
        end

        function clear(obj)
            cla(findall(obj.figureHandle, 'Type', 'axes'));
            obj.epochNum = 0;
        end
        
        function handleEpoch(obj, epoch)
            % check for a response
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end

            % increment the count
            obj.epochNum = obj.epochNum + 1;

            epochResponse = epoch.getResponse(obj.device);
            obj.lastResponse = epochResponse.getData();
            obj.sampleRate = epochResponse.sampleRate.quantityInBaseUnits;
        end

    end
    
    methods (Access = protected)
        function standardizeFigure(obj)
            set(findall(obj.figureHandle, 'Type', 'uicontrol'),...
                'BackgroundColor', 'w');
        end

        function sendData(obj, ~, ~)
    		% SENDDATA Send obj as structure to workspace
    		answer = inputdlg('Send to workspace as: ',...
    			'Debug Dialog', 1, {'r'});
    		assignin('base', sprintf('%s', answer{1}), class2struct(obj));
    		fprintf('%s - figure data sent as %s', datestr(now), answer{1});
        end
    end
end