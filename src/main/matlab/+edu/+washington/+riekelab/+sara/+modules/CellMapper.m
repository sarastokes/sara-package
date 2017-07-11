classdef CellMapper < symphonyui.ui.Module

properties
  handles
end

methods
  function createUi(obj, figureHandle)
    import appbox.*;

    set(figureHandle, 'Color', 'w',...
    'Position', appbox.screenCenter(250,250),...
    'Name', 'Cell Mapper');

    % setup the toolbar
    toolbar = findall(figureHandle, 'Type', 'uitoolbar');
    clearButton = uipushtool('Parent', toolbar,...
      'TooltipString', 'Clear plot',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelected_clearPlot);

    mainLayout = uix.VBox('Parent', figureHandle);
    obj.handles.ax = axes('Parent', mainLayout,...
    'XDir', 'reverse',...
    'YDir', 'reverse');
    hold(obj.handles.ax, 'on');

    uiLayout = uix.VBox('Parent', mainLayout,...
    'Spacing', 5, 'Padding', 5);
    obj.handles.loc = uitable('Parent', uiLayout,...
    'Data', [0 0; 0 0],...
    'ColumnName', {'X', 'Y'});

    obj.handles.pb.neuron = uicontrol('Parent', uiLayout,...
    'Style', 'push', 'String', 'Neuron',...
    'Callback', @obj.addMarker);
    obj.handles.pb.badCell = uicontrol('Parent', uiLayout,...
    'Style', 'push', 'String', 'Bad cell',...
    'Callback', @obj.addMarker);
    obj.handles.pb.star = uicontrol('Parent', uiLayout,...
    'Style', 'push', 'String', 'Star',...
    'Callback', @obj.addMarker);
    obj.handles.pb.edge = uicontrol('Parent', uiLayout,...
    'Style', 'push', 'String', 'Edge',...
    'Callback', @obj.addMarker);
    obj.handles.pb.harp = uicontrol('Parent', uiLayout,...
    'Style', 'push', 'String', 'harp',...
    'Callback', @obj.addMarker)
  end % createui

  function addMarker(obj, src, ~)
    co = pmkmp(12, 'CubicL');
    xy = obj.handles.loc.Data(1,:);

    whichMarker = src.String;

    switch lower(whichMarker)
    case 'neuron'
      plot(x, y, 'Marker', '*', 'Color', co(12,:));
    case 'bad cell'
      plot(x, y, 'Marker', 'x', 'Color', co(1,:));
    case 'edge'
      plot(x, y, 'o', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');
    case 'star'
      plot(x,y, '*', 'Color', co(7,:));
    case 'harp'
      plot(x, y, 'o', 'Color', co(4,:))
    end
  end % addMarker

  function onSelected_clearPlot(obj, ~, ~)
    clearPlot(obj);
  end % onSelected_clearPlot

  function clearPlot(obj)
    cla(obj.handles.ax);
  end % clearPlot
end % methods
end % classdef
