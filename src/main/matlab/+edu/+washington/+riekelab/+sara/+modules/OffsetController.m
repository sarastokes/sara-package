classdef OffsetController < symphonyui.ui.Module
  % set the center offset easily

  properties
    cellOffset = [0 0]
    handles
  end

methods
  function createUi(obj, figureHandle)
    set(figureHandle, 'Name', 'offset controller',...
        'Position', appbox.screenCenter(250,150));
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

    obj.acquisitionService.setProtocolProperty('centerOffset', obj.cellOffset);

    set(obj.handles.dispResult, 'String', ['updated:' datestr(now)]);
  end % onSelectedSet
end % methods
end % classdef
