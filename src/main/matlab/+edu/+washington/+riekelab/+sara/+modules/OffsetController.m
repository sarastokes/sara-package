classdef OffsetController < symphonyui.ui.Module
    % set standard stimulus parameters
    %
    % 9Jun2017 - SSP - created
    % 13Jun2017 - SSP - added one more error catch, should keep symphony from
    % shutting down if existing protocol doesn't have centerOffset
    
    properties
        % holds UI-related objects
        handles = struct();
        
        % track whether offset is included in protocol
        offsetFlag = false;
        % Keep consistent with mike's package
        lightKey = [];
    end
    
    properties (SetAccess = private, GetAccess = public)
        % protocol parameters to monitor
        cellOffset = [0 0];
        lightMean = 0.5
        autoUpdate = false
    end
    
    
    methods
        function createUi(obj, figureHandle)
            set(figureHandle, 'Name', 'offset controller',...
                'Position', appbox.screenCenter(250,200),...
                'Color', 'w');
            
            mainLayout = uix.VBox('Parent', figureHandle,...
                'Padding', 10);
            
            uicontrol('Parent', mainLayout,...
                'Style', 'text',...
                'String', 'center offset: ');
            
            xyLayout = uix.HBox('Parent', mainLayout,...
                'Padding', 5,...
                'BackgroundColor', 'w');
            
            obj.handles.x = uicontrol('Parent', xyLayout,...
                'Style', 'edit',...
                'String', 'x');
            obj.handles.y = uicontrol('Parent', xyLayout,...
                'Style', 'edit',...
                'String', 'y');
            obj.handles.dOffset = uicontrol('Parent', xyLayout,...
                'Style', 'push',...
                'String', 'set',...
                'Callback', @obj.changeOffset);
            
            obj.handles.tx.lightMean = uicontrol(mainLayout,...
                'Style', 'text',...
                'String', 'Light Mean: ');
            meanLayout = uix.HBox('Parent', mainLayout,...
                'Padding', 10,...
                'BackgroundColor', 'w');
            obj.handles.ed.lightMean = uicontrol(meanLayout,...
                'Style', 'edit',...
                'String', '0.5',...
                'TooltipString', '0-1');
            obj.handles.pb.dMean = uicontrol(meanLayout,...
                'Style', 'push',...
                'String', 'Set',...
                'Callback', @obj.changeMean);
            
            % Auto vs manual update mode control
            obj.handles.cb = uicontrol('Parent', mainLayout,...
                'Style', 'checkbox',...
                'String', 'Auto update',...
                'TooltipString', 'Update protocol parameters automatically',...
                'Callback', @toggleAutoUpdate);
            
            % Display internals
            valueLayout = uix.HBox('Parent', mainLayout,...
                'BackgroundColor', 'w');
            obj.handles.tx.internalLightMean = uicontrol(valueLayout,...
                'Style', 'text',...
                'String', ['LightMean = ', obj.lightMean]);
            obj.handles.tx.internalOffset = uicontrol(valueLayout,...
                'Style', 'text',...
                'String', ['Offset = ', obj.cellOffset]);
            
            set(xyLayout, 'Widths', [-1 -1 -1]);
            set(mainLayout, 'Heights', [-0.9 -1.2 -0.9 -1.3 -1 -0.9]);
            
            set(findall(figureHandle, 'Type', 'Uicontrol'),...
                'BackgroundColor', 'w');
        end % createUi
    end
    
    methods(Access = protected)
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            
            obj.addListener(obj.acquisitionService,...
                'SelectedProtocol', @obj.onService_SelectedProtocol);
        end
    end
    
    
    methods (Access = private)
        function setOffset(obj)
            % SETOFFSET  Sets center offset and reflects in tooltip string
            
            obj.acquisitionService.setProtocolProperty('centerOffset', obj.cellOffset);
        end
        
        function setMean(obj)
            % SETMEAN  Sets protocol lightMean and reflects in tooltip string
            obj.acquisitionService.setProtocolProperty(obj.lightKey, obj.lightMean);
            set(obj.handles.pb.lightMean,...
                'TooltipString', sprintf('Set at %s', datestr(now)));
        end
    end
    
    %
    % Callback methods
    %
    methods(Access = private)
        
        function onService_SelectedProtocol(obj, ~, ~)
            % Check for parameters
            params = obj.acquisitionService.getProtocolPropertyDescriptors();
            
            if isKey(params, 'centerOffset')
                set(obj.handles.dOffset, 'Enable', 'on');
                if obj.autoUpdate
                    obj.setOffset();
                end
            else
                set(obj.handles.dOffset, 'Enable', 'off');
                obj.offsetFlag = false;
            end
            
            if isKey(params, 'lightMean')
                set(obj.handles.dMean, 'Enable', 'on');
                obj.lightKey = 'lightMean';
            elseif isKey(params, 'backgroundIntensity')
                set(obj.handles.dMean, 'Enable', 'on');
                obj.lightKey = 'backgroundIntensity';
            else
                set(obj.handles.dMean, 'Enable', 'off');
                obj.lightKey = [];
            end
        end
        
        % Module updates protocols based on it's private parameter
        % properties. The change methods set this internal value and then
        % trigger the same events as the pushbuttons
        function changeOffset(obj, ~, ~)
            % CHANGEOFFSET  Parse input and update lightMean
            try
                obj.cellOffset = [str2double(get(obj.handles.x, 'String')),...
                    str2double(get(obj.handles.y, 'String'))];
            catch
                warndlg(sprintf('issue getting offset [%s, %s], remains at %u, %u',...
                    get(obj.handles.x, 'String'), get(obj.handles.y, 'String'),...
                    obj.cellOffset));
                return;
            end
            
            obj.setOffset();
        end
        
        function changeMean(obj, ~, ~)
            % CHANGEMEAN  Parse input and lightMean
            try
                value = str2double(get(obj.handles.y, 'String'));
            catch
                warndlg('Was not able to convert to double');
                return;
            end
            
            obj.lightMean = value;
            
            obj.setMean();
        end
        
        % Update automatically if protocol parameter exists
        function toggleAutoUpdate(obj, ~, ~)
            % TOGGLEAUTOUPDATE  Sets autoUpdate to t/f
            if obj.autoUpdate
                obj.autoUpdate = false;
            else
                obj.autoUpdate = true;
            end
        end
    end % methods
end % classdef
