classdef OffsetController < symphonyui.ui.Module
  % set the center offset easily
  %
  % future: communication with centering protocols, remove protocol
  % centerOffset control entirely
  %
  % 9Jun2017 - SSP - created
  % 13Jun2017 - SSP - added one more error catch, should keep symphony from
  % shutting down if existing protocol doesn't have centerOffset

  properties
    cellOffset = [0 0]
    handles
  end

methods
  function createUi(obj, figureHandle)
    set(figureHandle, 'Name', 'offset controller',...
        'Position', appbox.screenCenter(250,150),...
        'Color', 'w');
    mainLayout = uix.VBox('Parent', figureHandle,...
      'Padding', 10);

    obj.handles.txt = uicontrol('Parent', mainLayout,...
      'Style', 'text',...
      'String', 'center offset: ');

    xyLayout = uix.HBox('Parent', mainLayout,...
      'Padding', 10);

    obj.handles.x = uicontrol('Parent', xyLayout,...
      'Style', 'edit',...
      'String', 'x');
    obj.handles.y = uicontrol('Parent', xyLayout,...
      'Style', 'edit',...
      'String', 'y');
    obj.handles.dOffset = uicontrol('Parent', xyLayout,...
      'Style', 'push',...
      'String', 'set',...
      'Callback', @obj.onSelectedSet);
    obj.handles.dispResult = uicontrol('Parent', mainLayout,...
      'Style', 'text',...
      'String', 'offset not set');

    set(xyLayout, 'Widths', [-1 -1 -1]);
    set(mainLayout, 'Heights', [-1 -1 -1]);
  end % createUi

  function onSelectedSet(obj, ~, ~)
    % lots of error catching for now...
    try
      obj.cellOffset(1) = str2double(get(obj.handles.x, 'String'));
    catch
      warndlg(sprintf('issue getting x offset [%s], remains at %u', get(obj.handles.x, 'String'), obj.cellOffset(1)));
    end
    try
      obj.cellOffset(2) = str2double(get(obj.handles.y, 'String'));
    catch
      warndlg(sprintf('issue getting y offset [%s], remains at %u', get(obj.handles.y, 'String'), obj.cellOffset(2)));
    end

    try
        obj.acquisitionService.setProtocolProperty('centerOffset', obj.cellOffset);
        set(obj.handles.dispResult, 'String', ['updated: ' datestr(now)]);
    catch
        set(obj.handles.dispResult, 'String', ['ERROR: no update at ' datestr(now)]);
    end

  end % onSelectedSet
end % methods
end % classdef
