classdef LEDcalibration < edu.washington.riekelab.protocols.RiekeLabStageProtocol
properties
  amp
  chromaticClass = 'black'
  preTime = 200               % pre/tail prob aren't necessary but I threw them in just in case
  stimTime = 100000
  tailTime = 200
  centerOffset = [0,0]
  backgroundIntensity = 0             % or could this be the color?
  onlineAnalysis = 'none'
  numberOfAverages = uint16(1)
end

properties (Hidden)
  ampType
  chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic','R','G','B','S-iso','M-iso','L-iso'})
  colorWeights
  canvasSize
  rawImage              % i don't think i need this?
end

methods

  function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
  end

  function prepareRun(obj)
    prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

    obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
    % set the LED weights
    obj.setColorWeights();
  end

  function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity); % do i need this/color?
  end

    % Set LED weights based on grating type.
    function setColorWeights(obj)
      switch obj.chromaticClass
      case 'R'
        obj.colorWeights = [1 0 0];
      case 'G'
        obj.colorWeights = [0 1 0];
      case 'B'
        obj.colorWeights = [0 0 1];
      case 'dark'
        obj.colorWeights = [0 0 0];
      case 'white'
        obj.colorWeights = [1 1 1];
      case 'UV'
        % I'm not totally sure what to do here as it won't be an RGB value. Special non-Matlab code to interface directly with the UV LED?
      end
    end

    function prepareEpoch(obj, epoch)
      prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

      device = obj.rig.getDevice(obj.amp);
      duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
      % where was sample rate defined? does it need to be defined or just default?
      epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
      epoch.addResponse(device);   % probably don't need this either

      % is this when I'd add parameters for saving the color (if needed)?
    end

%% These two seem unneccessary but I left them in just in case
    function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages + 1
    end

    function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages + 1;
    end
  end
end
