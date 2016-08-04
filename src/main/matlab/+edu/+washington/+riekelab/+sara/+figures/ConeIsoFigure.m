classdef ConeIsoFigure < symphonyui.core.FigureHandler
  % for ConeIsoSearch protocol

properties
  device
  searchValues
  redAxis
  redF1
  greenAxis
  greenF1
end

properties (Access = private)
  axesHandle
  epochSort
  epochCap
  greenMin
  redMin
  currentContrasts
  minContrast
  searchAxis
  ledIndex
end

methods
  function obj = ConeIsoFigure(device, searchValues, redAxis, redF1, greenAxis, greenF1)
    obj.device = device;
    obj.searchValues = searchValues;
    obj.redAxis = redAxis;
    obj.redF1 = redF1;
    obj.greenAxis = greenAxis;
    obj.greenF1 = greenF1;

    obj.epochSort = 0;
    obj.epochCap = length(obj.searchValues);

    % begin with green axis
    obj.searchAxis = 'green';
    obj.ledIndex = 2;

    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;

    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
    storeContrastsButton = uipushtool('Parent', 'toolbar',...
      'TooltipString', 'Store Sweep',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedStoreContrasts);
    setIconImage(storeContrastsButton, symphonyui.app.App.getResource('icons', 'valid.png'));
    existingContrastsButton = uipushtool('Parent', 'toolbar',...
      'TooltipString', 'Print Existing Contrasts',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedExistingContrasts);
    setIconImage(existingContrastsButton, symphonyui.app.App.getResource('icons', 'experiment_view.png'));

    % create axes
    obj.axesHandle(1) = subplot(1,2,1, ...
      'Parent', obj.figureHandle,...
      'FontName', 'Roboto',...
      'FontSize', 9,...
      'XTickMode', 'auto');
    obj.axesHandle(2) = subplot(1,2,2,...
      'Parent', obj.figureHandle,...
      'FontName', 'Roboto',...
      'FontSize', 9,...
      'XTickMode', 'auto');
  end

  function clear(obj)
    cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
    obj.greenTrace = []; obj.redTrace = [];
    obj.epochSort = 0;
  end

  function handleEpoch(obj, epoch)
    % keep track of current epoch
    obj.epochSort = obj.epochSort+1;
    % reset after green found
    if obj.epochSort > obj.epochCap
      obj.epochSort = 1;
      % switch to red led
      obj.ledIndex = 1;
      obj.searchAxis = 'red';
    end

    % plot
    if obj.ledIndex == 2
      cla(obj.axesHandle(1));
      hold(obj.axesHandle(1), 'on');
      plot(obj.greenAxis, obj.greenF1, 'o-', 'color', [0 0.73 0.30], 'Parent', obj.axesHandle(1));
      hold(obj.axesHandle(1), 'off');
      set(obj.axesHandle(1), 'TickDir', 'out');
      ylabel(obj.axesHandle(1), 'F1 amp');
    else
      cla(obj.axesHandle(2));
      hold(obj.axesHandle(2), 'on');
      plot(obj.redAxis, obj.redF1, 'o-', 'color', [0.82, 0, 0], 'Parent', obj.axesHandle(2));
      hold(obj.axesHandle(2), 'off');
      set(obj.axesHandle(2), 'TickDirection', 'out');
      ylabel('F1 amp');
    end
  end
end

methods (Access = private)
  function onSelectedStoreContrasts(obj, ~, ~)
    fprintf('LED contrasts are [%.5f %.5f 1]\n', obj.redMin, obj.greenMin);
    global customColorWeights
    customColorWeights = [obj.redMin obj.greenMin 1];
  end

  function onSelectedExistingContrasts(obj, ~, ~)
    global customColorWeights
    fprintf('Existing LED contrasts are [%.5f %.5f 1]\n', customColorWeights(1), customColorWeights(2));
  end
end
end
