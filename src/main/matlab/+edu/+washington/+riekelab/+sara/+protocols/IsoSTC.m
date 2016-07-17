classdef IsoSTC < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp
  preTime = 500
  stimTime = 5000
  tailTime = 500
  contrast = 1                            %
  temporalFrequency = 2                   % modulation frequency
  radius = 150
  backgroundIntensity = 0.5
  centerOffset = [0,0]                    % spot center
  paradigmClass = 'ID';                   % sin/sqrwave OR gaussian noise
  temporalClass = 'sinewave'              % sin or squarewave for ID paradigm
  chromaticClass = 'achromatic'
  onlineAnalysis = 'none'
  randomSeed = true                       % use random seed w/ STA paradigm
  stdev = 0.3;                            % gaussian noise sd
  numberOfAverages = uint16(3)
end

properties (Hidden)
  ampType
  paradigmClassType = symphonyui.core.PropertyType('char', 'row', {'ID', 'STA'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
  chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'RGB','L-iso', 'M-iso', 'S-iso', 'LM-iso'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  bkg
  seed
  noiseStream
end

%properties (Hidden)
  % analysis properties
%end

%properties (Hidden, Transient)
%  analysisFigure
%end

methods
  function didSetRig(obj)
      didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

      [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
    end

  function prepareRun(obj)
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);
    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

    % why is this here?
    if obj.backgroundIntensity == 0
        obj.bkg = 0.5;
    else
        obj.bkg = obj.backgroundIntensity;
    end

%    if ~strcmp(obj.onlineAnalysis, 'none')
%    end
     

%    obj.organizeParameters();

    obj.setColorWeights();
  end

      % analysis figure functions

  function p = createPresentation(obj)

    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    spot = stage.builtin.stimuli.Ellipse();
    spot.radiusX = obj.radius;
    spot.radiusY = obj.radius;
    spot.position = obj.canvasSize/2 + obj.centerOffset;


    % control when the spot is visible
    spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    % control spot color
    if ~strcmp(obj.chromaticClass, 'achromatic')
      spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getChromatic(obj, state.time - obj.preTime * 1e-3));
    else
      spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getAchromatic(obj, state.time - obj.preTime * 1e-3));
    end


    % Add the stimulus to the presentation.
    p.addStimulus(spot);
    p.addController(spotColorController);
    p.addController(spotVisibleController);

    function c = getAchromatic(obj, time)
      if time >= 0
        if strcmpi(obj.paradigmClass, 'ID')
          if strcmpi(obj.temporalClass, 'squarewave')
            c = obj.contrast * sign(sin(obj.temporalFrequency*time*2*pi)) * obj.bkg + obj.bkg;
          else
            c = obj.contrast * sin(obj.temporalFrequency*time*2*pi) * obj.bkg + obj.bkg;
          end
        elseif strcmpi(obj.paradigmClass, 'STA')
          c = obj.stdev * obj.noiseStream.randn * obj.bkg + obj.bkg;
        end
      else
        c = obj.bkg;
      end
    end

    function c = getChromatic(obj, time)
      if time >= 0
        if strcmpi(obj.paradigmClass, 'ID')
          if strcmpi(obj.temporalClass, 'squarewave')
            c = obj.contrast * obj.colorWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.bkg + obj.bkg;
            c = c(:)';
          else
            c = obj.contrast * obj.colorWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.bkg + obj.bkg;
            c = c(:)';
          end
        elseif strcmpi(obj.paradigmClass, 'STA')
          c = obj.stdev * (obj.noiseStream.randn * obj.colorWeights) * obj.bkg + obj.bkg;
          c = c(:)';
        end
      else
        c = obj.bkg;
      end
    end
  end
    function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

    device = obj.rig.getDevice(obj.amp);
    duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
    epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
    epoch.addResponse(device);

    if strcmpi(obj.paradigmClass, 'STA')
      if obj.randomSeed
        obj.seed = RandStream.shuffleSeed;
      else
        obj.seed = 1;
      end
      obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);
    end
  end

  function tf = shouldContinuePreparingEpochs(obj)
    tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
    tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end

end
end
