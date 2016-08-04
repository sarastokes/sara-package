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
  stimClassType = symphonyui.core.PropertyType('char', 'row', {'lms', 'alms', 'sy', 'sya', 'cpy'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'flash', 'flash_up', 'flash_down'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
%  numberOfAverages
  sweepColor
  numStim
  colorList
  currentColorWeights
  chromaticClass
  stimTrace
  stimValues
  plotColor
  currentEpoch
  epColors
  epochNames
end

methods
function didSetRig(obj)
  didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

  [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
  prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

  % trace for response figure
  x = 0:0.001:((obj.stimTime - 1) * 1e-3);
  obj.stimValues = zeros(1, length(x));
  if strcmp(obj.temporalClass, 'flash_up')
      obj.stimValues(:) = 1;
  elseif strcmp(obj.temporalClass, 'flash_down')
      obj.stimValues(:) = 0;
  else
      for ii = 1:length(x)
        if strcmp(obj.temporalClass, 'sinewave')
          obj.stimValues(1,ii) = obj.contrast * sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
      elseif strcmp(obj.temporalClass, 'squarewave')
          obj.stimValues(1,ii) = obj.contrast * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
        end
      end
    end
    obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);


    if ~strcmp(obj.onlineAnalysis, 'none')
      obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure', obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace);
    end
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
%              elseif strcmp(obj.temporalClass, 'flash_up')
%                  c = 1 * obj.currentColorWeights;
%              elseif strcmp(obj.temporalClass, 'flash_down')
%                  c = -1 * obj.currentColorWeights;
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

  end

  function tf = shouldContinuePreparingEpochs(obj)
    tf = obj.numEpochsPrepared < obj.numberOfAverages;
   end

   function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
   end
end
end
