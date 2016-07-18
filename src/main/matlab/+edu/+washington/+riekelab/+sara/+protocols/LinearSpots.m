classdef LinearSpots < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp
  preTime = 200
  stimTime = 200
  tailTime = 200
  backgroundIntensity = 0.5             % mean light level (0-1)
  centerOffsetA = [-200,-200]           % location of spot A (pix: x,y)
  radiusA = 75                          % size of spot A (pix)
  centerOffsetB = [200,200]             % location of spot B (pix - x,y)
  radiusB = 75                          % size of spot B (pix)
  chromaticClassA = 'achromatic'        % spot A color
  chromaticClassB = 'achromatic'        % spot B color
  paradigmClass = 'sum_up'              % experiment sequence
  reverseOrder = false                  % reverse experiment order
  controlSpot = false                   % include a control spot
  controlContrast = 1                   % increment or decrement (0-1)
  centerOffsetC = [0,0]                 % if true, control spot center
  radiusC = 100                         % if true, control spot radius
  chromaticClassC = 'achromatic'        % if true, control spot color
  onlineAnalysis = 'none'
  numberOfAverages = uint16(1)          % might not include this
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

methods
function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

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

    obj.colorWeightsA = setColorWeightsLocal(obj, obj.chromaticClassA);
    obj.colorWeightsB = setColorWeightsLocal(obj, obj.chromaticClassB);

    if obj.controlSpot && ~strcmp(obj.chromaticClassC, 'achromatic')
      obj.colorWeightsC = setColorWeightsLocal(obj, obj.chromaticClassC);
    end


    function w = setColorWeightsLocal(obj, colorCall)
      switch colorCall
        case 'L-iso'
            w = obj.quantalCatch(:,1:3)' \ [1 0 0]';
            w = w / w(1);
        case 'M-iso'
            w = obj.quantalCatch(:,1:3)' \ [0 1 0]';
            w = w / w(2);
        case 'S-iso'
            w = obj.quantalCatch(:,1:3)' \ [0 0 1]';
            w = w / w(3);
        case 'LM-iso'
            w = obj.quantalCatch(:,1:3)' \ [1 1 0]';
            w = w / max(w);
        otherwise
            w = [1 1 1];
      end
      w = w(:)';
    end
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

    device = obj.rig.getDevice(obj.amp);
    duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
    epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
    epoch.addResponse(device);
  end

  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end
end