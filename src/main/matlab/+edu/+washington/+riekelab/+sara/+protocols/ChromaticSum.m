classdef ChromaticSum < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
% goal to replicate 1978 figure

properties
  amp
  preTime = 500
  stimTime = 500
  tailTime = 500
  radius = 456
  paradigmClass = 'yellow'
  contrast = 1
  backgroundIntensity = 0.5
  centerOffset = [0,0]
  onlineAnalysis = 'none'
  numberOfAverages = uint16(3)
end


properties (Hidden)
  ampType
  stimClass
  paradigmClass = symphonyui.core.PropertyType('char', 'row', {'yellow', 'cyan', 'purple'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  plotColor
  sweepColor
  stimValues
  stimTrace
end

methods
function didSetRig(obj)
  didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
  [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
  prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

  % get stim trace
  x = 0:0.001:((obj.stimTime - 1) * 1e-3);
  stimValues = ones(1, length(x));
  obj.stimTrace = [obj.backgroundIntensity + zeros(1, obj.preTime) obj.stimValues obj.backgroundIntensity + zeros(1, obj.tailTime)];
  % get stim class
  if strcmp(obj.paradigmClass, 'yellow')
    obj.stimClass = 'rgy';
  elseif strcmp(obj.paradigmClass, 'cyan')
    obj.stimClass = 'gbc';
  elseif strcmp(obj.paradigmClass, 'purple')
    obj.stimClass = 'rbp';
  end

  obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);

  if strcmp(obj.onlineAnalysis, 'none')
    obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure', obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace);
  end
end

function p = createPresentation(obj)
  p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
  p.setBackgroundColor(obj.backgroundIntensity);

  % create spot stimulus
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
      if obj.backgroundIntensity == 0
        c = obj.colorWeights * obj.contrast;
      else
        obj.intensity = obj.backgroundIntensity * (obj.contrast * obj.colorWeights) + obj.backgroundIntensity;
      end
    else
      c = obj.backgroundIntensity;
    end
  end
end


function prepareEpoch(obj, epoch)
  prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

  obj.currentEpoch = obj.numEpochsCompleted + 1;

  index = rem(obj.currentEpoch, length(obj.stimClass));
  if index == 0
    index = length(obj.stimClass);
  end
  colorCall = obj.stimClass(index);

  [obj.currentColorWeights, obj.sweepColor, obj.chromaticClass] = setColorWeightsLocal(obj.colorCall);
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
