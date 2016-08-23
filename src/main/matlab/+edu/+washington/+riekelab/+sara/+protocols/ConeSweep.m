classdef ConeSweep < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp
  stimClass = 'lms'
  useCustomConeIso = false
  reverseOrder = false
  preTime = 200
  stimTime = 1000
  tailTime = 200
  contrast = 1
  backgroundIntensity = 0.5
  radius = 100
  centerOffset = [0,0]
  temporalFrequency = 2
  temporalClass = 'sinewave'
  onlineAnalysis = 'none'
  numberOfAverages = uint16(12)
end

properties (Hidden)
  ampType
  stimClassType = symphonyui.core.PropertyType('char', 'row', {'lms', 'alms', 'cpy', 'alms', 'ysa'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'flash'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  chromaticClass
  currentColorWeights
  currentEpoch
end

properties (Hidden) % online analysis properties
  stimTrace
  stimValues
  sweepColor
  plotColors
  F1
  F2
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

  % find plotColors
  for ii = 1:length(obj.stimClass)
    colorCall = obj.stimClass(ii);
    [~, obj.plotColors(ii, :), ~] = setColorWeightsLocal(obj, colorCall);
  end

  % trace for response figure
  x = 0:0.001:((obj.stimTime - 1) * 1e-3);
  obj.stimValues = zeros(1, length(x));
  for ii = 1:length(x)
    if strcmp(obj.temporalClass, 'sinewave')
      obj.stimValues(1,ii) = obj.contrast * sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
    elseif strcmp(obj.temporalClass, 'squarewave')
      obj.stimValues(1,ii) = obj.contrast * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
    end
  end

  obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

    % preallocate variables for F1figure
    obj.f1amp = zeros(obj.numberOfAverages/obj.length(stimClass), length(obj.stimClass));
    obj.f1phase = zeros(size(obj.f1amp));

    % set up figures
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);

    if ~strcmp(obj.onlineAnalysis, 'none')
      obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure', obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace);
      obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CTRAnalysis);
      f = obj.analysisFigure.getFigureHandle();
      set(f, 'Name', 'cone sweep f1');
      obj.analysisFigure.userData.axesHandle = axes('Parent', f);
    end
  end

  function CTRAnalysis(obj, ~, epoch)
    response = epoch.getResponse(obj.rig.getDevice(obj.amp));
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    % Analyze response by type
    responseTrace = obj.getResponseByType(responseTrace, obj.onlineAnalysis);

    responseTrace = responseTrace(obj.preTime/1000*sampleRate+1 : end);
    binRate = 60;
    binWidth = sampleRate/binRate;
    numBins = floor(obj.stimTime/1000 * binRate);
    binData = zeros(1, numBins);
    for k = 1 : numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end
    binsPerCycle = binRate / obj.temporalFrequency;
    numCycles = floor(length(binData)/binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));

    for k = 1:numCycle
      index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
      cycleData = cycleData + binData(index);
    end
    cycleData = cycleData / k;

    % get the F1 response
    ft = fft(cycleData);
    f1amp = abs(ft(2))/length(ft)*2;
    f1phase = angle(ft(2)) * 180/pi;

    obj.currentEpoch = obj.numEpochsCompleted + 1;
    index = rem(obj.currentEpoch,length(obj.stimClass));
    if index == 0
      index = length(obj.stimClass);
    end
    trial = ceil(obj.currentEpoch/obj.numberOfAverages);

    obj.f1amp(index, trial) = f1amp;
    obj.f1phase(index, trial) = f1phase;

    % plot the f1
    axesHandle = obj.analysisFigure.userData.axesHandle;
    cla(axesHandle);
    hold(axesHandle, 'on');
    for ii = 1:length(obj.stimClass)
      c1 = obj.plotColors(ii,:); c2 = c1 + ((1-c1).*0.5);
      plot(obj.f1phase(ii,:), obj.f1amp(ii, :), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2, 'Parent', axesHandle);
      plot(mean(obj.f1phase(ii,:), 2), mean(obj.f1amp(ii,:), 2), 'o', 'MarkerFaceColor', 'MarkerEdgeColor', c1,'Parent', axesHandle);
    end
    hold(axesHandle,'off');
    set(axesHandle,'TickDir', 'out');
    set(axesHandle, 'XLim', [-180 180]);
    ylabel(axesHandle, 'F1 amplitude');
    xlabel(axesHandle, 'F1 phase');
    title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', axesHandle);
  end

  function p = createPresentation(obj)

    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    spot = stage.builtin.stimuli.Ellipse();
    spot.radiusX = obj.radius;
    spot.radiusY = obj.radius;
    spot.position = obj.canvasSize/2 + obj.centerOffset;

    % control when the spot is visible
    spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

    % Add the stimulus to the presentation.
    p.addStimulus(spot);
    p.addController(spotVisibleController);
    p.addController(spotColorController);

      function c = getSpotColor(obj, time)
          if time >= 0
              if strcmp(obj.temporalClass, 'sinewave')
                c = obj.contrast * obj.currentColorWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
              elseif strcmp(obj.temporalClass, 'squarewave')
                 c = obj.contrast * obj.currentColorWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
              end
          else
              c = obj.backgroundIntensity;
          end
      end
  end

  function prepareEpoch(obj, epoch)
      prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

      obj.currentEpoch = obj.numEpochsCompleted + 1;

      index = rem(obj.currentEpoch,length(obj.stimClass));
      if index == 0
        index = length(obj.stimClass);
      end
      colorCall = obj.stimClass(index);

      [obj.currentColorWeights, obj.sweepColor, obj.chromaticClass]  = setColorWeightsLocal(obj, colorCall);
       obj.plotColor = obj.sweepColor;
      epoch.addParameter('chromaticClass', obj.chromaticClass);
      epoch.addParameter('sweepColor') = obj.sweepColor;

  end

  function tf = shouldContinuePreparingEpochs(obj)
    tf = obj.numEpochsPrepared < obj.numberOfAverages;
   end

   function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
   end
end
end
