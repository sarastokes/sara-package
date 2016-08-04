classdef ConeIsoFigure < symphonyui.core.FigureHandler
  % for ConeIsoSearch protocol

properties
  device
  searchValues
  onlineAnalysis
  preTime
  stimTime
  temporalFrequency
  demoMode
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
  objectiveMag
  ndf
end

methods
  function obj = ConeIsoFigure(device, searchValues, onlineAnalysis, preTime, stimTime, temporalFrequency, varargin)
    obj.device = device;
    obj.searchValues = searchValues;
    obj.onlineAnalysis = onlineAnalysis;
    obj.stimTime = stimTime;
    obj.preTime = preTime;
    obj.temporalFrequency = temporalFrequency;

    % demo mode option to test off rig
    ip = inputParser();
    ip.addParameter('demoMode', [], @(x)islogical(x) || @(x)char(x));
    ip.parse(varargin{:});
    obj.demoMode = ip.Results.demoMode;

    if isempty(obj.demoMode)
      obj.demoMode = false;
    end

    % epoch counter
    obj.epochSort = 0;
    obj.epochCap = 2 * length(obj.searchValues);

    % begin with green axis
    obj.searchAxis = 'green'; obj.ledIndex = 2;

    % i don't think i need redAxis, greenAxis.. will remove once working
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

    findContrastMinsButton = uipushtool('Parent', toolbar,...
      'TooltipString', 'Find contrast minimums',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedFindContrastMins);
    setIconImage(findContrastMinsButton, symphonyui.app.App.getResource('icons', 'valid.png'));

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

    if obj.demoMode
      load demoResponse; % mat file saved in utils
      expTime = (obj.preTime + obj.stimTime + obj.tailTime) * 10;
      n = randi(length(response) - expTime, 1);
      responseTrace = response(n + 1 : n + expTime);
      sampleRate = 10000;
    else
      response = epoch.getResponse(obj.device);
      responseTrace = response.getData();
      sampleRate = response.sampleRate.quantityInBaseUnits;
    end

    % some of this should probably go back in ConeIsoSearch..
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
    if obj.epochSort > length(obj.searchValues)
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
  %  global customColorWeights
  %  customColorWeights = [obj.redMin obj.greenMin 1];

    % get date and obj/ndf
    d = datestr(now,'mmmdd');
    fw = obj.rig.getDevices('FilterWheel');
    if ~isempty(fw)
      filterWheel = fw{1};
      obj.objectiveMag = filterWheel.getObjective();
      obj.ndf = filterWheel.getNDF();
    else
      error('ConeIsoFigure did not find FilterWheel');
    end

    load customColorWeights.mat;
    % if ~isempty(customColorWeights.(sprintf('%sobj%undf%u'), d, obj.ndf, obj.objectiveMag));
    customColorWeights.(sprintf('%sobj%undf%u', d, obj.ndf, obj.objectiveMag)) = [obj.redMin obj.greenMin 1];
    save('customColorWeights.mat', 'customColorWeights', '-append');
  end

  function onSelectedExistingContrasts(obj, ~, ~)
  %  global customColorWeights
  %  fprintf('Existing LED contrasts are [%.5f %.5f 1]\n', customColorWeights(1), customColorWeights(2));
  end

  function findContrastMins(obj, ~, ~)
    if obj.demoMode
      obj.greenMin = 0;
    else
      obj.greenMin = min(obj.greenF1);
    end
    [rows, cols, vals] = find(obj.greenF1 == obj.greenMin);
    fprintf('rows = %u, cols = %u, vals = %u\n', rows,cols,vals);
end
end
end
