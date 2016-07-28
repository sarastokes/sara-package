classdef LinearSpots < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
    % test spatial (non)linearity - checks if inputs sum/null


    % 18Jul - currently only makes sense for achromatic

properties
  amp
  preTime = 200                         % time before stim (ms)
  stimTime = 200                        % stim duration (ms)
  tailTime = 200                        % time after stim (ms)
  backgroundIntensity = 0.5             % mean light level (0-1)
  centerOffsetA = [-200,-200]           % location of spot A (pix: x,y)
  radiusA = 75                          % size of spot A (pix)
  centerOffsetB = [200,200]             % location of spot B (pix - x,y)
  radiusB = 75                          % size of spot B (pix)
  chromaticClassA = 'achromatic'        % spot A color
  chromaticClassB = 'achromatic'        % spot B color
  paradigmClass = 'sum_up'              % experiment sequence
  controlSpot = false                   % include a control spot
  controlContrast = 1                   % increment or decrement (0-1)
  centerOffsetC = [0,0]                 % if true, control spot center
  radiusC = 100                         % if true, control spot radius
  chromaticClassC = 'achromatic'        % if true, control spot color
  onlineAnalysis = 'none'               % online analysis type
  numberOfAverages = uint16(1)          % number of epochs
end

properties (Hidden)
  ampType
  paradigmClassType = symphonyui.core.PropertyType('char', 'row', {'sum_up', 'sum_down', 'null_wb', 'null_bw', 'baselineA_up', 'baselineB_up', 'baselineA_down', 'baselineB_down'})
  chromaticClassAType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
  chromaticClassBType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
  chromaticClassCType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  spotValues
  colorWeightsA
  colorWeightsB
  colorWeightsC
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
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

    if strcmp(obj.paradigmClass, 'baselineA_up')
      obj.spotValues = [1, obj.backgroundIntensity];
    elseif strcmp(obj.paradigmClass, 'baselineA_down')
      obj.spotValues = [0, obj.backgroundIntensity];
    elseif strcmp(obj.paradigmClass, 'baselineB_up')
      obj.spotValues = [obj.backgroundIntensity, 1];
    elseif strcmp(obj.paradigmClass, 'baselineB_down')
      obj.spotValues = [obj.backgroundIntensity, 0];
    elseif strcmp(obj.paradigmClass, 'sum_up')
      obj.spotValues = [1, 1];
    elseif strcmp(obj.paradigmClass, 'sum_down')
      obj.spotValues = [0, 0];
    elseif strcmpi(obj.paradigmClass, 'null_wb')
      obj.spotValues = [1, 0];
    elseif strcmpi(obj.paradigmClass, 'null_bw')
      obj.spotValues = [0, 1];
    end

    if obj.controlSpot
      obj.stimPerSweep = 3;
      obj.spotValues(end+1) = obj.controlContrast;
    else
      obj.stimPerSweep = 2;
    end

    for ii = 1:length(obj.spotValues)
      obj.stimValue(ii, :) = obj.spotValues(ii) * ones(1, obj.stimTime);
    end

    obj.stimTrace = [(obj.backgroundIntensity * ones(obj.stimPerSweep, obj.preTime)) obj.stimValue (obj.backgroundIntensity * ones(obj.stimPerSweep, obj.tailTime))];

    [obj.colorWeightsA, ~, ~] = setColorWeightsLocal(obj, obj.chromaticClassA);
    [obj.colorWeightsB, ~, ~] = setColorWeightsLocal(obj, obj.chromaticClassB);

    if obj.controlSpot && ~strcmp(obj.chromaticClassC, 'achromatic')
      obj.colorWeightsC = setColorWeightsLocal(obj, obj.chromaticClassC);
    end

    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace, 'stimPerSweep', obj.stimPerSweep);
  end

  function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    % 1st spot setup
    spotA = stage.builtin.stimuli.Ellipse();
    spotA.radiusX = obj.radiusA; spotA.radiusY = obj.radiusA;
    spotA.position = obj.canvasSize/2 + obj.centerOffsetA;
    if strcmp(obj.chromaticClassA, 'achromatic')
      spotA.color = obj.spotValues(1);
    else
      spotA.color = obj.colorWeightsA * obj.spotValues(1);
    end
    visibleControllerA = stage.builtin.controllers.PropertyController(spotA, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    % 2nd spot setup
    spotB = stage.builtin.stimuli.Ellipse();
    spotB.radiusX = obj.radiusB; spotB.radiusY = obj.radiusB;
    spotB.position = obj.canvasSize/2 + obj.centerOffsetB;
    if strcmp(obj.chromaticClassB, 'achromatic')
      spotB.color = obj.spotValues(2);
    else
      spotB.color = obj.colorWeightsB * obj.spotValues(2);
    end
    % 2nd spot controllers
    visibleControllerB = stage.builtin.controllers.PropertyController(spotB, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    if obj.controlSpot
      spotC = stage.builtin.stimuli.Ellipse();
      spotC.radiusX = obj.radiusC; spotC.radiusY = obj.radiusC;
      spotC.position = obj.canvasSize/2 + obj.centerOffsetC;
      if strcmp(obj.chromaticClassC, 'achromatic')
        spotC.color = obj.controlContrast;
      else
        spotC.color = obj.colorWeightsC * obj.controlContrast;
      end
      visibleControllerC = stage.builtin.controllers.PropertyController(spotC, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
    end

    p.addStimulus(spotA);
    p.addController(visibleControllerA);

    p.addStimulus(spotB);
    p.addController(visibleControllerB);

    if obj.controlSpot
      p.addStimulus(spotC);
      p.addController(visibleControllerC);
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
