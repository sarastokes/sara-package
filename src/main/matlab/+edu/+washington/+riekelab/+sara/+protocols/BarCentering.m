classdef BarCentering < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

  properties
    amp
    preTime = 500                   % Spot leading duration (ms)
    stimTime = 500                  % Spot duration (ms)
    tailTime = 500                  % Spot trailing duration (ms)
    orientation = 0                 % degrees
    position = [-0.9:0.1:0.9]
    centerOffset = [0,0]
    barSize = [300, 100]
    intensity = 1
    backgroundIntensity = 0.5
    onlineAnalysis = 'none'         % Online analysis type - need this
    numberOfAverages = uint16(1)    % number of epochs
  end

  properties (Hidden)
    ampType
    onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    canvasSize
    frameRate
    % intensity
    stageClass
    currentPosition
    % orientation
    % orientationRads
  end

  properties (Hidden, Transient)
      % figure for online analysis
  end

  methods
    function didSetRig(obj)
        didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
        [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
    end

    function prepareRun(obj)
        prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

        % get frame rate. need to check if it's a LCR rig.
        %if ~isempty(strfind(obj.rig.getDevice('Stage').name,'LightCrafter'))
      %    obj.frameRate = obj.rig.getDevice('Stage').getPatternRate();
      %  else
      %    obj.frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
      %  end

        obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

        obj.organizeParameters();
      end

      function organizeParameters(obj)
        % calculate the number of repetitions of each bar position
        numReps = ceil(double(obj.numberOfAverages) / length(obj.positions));

        % set the sequence
        obj.sequence = obj.positions(:) * ones(1, numReps);
        obj.sequence = obj.sequence(:)';

        % would we ever want random order?
        epochSyntax = 1:obj.numberOfAverages;

        obj.sequence = obj.sequence(epochSyntax);
      end

      function p = createPresentation(obj)
        p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
        p.setBackgroundColor(obj.backgroundIntensity);

        rect = stage.builtin.stimuli.Rectangle();
        rect.size = obj.barSize;
        % rect.position = obj.canvasSize/2 + obj.centerOffset
        rect.orientation = obj.orientation;
        if rect.orientation == 0
          Xpos = 0;
          Ypos = obj.centerOffset(2) +((obj.canvasSize/2)*obj.position);
        elseif rect.orientation == 180
          Ypos = 0;
          Xpos = obj.centerOffset(1) + ((obj.canvasSize/2)*obj.position);
        end
        rect.position = [Xpos, Ypos];
        rect.color = obj.intensity;

        % add the stimulus to the presentation
        p.addStimulus(rect);
      end

      function prepareEpoch(obj, epoch)
        prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj,epoch);

        device = obj.rig.getDevice(obj.amp);
        duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
        % is this for storing data?
        epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
        epoch.addResponse;

        obj.position = obj.sequence(obj.numEpochsCompleted+1);

        %epoch.addParameter('x', obj.x);
        epoch.addParameter('position', obj.position);

      end

      function tf = shouldContinuePreparingEpochs(obj)
        tf = numEpochsPrepared < obj.numberOfAverages;
      end

      function tf = shouldContinueRun(obj)
        tf = obj.numEpochsCompleted < obj.numberOfAverages;
      end
    end
  end
