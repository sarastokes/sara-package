classdef LinearGratings < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
% still needs troubleshooting

properties
  amp
  preTime = 200                         % time before stim (ms)
  stimTime = 200                        % stim duration (ms)
  tailTime = 200                        % time after stim (ms)
  backgroundIntensity = 0.5             % mean light level (0-1)
  paradigmClass = 'null'                % WILL ONLY RUN IF PHASEOFFSET=0
  phaseOffset = 0                       % only set if diff than sum or null
  temporalClass = 'squarewave'          % sine or squarewave
  temporalFrequency = 2
  centerOffsetOne = [-200,-200]         % location of spot A (pix: x,y)
  radiusOne = 75                        % size of spot A (pix)
  contrastOne = 1
  chromaticClassOne = 'achromatic'      % spot A color
  centerOffsetTwo = [200,200]           % location of spot B (pix - x,y)
  radiusTwo = 75                        % size of spot B (pix)
  contrastTwo = 1
  chromaticClassTwo = 'achromatic'      % spot B color
  onlineAnalysis = 'none'               % online analysis type
  numberOfAverages = uint16(3)          % number of epochs
end

properties (Hidden)
  ampType
  paradigmClassType = symphonyui.core.PropertyType('char', 'row', {'sum', 'null', 'baselineOne','baselineTwo'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
  chromaticClassOneType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'custom', 'LM-iso'})
  chromaticClassTwoType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'custom', 'LM-iso'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  colorWeightsOne
  colorWeightsTwo
  phaseRads
end

properties (Hidden) % relating to online analysis
  stimValues
  stimTrace
%  plotColor
end

methods
function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

    % set color weights
    [obj.colorWeightsOne, ~, ~] = setColorWeightsLocal(obj, obj.chromaticClassOne);
    [obj.colorWeightsTwo, ~, ~] = setColorWeightsLocal(obj, obj.chromaticClassTwo);

    % Calculate the spatial phase in radians.
    obj.phaseRads = obj.phaseOffset / 180 * pi;

    % Get the stim traces
    x = 0:0.001:((obj.stimTime - 1) * 1e-3);
    obj.stimValues = zeros(2, length(x));
    for ii = 1:length(x)
      if strcmp(obj.temporalClass, 'sinewave')
        obj.stimValues(1, ii) = obj.contrastOne * sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
        obj.stimValues(2, ii) = obj.contrastTwo * sin(obj.temporalFrequency * x(ii) * 2 * pi + obj.phaseRads) * obj.backgroundIntensity + obj.backgroundIntensity;
      else
        obj.stimValues(1, ii) = obj.contrastOne * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
        obj.stimValues(2, ii) = obj.contrastTwo * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi + obj.phaseRads)) * obj.backgroundIntensity + obj.backgroundIntensity;
      end
    end
    if strcmp(obj.paradigmClass, 'baselineOne')
      obj.stimValues(2,:) = 0.5;
    elseif strcmp(obj.paradigmClass, 'baselineTwo')
      obj.stimValues(1, :) = 0.5;
    end

    obj.stimTrace = [(obj.backgroundIntensity * ones(2, obj.preTime)) obj.stimValue (obj.backgroundIntensity * ones(2, obj.tailTime))];

    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace, 'stimPerSweep', 2);

  end

  function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    % 1st spot setup
    spotOne = stage.builtin.stimuli.Ellipse();
    spotOne.radiusX = obj.radiusOne; spotOne.radiusY = obj.radiusOne;
    spotOne.position = obj.canvasSize/2 + obj.centerOffsetOne;

    % 1st spot controllers
    visibleControllerOne = stage.builtin.controllers.PropertyController(spotOne, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
    colorControllerOne = stage.builtin.controllers.PropertyController(spotOne, 'color', @(state)getSpotColorOne(obj, state.time - obj.preTime * 1e-3));

    % 2nd spot setup
    spotTwo = stage.builtin.stimuli.Ellipse();
    spotTwo.radiusX = obj.radiusTwo; spotTwo.radiusY = obj.radiusTwo;
    spotTwo.position = obj.canvasSize/2 + obj.centerOffsetTwo;

    % 2nd spot controllers
    visibleControllerTwo = stage.builtin.controllers.PropertyController(spotTwo, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
    colorControllerTwo = stage.builtin.controllers.PropertyController(spotTwo, 'color', @(state)getSpotColorTwo(obj, state.time - obj.preTime * 1e-3));

    p.addStimulus(spotOne);
    p.addController(visibleControllerOne);
    p.addController(colorControllerOne);

    p.addStimulus(spotTwo);
    p.addController(visibleControllerTwo);
    p.addController(colorControllerTwo);

    function c = getSpotColorOne(obj, time)
      if strcmp(obj.paradigmClass, 'baselineTwo')
        c = obj.backgroundIntensity;
      elseif time >=0
          if strcmp(obj.temporalClass, 'sinewave')
            c = obj.contrastOne * obj.colorWeightsOne * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
          else
            c = obj.contrastOne * obj.colorWeightsOne * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
          end
      else
        c = obj.backgroundIntensity;
      end
    end

    function c = getSpotColorTwo(obj, time)
      if strcmp(obj.paradigmClass, 'baselineOne')
        c = obj.backgroundIntensity;
      elseif time >=0
        if strcmp(obj.temporalClass, 'sinewave')
          c = obj.contrastTwo * obj.colorWeightsTwo * sin(obj.temporalFrequency * time * 2 * pi + obj.phaseRads) * obj.backgroundIntensity + obj.backgroundIntensity;
        else
          c = obj.contrastTwo * obj.colorWeightsTwo * sign(sin(obj.temporalFrequency * time * 2 * pi + obj.phaseRads)) * obj.backgroundIntensity + obj.backgroundIntensity;
        end
      else
        c = obj.backgroundIntensity;
      end
    end
  end

  function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

  end

  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end
end
