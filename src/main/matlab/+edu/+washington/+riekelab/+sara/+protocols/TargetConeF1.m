classdef TargetConeF1 < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp                               % Output amplifier
  preTime = 500                     % Spot leading duration (ms)
  stimTime = 2500                   % Spot duration (ms)
  tailTime = 500                    % Spot trailing duration (ms)
  temporalFrequency = 4.0           % Modulation frequency (Hz)
  radius = 200                      % Inner radius in pixels.
  backgroundIntensity = 0.5         % Background light intensity (0-1)
  centerOffset = [0,0]              % Center offset in pixels (x,y)
  temporalClass = 'sinewave'        % Sinewave or squarewave?
  chromaticClass = 'achromatic'     % Spot color
  stimulusClass = 'spot'            % Stimulus class
  onlineAnalysis = 'extracellular'  % Online analysis type.
  targetF1 = 20                     % Target f1 amplitude
  minStart = 0.01                   % Starting contrast min (0-1)
  maxStart = 1                      % Starting contrast max (0-1)
  numberOfAverages = uint16(18)     % Number of epochs
end

properties (Hidden)
    ampType
    temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'pulse-positive', 'pulse-negative'})
    chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'red', 'green', 'blue', 'yellow', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
    onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    stimulusClassType = symphonyui.core.PropertyType('char', 'row', {'spot', 'annulus'})
end

properties (Hidden, Transient)
    analysisFigure
end

properties (Hidden)
  xaxis
  maxPt = 0
  minPt = 0
  lastPt = 0
  nextPt = 0
  lastF1 = 0
end

methods
function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end
function prepareRun(obj)
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

    if ~strcmp(obj.onlineAnalysis, 'none')
        obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CRFanalysis);
        f = obj.analysisFigure.getFigureHandle();
        set(f, 'Name', 'Cone Contrast Response Function');
        obj.analysisFigure.userData.axesHandle = axes('Parent', f);
    end

    if strcmp(obj.stageClass, 'LightCrafter')
        obj.chromaticClass = 'achromatic';
    end

    obj.xaxis = zeros(1, double(obj.numberOfAverages));

    obj.setColorWeights();
end

function CRFanalysis(obj, ~, epoch)
    response = epoch.getResponse(obj.rig.getDevice(obj.amp));
    [y, ~] = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    binRate = 60;
    if strcmp(obj.recordingType,'extracellular')
        res = spikeDetectorOnline(y,[],sampleRate);
        y = zeros(size(y));
        y(res.sp) = sampleRate; %spike binary
    else
        if prePts > 0
            y = y - median(y(1:prePts));
        else
            y = y - median(y);
        end
    end

    %--------------------------------------------------------------
    % Get the F1 amplitude and phase.
    responseTrace = y(obj.preTime/1000*sampleRate+1 : end);

    binWidth = sampleRate / binRate; % Bin at 60 Hz.
    numBins = floor(obj.stimTime/1000 * binRate);
    binData = zeros(1, numBins);
    for k = 1 : numBins
        index = round((k-1)*binWidth+1 : k*binWidth);
        binData(k) = mean(responseTrace(index));
    end
    binsPerCycle = binRate / obj.temporalFrequency;
    numCycles = floor(length(binData)/binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));
    for k = 1 : numCycles
        index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
        cycleData = cycleData + binData(index);
    end
    cycleData = cycleData / k;

    ft = fft(cycleData);

    index = find(obj.xaxis == obj.contrast, 1);
    r = obj.F1Amp(index) * obj.repsPerX(index);
    obj.lastF1 = abs(ft(2))/length(ft)*2;
    r = r + obj.lastF1;

    % Increment the count.
    obj.repsPerX(index) = obj.repsPerX(index) + 1;
    obj.F1Amp(index) = r / obj.repsPerX(index);

    % add to graph
    obj.xaxis(obj.numEpochsCompleted) = obj.nextPt;
    axesHandle = obj.analysisFigure.userData.axesHandle;
    cla(axesHandle);

    h1 = axesHandle;
    plot(obj.xaxis, obj.F1Amp, 'ko-', 'Parent', h1);
    set(h1, 'TickDir', 'out');
    ylabel(h1, 'F1 amp');
    title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', h1);
end

function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    spot = stage.builtin.stimuli.Ellipse();
    spot.radiusX = obj.radius;
    spot.radiusY = obj.radius;
    spot.position = obj.canvasSize/2 + obj.centerOffset;

    spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

    p.addStimulus(spot);
    p.addController(spotVisibleController);
    p.addController(spotColorController);

    % center mask for annulus
    if obj.maskRadius > 0
      mask = stage.builtin.stimuli.Ellipse();
      mask.radiusX = obj.maskRadius;
      mask.radiusY = obj.maskRadius;
      mask.position = obj.canvasSize/2 + obj.centerOffset;
      mask.color = obj.backgroundIntensity;

      maskVisibleController = stage.builtin.controllers.PropertyController(mask, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

      p.addStimulus(mask);
      p.addController(maskVisibleController);
    end

  function c = getSpotColor(obj, time)
    if time >= 0
      if strcmp(obj.temporalClass, 'sinewave')
        c = obj.contrast * obj.colorWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
      elseif strcmp(obj.temporalClass, 'squarewave')
         c = obj.contrast * obj.colorWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
      end
    else
      c = obj.backgroundIntensity;
    end
  end
end

function prepareEpoch(obj, epoch)
  prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch)

  obj.lastPt = obj.nextPt;

  if obj.numEpochsCompleted == 0
    obj.nextPt = obj.minStart;
  elseif obj.numEpochsCompleted == 1
    obj.nextPt = obj.maxStart;
  elseif obj.numEpochsCompleted == 2
    if obj.lastF1 < obj.targetF1
      error('Max point didnt reach target');
    else
      obj.nextPt = (obj.maxStart - obj.minStart)/2 + obj.minStart;
    end
  else
    if obj.lastF1 < obj.targetF1
      obj.nextPt = (obj.maxPt - obj.lastPt)/2 + obj.lastPt;
      obj.minPt = obj.lastPt;
    elseif obj.lastF1 >= obj.targetF1
      obj.nextPt = obj.lastPt - (obj.lastPt - obj.minPt)/2;
      obj.maxPt = obj.lastPt;
    end
  end

  epoch.addParameter('contrast', obj.nextPt);
end

function tf = shouldContinuePreparingEpochs(obj)
  tf = obj.numEpochsPrepared < obj.numberOfAverages;
 end

function tf = shouldContinueRun(obj)
  tf = obj.numEpochsCompleted < obj.numberOfAverages;
end

end % methods
end % classdef
