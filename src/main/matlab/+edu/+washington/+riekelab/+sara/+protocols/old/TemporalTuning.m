classdef TemporalTuning < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp
  preTime = 250
  stimTime = 2000
  tailTime = 250
  contrast = 1
  chromaticClass = 'achromatic'
  temporalFrequencies = [0.5 1 2 4 8 16 32]
  temporalClass = 'sinewave'
  radius = 100
  centerOffset = [0 0]
  maskRadius = 0
  randomizeOrder = false % not ready
  backgroundIntensity = 0.5
  onlineAnalysis = 'extracellular'
  numberOfAverages = uint16(8)
end

properties (Hidden)
  ampType
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
  chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic','L-iso', 'M-iso', 'S-iso', 'red', 'green', 'blue', 'yellow', 'LM-iso', 'MS-iso', 'LS-iso'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  currentTemporalFrequency
  sequence
  epochCount
  plotColor
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

   [obj.colorWeights, obj.plotColor, ~] = setColorWeightsLocal(obj, obj.chromaticClass);

   x = 0:0.001:((obj.stimTime - 1) * 1e-3);
   stimTrace = zeros(length(obj.temporalFrequencies), obj.stimTime + obj.preTime + obj.tailTime);
   for jj = 1:length(obj.temporalFrequencies)
     stimValues = zeros(1, length(x));
     tempFreq = obj.temporalFrequencies(jj);
     for ii = 1:length(x)
       if strcmp(obj.temporalClass, 'sinewave')
         stimValues(1,ii) = sin(tempFreq * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
       else
         stimValues(1, ii) = sign(sin(tempFreq * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity);
       end
     end
     stimTrace(jj, :) = [(obj.backgroundIntensity * ones(1, obj.preTime)) stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];
   end

   obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace, 'stimColor', obj.plotColor);

   if ~strcmp(obj.onlineAnalysis, 'none')
     obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure', obj.rig.getDevice(obj.amp), obj.temporalFrequencies, obj.onlineAnalysis, obj.preTime, obj.stimTime, 'plotColor', obj.plotColor);
   end

   % add in randomize later
   obj.sequence = obj.temporalFrequencies;
 end

function p = createPresentation(obj)

  p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
  p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity

  % create spot
  spot = stage.builtin.stimuli.Ellipse();
  spot.radiusX = obj.radius;
  spot.radiusY = obj.radius;
  spot.position = obj.canvasSize/2 + obj.centerOffset;

  spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

  spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

  % add the stimulus to the presentation
  p.addStimulus(spot);
  p.addController(spotColorController);
  p.addController(spotVisibleController);

  function c = getSpotColor(obj, time)
    if time >= 0
      if strcmp(obj.temporalClass, 'sinewave')
        c = obj.contrast * obj.colorWeights * sin(obj.currentTemporalFrequency * time * 2 * pi)* obj.backgroundIntensity + obj.backgroundIntensity;
      else
        c = obj.contrast * obj.colorWeights * sign(sin(obj.currentTemporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
      end
    else
      c = obj.backgroundIntensity;
    end
  end
end

function prepareEpoch(obj, epoch)
  prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

  obj.currentTemporalFrequency = obj.sequence(obj.numEpochsCompleted + 1);

  epoch.addParameter('temporalFrequency', obj.currentTemporalFrequency);
end

function tf = shouldContinuePreparingEpochs(obj)
  tf = obj.numEpochsPrepared < obj.numberOfAverages;
end

function tf = shouldContinueRun(obj)
  tf = obj.numEpochsCompleted < obj.numberOfAverages;
end
end
end
