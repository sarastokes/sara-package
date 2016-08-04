classdef ConeIsoSearch < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp
  preTime = 250
  stimTime = 1500
  tailTime = 250
  temporalFrequency = 4.0
  radius = 150
  minStepBits = 2                     % min step size (bits)
  maxStepBits = 3                     % max step size (bits)
  backgroundIntensity = 0.5
  centerOffset = [0,0]
  temporalClass = 'sinewave'
  onlineAnalysis = 'none'
  demoMode = false                   % if not connected to rig
  numberOfAverages = uint16(130)
end

properties (Hidden)
  ampType
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog', 'demo'})
  ledContrasts
  ledIndex
  greenAxis
  greenF1
  redAxis
  redF1
  foundGreenMin
  foundRedMin
  greenMin
  redMin
  searchValues
  minStep
  maxStep
  searchAxis
end

% response figure properties
properties (Hidden)
  stimTrace
  stimValues
  stimTitle
  sweepColor
end

% output figure properties
properties (Hidden)
  currentNDF
  currentOBJ
  greenLED
  redLED
  blueLED
end

properties (Hidden, Transient)
  analysisFigure
end

methods
  function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
  end

  function prepareRun(obj)
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

    if strcmp(obj.stageClass, 'LightCrafter')
      error('Set to video mode or use manookin package ConeIsoSearch');
    end

    x = 0:0.001:((obj.stimTime -1) * 1e-3);
    obj.stimValues = zeros(1, length(x));
    for ii = 1:length(x)
      if strcmp(obj.temporalClass, 'squarewave')
        obj.stimValues(1,ii) = sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
      else
        obj.stimValues(1,ii) = sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
      end
    end

    obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

    if ~strcmp(obj.onlineAnalysis, 'none')
      obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.MTFanalysis);
      f = obj.analysisFigure.getFigureHandle();
      set(f, 'Name', 'S-iso search');
      obj.analysisFigure.userData.axesHandle = axes('Parent', f);
    end

    %% from organizeParameters(obj)
    obj.minStep = 2^obj.minStepBits / 256 * 2;
    obj.maxStep = 2^obj.maxStepBits / 256 * 2;

    % initialize search axis with the max step
    obj.searchValues = [(-1 : obj.minStep:1), (-0.4375:obj.minStep:-0.2031), (0:obj.minStep:0.125)];
    obj.searchValues = unique(obj.searchValues);
    fprintf('Number of unique search values is %u\n', length(obj.searchValues))
    if obj.numberOfAverages < (2 * obj.searchValues)
      error('Need more averages to account for all search values');
    end

    % begin with green axis
    obj.searchAxis = 'green'; obj.ledIndex = 2;

    % response and online analysis figures
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);

    if ~strcmp(obj.onlineAnalysis, 'none')
      obj.showFigure('edu.washington.riekelab.sara.figures.ConeIsoFigure', obj.rig.getDevice(obj.amp), obj.searchValues, obj.onlineAnalysis, obj.preTime, obj.stimTime, obj.temporalFrequency);
    end
  end
  % will cut this out once ConeIsoFigure is totally functional
    function MTFanalysis(obj, ~, epoch)
      if obj.demoMode
        load demoResponse; % mat file saved in utils
        expTime = (obj.preTime + obj.stimTime + obj.tailTime) * 10;
        n = randi(length(response) - expTime, 1);
        responseTrace = response(n + 1 : n + expTime);
        sampleRate = 10000;
      else
        response = epoch.getResponse(obj.rig.getDevice(obj.amp));
        responseTrace = response.getData();
        sampleRate = response.sampleRate.quantityInBaseUnits;
      end

      % analyze response by type
      responseTrace = obj.getResponseByType(responseTrace, obj.onlineAnalysis);

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
      % find the F1 amplitude for red/green axis
      if strcmp(obj.searchAxis, 'red')
        if isempty(obj.redAxis)
          index = 1;
        else
          index = length(obj.redAxis) + 1;
        end
        obj.redAxis(index) = obj.ledContrasts(obj.ledIndex);
        obj.redF1(index) = abs(ft(2)) / length(ft)*2;
      else
        obj.greenAxis(obj.numEpochsCompleted) = obj.ledContrasts(obj.ledIndex);
        obj.greenF1(obj.numEpochsCompleted) = abs(ft(2)) / length(ft)*2;
      end

      %----------------------------------------------------------------------
      axesHandle = obj.analysisFigure.userData.axesHandle;
      cla(axesHandle);
      hold(axesHandle, 'on');
      plot(obj.greenAxis, obj.greenF1, 'o-', 'color', [0 0.73 0.30], 'Parent', axesHandle);
      if strcmp(obj.searchAxis, 'red')
        plot(obj.redAxis, obj.redF1, 'o-', 'color', [0.82, 0, 0], 'Parent', axesHandle);
      end
      hold(axesHandle, 'off'); % why turn this back off?
      set(axesHandle, 'TickDir', 'out');
      ylabel(axesHandle, 'F1 amp');
      title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', axesHandle);
    end

    function p = createPresentation(obj)
      p = stage.core.Presentation ((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
      p.setBackgroundColor(obj.backgroundIntensity);

      spot = stage.builtin.stimuli.Ellipse();
      spot.radiusX = obj.radius; spot.radiusY = obj.radius;
      spot.position = obj.canvasSize/2 + obj.centerOffset;
      spot.color = obj.ledContrasts * obj.backgroundIntensity + obj.backgroundIntensity;

      % add the stimulus to the presentation
      p.addStimulus(spot);

      % control when the spot is visible
      spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
      p.addController(spotVisible);

      % control the spot color
      colorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));
      p.addController(colorController);
      end

      function c = getSpotColor(obj, time)
        if strcmp(obj.temporalClass, 'sinewave')
          c = obj.ledContrasts * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
        else
          c = obj.ledContrasts * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
        end
      end

    function prepareEpoch(obj, epoch)
      prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

      n = obj.numEpochsCompleted - length(obj.searchValues);
      if n == 0
        obj.searchAxis = 'red';
        if strcmp(obj.onlineAnalysis, 'none')
          obj.greenMin = 0;
        else
          % changed greenMin to greenF1
          obj.greenMin = obj.searchValues(find(obj.greenMin == min(obj.greenF1), 1));
          fprintf('Green Minimum is %.5f\n', obj.greenMin);
        end
      end
      if n == length(obj.searchValues)
        fprintf('Red minimum\n');
      end
      if obj.numEpochsCompleted+1 > length(obj.searchValues)
        obj.searchAxis = 'red';
      else
        obj.searchAxis = 'green';
      end

      switch obj.searchAxis
        case 'red'
          index = (obj.numEpochsCompleted+1) - length(obj.searchValues);
          obj.ledContrasts = [obj.searchValues(index) obj.greenMin 1];
          obj.ledIndex = 1; obj.sweepColor = [0.82 0 0];
        case 'green'
          obj.ledContrasts = [0 obj.searchValues(obj.numEpochsCompleted+1) 1];
          obj.ledIndex = 2; obj.sweepColor = [0 0.73 0.30];
      end

      obj.stimTitle = sprintf('Epoch number %u - LED contrasts at [%.3f %.3f 1]', obj.numEpochsCompleted - 1, obj.ledContrasts(1), obj.ledContrasts(2));

      % this throws an error (index exceeds matrix dimensions) at end of green
%      fprintf('epoch %u - LED contrasts are %.5f %.5f %u\n', obj.numEpochsCompleted+1, obj.ledContrasts(1), obj.ledContrasts(2), obj.ledContrasts(3));

      epoch.addParameter('searchAxis', obj.searchAxis);
      epoch.addParameter('ledIndex', obj.ledIndex);
      epoch.addParameter('ledContrasts', obj.ledContrasts);
    end

    function tf = shouldContinuePreparingEpochs(obj)
        tf = obj.numEpochsPrepared < obj.numberOfAverages;
    end

    function tf = shouldContinueRun(obj)
        tf = obj.numEpochsCompleted < obj.numberOfAverages;
    end
  end
end
