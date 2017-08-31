classdef LinearSpots < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % test spatial (non)linearity - checks if inputs sum/null
    % 3Aug - fixed issue for cone-iso stim

properties
  amp
  greenLED = '570nm'                    % Green LED
  preTime = 200                         % time before stim (ms)
  stimTime = 200                        % stim duration (ms)
  tailTime = 200                        % time after stim (ms)
  lightMean = 0.5             % mean light level (0-1)
  centerOffsetOne = [-200,-200]         % location of spot A (pix: x,y)
  radiusOne = 75                        % size of spot A (pix)
  centerOffsetTwo = [200,200]           % location of spot B (pix - x,y)
  radiusTwo = 75                        % size of spot B (pix)
  chromaticClassOne = 'achromatic'      % spot A color
  chromaticClassTwo = 'achromatic'      % spot B color
  paradigmClass = 'sum_up'              % experiment sequence
  controlSpot = false                   % include a control spot
  controlContrast = 1                   % increment or decrement (0-1)
  controlCenterOffset = [0,0]                 % if true, control spot center
  controlRadius = 100                         % if true, control spot radius
  chromaticClassThree = 'achromatic'        % if true, control spot color
  onlineAnalysis = 'none'               % online analysis type
  numberOfAverages = uint16(1)          % number of epochs
end

properties (Hidden)
  ampType
  greenLEDType = symphonyui.core.PropertyType('char', 'row', {'570nm','505nm'})
  paradigmClassType = symphonyui.core.PropertyType('char', 'row', {'sum_up', 'sum_down', 'null_wb', 'null_bw', 'baselineA_up', 'baselineB_up', 'baselineA_down', 'baselineB_down'})
  chromaticClassOneType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'custom', 'LM-iso'})
  chromaticClassTwoType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'custom', 'LM-iso'})
  chromaticClassThreeType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'custom', 'LM-iso'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  spotValues
  colorWeightsOne
  colorWeightsTwo
  colorWeightsThree
end

properties (Hidden) % relating to online analysis
  stimPerSweep
  stimValue
  stimTrace
%  plotColor
end

methods
function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
    prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

    clear obj.stimValue;
    if strcmp(obj.paradigmClass, 'baselineA_up')
      obj.spotValues = [1, obj.lightMean];
    elseif strcmp(obj.paradigmClass, 'baselineA_down')
      obj.spotValues = [0, obj.lightMean];
    elseif strcmp(obj.paradigmClass, 'baselineB_up')
      obj.spotValues = [obj.lightMean, 1];
    elseif strcmp(obj.paradigmClass, 'baselineB_down')
      obj.spotValues = [obj.lightMean, 0];
    elseif strcmp(obj.paradigmClass, 'sum_up')
      obj.spotValues = [1, 1];
    elseif strcmp(obj.paradigmClass, 'sum_down')
      obj.spotValues = [0, 0];
    elseif strcmp(obj.paradigmClass, 'null_wb')
      obj.spotValues = [1, 0];
    elseif strcmp(obj.paradigmClass, 'null_bw')
      obj.spotValues = [0, 1];
    end

    if obj.controlSpot
      obj.stimPerSweep = 3;
      obj.spotValues(end+1) = obj.controlContrast;
    else
      obj.stimPerSweep = 2;
      obj.stimValue = zeros(2, obj.stimTime);
    end

    for ii = 1:obj.stimPerSweep
      obj.stimValue(ii, :) = obj.spotValues(1, ii) * ones(1, obj.stimTime);
    end
    n = size(obj.stimValue);
    fprintf('Size of stimValue is %u, %u\n', n(1), n(2));

    obj.stimTrace = [(obj.lightMean * ones(obj.stimPerSweep, obj.preTime)) obj.stimValue (obj.lightMean * ones(obj.stimPerSweep, obj.tailTime))];
    n = size(obj.stimTrace);
    fprintf('Size of stimTrace is %u, %u\n', n(1), n(2));

    [obj.colorWeightsOne, ~, ~] = setColorWeightsLocal(obj, obj.chromaticClassOne);
    [obj.colorWeightsTwo, ~, ~] = setColorWeightsLocal(obj, obj.chromaticClassTwo);

    if obj.controlSpot && ~strcmp(obj.chromaticClassThree, 'achromatic')
      obj.colorWeightsThree = setColorWeightsLocal(obj, obj.chromaticClassThree);
    end

    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure', obj.rig.getDevice(obj.amp), 'stimTrace', obj.stimTrace, 'stimPerSweep', obj.stimPerSweep);
  end

  function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.lightMean);

    % 1st spot setup
    spotOne = stage.builtin.stimuli.Ellipse();
    spotOne.radiusX = obj.radiusOne; spotOne.radiusY = obj.radiusOne;
    spotOne.position = obj.canvasSize/2 + obj.centerOffsetOne;
    if strcmp(obj.chromaticClassOne, 'achromatic')
      spotOne.color = obj.spotValues(1);
    else
      spotOne.color = (2*obj.colorWeightsOne - 1) * obj.spotValues(1);
    end
    visibleControllerA = stage.builtin.controllers.PropertyController(spotOne, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    % 2nd spot setup
    spotTwo = stage.builtin.stimuli.Ellipse();
    spotTwo.radiusX = obj.radiusTwo; spotTwo.radiusY = obj.radiusTwo;
    spotTwo.position = obj.canvasSize/2 + obj.centerOffsetTwo;
    if strcmp(obj.chromaticClassTwo, 'achromatic')
      spotTwo.color = obj.spotValues(2);
    else
      spotTwo.color = (2*obj.colorWeightsTwo - 1) * obj.spotValues(2);
    end
    % 2nd spot controllers
    visibleControllerB = stage.builtin.controllers.PropertyController(spotTwo, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    if obj.controlSpot
      spotThree = stage.builtin.stimuli.Ellipse();
      spotThree.radiusX = obj.controlRadius; spotThree.radiusY = obj.controlRadius;
      spotThree.position = obj.canvasSize/2 + obj.controlCenterOffset;
      if strcmp(obj.chromaticClassThree, 'achromatic')
        spotThree.color = obj.controlContrast;
      else
        spotThree.color = obj.colorWeightsThree * (2*obj.controlContrast - 1);
      end
      visibleControllerC = stage.builtin.controllers.PropertyController(spotThree, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
    end

    p.addStimulus(spotOne);
    p.addController(visibleControllerA);

    p.addStimulus(spotTwo);
    p.addController(visibleControllerB);

    if obj.controlSpot
      p.addStimulus(spotThree);
      p.addController(visibleControllerC);
    end
  end

  function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

  end

  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end
end
