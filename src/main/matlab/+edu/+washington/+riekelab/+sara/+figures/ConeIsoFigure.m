classdef ConeIsoFigure < symphonyui.core.FigureHandler
  % for ConeIsoSearch protocol

properties
  device
  searchValues
  onlineAnalysis
  preTime
  stimTime
  temporalFrequency
end

properties (Access = private)
  axesHandle
  greenF1
  greenAxis
  redF1
  redAxis
  ledContrasts
  ledIndex
  epochSort
  epochCap
  greenMin
  redMin
  currentContrasts
  minContrast
  searchAxis
end

methods
  function obj = ConeIsoFigure(device, searchValues, onlineAnalysis, preTime, stimTime, temporalFrequency)
    obj.device = device;
    obj.searchValues = searchValues;
    obj.onlineAnalysis = onlineAnalysis;
    obj.stimTime = stimTime;
    obj.preTime = preTime;
    obj.temporalFrequency = temporalFrequency;

    obj.epochSort = 0;
    obj.epochCap = 2 * length(obj.searchValues);

    % begin with green axis
    obj.searchAxis = 'green';
    obj.ledIndex = 2;

    obj.redAxis = obj.searchValues; obj.redF1 = zeros(size(obj.redAxis));
    obj.greenAxis = obj.searchValues; obj.greenF1 = zeros(size(obj.greenF1));
    fprintf('size of greenAxis is %u and size of greenF1 is %u\n', length(obj.greenAxis), length(obj.greenF1));
    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;

    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
    storeContrastsButton = uipushtool('Parent', toolbar,...
      'TooltipString', 'Store Sweep',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedStoreContrasts);
    setIconImage(storeContrastsButton, symphonyui.app.App.getResource('icons', 'valid.png'));

    existingContrastsButton = uipushtool('Parent', toolbar,...
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

  function setTitle(obj, t)
    set(obj.figureHandle, 'Name', t);
    title(obj.axesHandle(1), t);
  end

  function clear(obj)
    cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
    obj.epochSort = 0;
  end

  function handleEpoch(obj, epoch)
    % keep track of current epoch
    obj.epochSort = obj.epochSort+1;

    % find F1 amplitude
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end

    response = epoch.getResponse(obj.device);
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    responseTrace = getResponseByType(responseTrace, obj.onlineAnalysis);

    % get the f1 amplitude and phase
    responseTrace = responseTrace(obj.preTime/1000*sampleRate+1 : end);
    binRate = 60;
    binWidth = sampleRate / binRate;
    numBins = floor(obj.stimTime/1000 * binRate);
    binData = zeros(1, numBins);

    for k = 1 : numBins
      index = round((k-1) * binWidth + 1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end

    binsPerCycle = binRate / obj.temporalFrequency;
    numCycles = floor(length(binData)/binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));

    for k = 1:numCycles
      index = round(k-1)*binsPerCycle + (1 : floor(binsPerCycle));
      cycleData = cycleData + binData(index);
    end
    cycleData = cycleData / k;

    ft = fft(cycleData);

    % reset after green found
    if obj.epochSort > obj.epochCap
      % switch to red led
      obj.ledIndex = 1;
      obj.searchAxis = 'red';
    else
      obj.ledIndex = 2;
      obj.searchAxis = 'green';
    end

    % find the F1 amplitude for red/green axis
    if strcmp(obj.searchAxis, 'red')
      index = epochSort - length(obj.redAxis)
      obj.redF1(index) = abs(ft(2)) / length(ft)*2;
    else
      obj.greenF1(obj.epochSort) = abs(ft(2)) / length(ft) * 2;
      fprintf('Length of greenF1 is %u and epochSort is %u\n', length(obj.greenF1), obj.epochSort);
    end

    % plot (everything calculated so far red/green)
      cla(obj.axesHandle(1));
      hold(obj.axesHandle(1), 'on');
      plot(obj.greenAxis(1:length(obj.greenF1)), obj.greenF1, 'o-', 'color', [0 0.73 0.30], 'Parent', obj.axesHandle(1));
      hold(obj.axesHandle(1), 'off');
      set(obj.axesHandle(1), 'TickDir', 'out');
      ylabel(obj.axesHandle(1), 'F1 amp');
    if obj.ledIndex == 1
      cla(obj.axesHandle(2));
      hold(obj.axesHandle(2), 'on');
      plot(obj.redAxis(1:length(obj.redF1)), obj.redF1, 'o-', 'color', [0.82, 0, 0], 'Parent', obj.axesHandle(2));
      hold(obj.axesHandle(2), 'off');
      set(obj.axesHandle(2), 'TickDirection', 'out');
      ylabel('F1 amp');
    end
    obj.setTitle(['Epoch ', num2str(obj.epochSort), ' of ', num2str(obj.epochCap)]);
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
