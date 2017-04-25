classdef ConeSweep < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocolSara

properties
  amp
  stimClass = 'lms'
  preTime = 200
  stimTime = 1000
  tailTime = 200
  contrast = 1
  backgroundIntensity = 0.5
  radius = 1500
  maskRadius = 0
  temporalClass = 'sinewave'
  temporalFrequency = 2
  centerOffset = [0,0]
  equalQuantalCatch = false
  checkSpikes = false                     % pulls up SpikeDetectionFigure
  onlineAnalysis = 'extracellular'
  numberOfAverages = uint16(9)
end

properties (Hidden)
  ampType
  stimClassType = symphonyui.core.PropertyType('char', 'row', {'lms', 'olms', 'alms', 'klms', 'cpy', 'ysa', 'lmx', 'zwx', 'azwx' 'almx', 'yxa', 'rgb', 'rgby', 'ghij'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'flash'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  chromaticClass
  stimulusClass
  currentColorWeights
  currentContrast
  currentEpoch
end

properties (Hidden) % online analysis properties
  stimTrace
  stimValues
  sweepColor
  plotColors
  plotColor % some of these are unnecessary, condense later
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

  % set stimulus class
  if obj.maskRadius == 0
    obj.stimulusClass = 'spot';
  else
    obj.stimulusClass = 'annulus';
  end

  % find plotColors
  if ~isempty(strfind(obj.stimClass, 'rgb'))
    leds = {'red' 'green' 'blue' 'yellow'};
    for ii = 1:length(obj.stimClass)
      colorCall = leds(ii);
      [~, obj.plotColors(ii,:), ~] = setColorWeightsLocal(obj, colorCall);
    end
  else
    for ii = 1:length(obj.stimClass)
      colorCall = obj.stimClass(ii);
      [~, obj.plotColors(ii, :), ~] = setColorWeightsLocal(obj, colorCall);
    end
  end

  % trace for response figure
  x = 0:0.001:((obj.stimTime - 1) * 1e-3);
  obj.stimValues = zeros(1, length(x));
  for ii = 1:length(x)
    if strcmp(obj.temporalClass, 'sinewave')
      obj.stimValues(1,ii) = sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
    elseif strcmp(obj.temporalClass, 'squarewave')
      obj.stimValues(1,ii) = sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
    end
  end
  obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

  % set up figures
  if numel(obj.rig.getDeviceNames('Amp')) < 2
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);
  else
    obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
  end

  obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure', obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace);

  if ~strcmp(obj.onlineAnalysis, 'none')
    if strcmp(obj.onlineAnalysis, 'extracellular') || strcmp(obj.onlineAnalysis, 'Spikes_CClamp')
       obj.showFigure('edu.washington.riekelab.sara.figures.ConeFiringRateFigure',...
      obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace, 'onlineAnalysis', obj.onlineAnalysis);
    end
  end
  if strcmp(obj.onlineAnalysis, 'extracellular') && obj.checkSpikes
    obj.showFigure('edu.washington.riekelab.sara.figures.SpikeDetectionFigure',...
      obj.rig.getDevice(obj.amp));
  end
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
                c = obj.currentContrast * obj.currentColorWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
              elseif strcmp(obj.temporalClass, 'squarewave')
                 c = obj.currentContrast * obj.currentColorWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
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
      if ~isempty(strfind(obj.stimClass, 'rgb'))
        leds = {'red' 'green' 'blue' 'yellow'};
        colorCall = leds(index);
      else
        colorCall = obj.stimClass(index);
      end

      if obj.equalQuantalCatch && strcmp(obj.stimClass, 'lms')
        switch colorCall
          case 'm'
            obj.currentContrast = 0.73;
          case 's'
            obj.currentContrast = 0.28;
          otherwise
            obj.currentContrast = 1;
        end
      else
        obj.currentContrast = obj.contrast;
      end
      epoch.addParameter('currentContrast', obj.currentContrast);

      [obj.currentColorWeights, obj.sweepColor, obj.chromaticClass]  = setColorWeightsLocal(obj, colorCall);
      obj.plotColor = obj.sweepColor;
      epoch.addParameter('chromaticClass', obj.chromaticClass);
      epoch.addParameter('sweepColor', obj.sweepColor);
      epoch.addParameter('stimulusClass', obj.stimulusClass);

  end

  function tf = shouldContinuePreparingEpochs(obj)
    tf = obj.numEpochsPrepared < obj.numberOfAverages;
   end

  function tf = shouldContinueRun(obj)
    tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end
end
