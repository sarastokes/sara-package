classdef ChromaticSpatialNoise < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
% adapted from SpatialNoise.m
% online analysis not working yet, especially not for new iso stimuli

properties
    amp                             % Output amplifier
    preTime = 500                   % Noise leading duration (ms)
    stimTime = 10000                % Noise duration (ms)
    tailTime = 500                  % Noise trailing duration (ms)
    stixelSize = 25                 % Edge length of stixel (pix)
    frameDwell = 1                  % Number of frames to display any image
    intensity = 1.0                 % Max light intensity (0-1)
    backgroundIntensity = 0.5       % Background light intensity (0-1)
    centerOffset = [0,0]            % Center offset in pixels (x,y)
    maskRadius = 0                  % Mask radius in pixels.
    useRandomSeed = true            % Random seed (bool)
    noiseClass = 'binary'           % Noise class (binary or Gaussian)
    onlineAnalysis = 'none'
    runFullProtocol = true         % cycle thru LMS-iso
    equalQuantalCatch = false
    numberOfAverages = uint16(50)    % Number of epochs
end

properties (Hidden)
  ampType
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  noiseClassType = symphonyui.core.PropertyType('char', 'row', {'binary', 'gaussian'})
  chromaticClassType = symphonyui.core.PropertyType('char','row',{'achromatic','RGB', 'L-iso', 'M-iso', 'S-iso', 'custom'})
  noiseStream
  numXChecks
  numYChecks
  correctedMean
  correctedIntensity
  seed
  seedList
  frameValues
  backgroundFrame
  strf
  spatialRF
  stimTrace
  currentIntensity
  currentColorWeights
  colorWeightsMatrix
  currentChromaticClass
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

      stimValues = ones(1, obj.stimTime);
      obj.stimTrace = [(obj.backgroundIntensity * ones(1,obj.preTime)) stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

      obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);

      % Get the frame rate. Need to check if it's a LCR rig.
      if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
          obj.chromaticClass = 'achromatic';
      end

      % Calculate the corrected intensity.
      obj.correctedIntensity = obj.intensity * 255;
      obj.correctedMean = obj.backgroundIntensity * 255;

      % Calculate the number of X/Y checks.
      obj.numXChecks = ceil(obj.canvasSize(2)/obj.stixelSize);
      obj.numYChecks = ceil(obj.canvasSize(2)/obj.stixelSize);

      if obj.equalQuantalCatch
        obj.intensities = [1 0.77 0.28];
      end

      if obj.useRandomSeed
        for ii = 1:double(obj.numberOfAverages)
          obj.seedList(ii) = RandStream.shuffleSeed;
        end
        size(obj.seedList)
      end

      obj.colorWeightsMatrix = zeros(3,3);
      [obj.colorWeightsMatrix(1,:),~,~] = setColorWeightsLocal(obj, 'L-iso');
      [obj.colorWeightsMatrix(2,:),~,~] = setColorWeightsLocal(obj, 'M-iso');
      [obj.colorWeightsMatrix(3,:),~,~] = setColorWeightsLocal(obj, 'S-iso');

      % Automated analysis figure.
      if ~strcmp(obj.onlineAnalysis,'none')
        params = [obj.preTime, obj.stimTime, obj.numXChecks, obj.numYChecks, obj.frameRate, obj.frameDwell]; % params
        obj.showFigure('edu.washington.riekelab.sara.figures.ConeInputFigure', obj.rig.getDevice(obj.amp), obj.seedList, obj.onlineAnalysis, obj.noiseClass, params);
      end

      % Get the frame values for repeating epochs.
      if ~obj.useRandomSeed
          obj.seed = 1;
          obj.getFrameValues();
      end
  end

  function getFrameValues(obj) % called from prepareEpoch
      % Get the number of frames.
      numFrames = floor(obj.stimTime/1000 * obj.frameRate / obj.frameDwell);

      % Seed the random number generator.
      obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);

      % Deal with the noise type.
      % if strcmp(obj.noiseClass, 'binary')
        M = obj.noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks) > 0.5;
        M = (2*M)-1; % matrix of -1 and 1
        obj.frameValues = zeros(numFrames, obj.numYChecks, obj.numXChecks,3);
        for ii = 1:3
          obj.frameValues(:,:,:,ii) = obj.currentColorWeights(ii) * M;
        end
        obj.backgroundFrame = uint8(obj.backgroundIntensity*ones(obj.numYChecks,obj.numXChecks,3));
        obj.frameValues = uint8(obj.intensity*255*obj.frameValues);
      % elseif strcmp(obj.noiseClass, 'gaussian')
      %     M = uint8((0.3 * obj.intensity * obj.noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks) * 0.5 + 0.5) * 255);
      %     M = repmat(M, [1 1 1 3]);
      %     % for ii = 1:3
      %     %   M(:,:,:,ii) = obj.currentColorWeights(ii) * M(:,:,:,ii);
      %     % end
      %     M = uint8(255 *(obj.backgroundIntensity * M + obj.backgroundIntensity));
      %
      %     obj.backgroundFrame = uint8(obj.backgroundIntensity * ones(obj.numYChecks, obj.numXChecks,3));
      %     obj.frameValues = M;
      % end
  end

  function flipDurations = getFlips(obj)
      info = obj.rig.getDevice('Stage').getPlayInfo();
      %software timing
      flipDurations = info.flipDurations;
  end

  function p = createPresentation(obj)

      p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
      p.setBackgroundColor(obj.backgroundIntensity);

      % Create your noise image.
      % if strcmpi(obj.noiseClass, 'binary')
          imageMatrix = uint8((rand(obj.numYChecks, obj.numXChecks)>0.5) * obj.correctedIntensity);
          imageMatrix = (2 * imageMatrix) - 1;
      % else
      %     imageMatrix = uint8((0.3*randn(obj.numYChecks, obj.numXChecks) * obj.backgroundIntensity + obj.backgroundIntensity)*255);
      %     imageMatrix = (2*imageMatrix) - 1;
      % end
      checkerboard = stage.builtin.stimuli.Image(imageMatrix);
      checkerboard.position = obj.canvasSize / 2;
      checkerboard.size = [obj.numXChecks obj.numYChecks] * obj.stixelSize;

      % Set the minifying and magnifying functions to form discrete
      % stixels.
      checkerboard.setMinFunction(GL.NEAREST);
      checkerboard.setMagFunction(GL.NEAREST);

      % Add the stimulus to the presentation.
      p.addStimulus(checkerboard);

      gridVisible = stage.builtin.controllers.PropertyController(checkerboard, 'visible', ...
          @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
      p.addController(gridVisible);

      % Calculate preFrames and stimFrames
      preF = floor(obj.preTime/1000 * obj.frameRate);
      stimF = floor(obj.stimTime/1000 * obj.frameRate);

    imgController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix', @(state)setChromaticStixels(obj, state.frame - preF, stimF));
    p.addController(imgController);

      function s = setChromaticStixels(obj, frame, stimFrames)
          if frame > 0 && frame <= stimFrames
              index = ceil(frame/obj.frameDwell);
              s = squeeze(obj.frameValues(index,:,:,:));
          else
              s = obj.backgroundFrame;
          end
      end

      % Deal with the mask, if necessary.
      if obj.maskRadius > 0
          mask = stage.builtin.stimuli.Ellipse();
          mask.color = obj.backgroundIntensity;
          mask.radiusX = obj.maskRadius;
          mask.radiusY = obj.maskRadius;
          mask.position = obj.canvasSize / 2 + obj.centerOffset;
          p.addStimulus(mask);
      end
  end

  function prepareEpoch(obj, epoch)
      prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

      % get stim class
      index = rem(obj.numEpochsCompleted+1,3);
      if index == 0
        index = 3;
      end

      cones = 'lms';
      intensities = {1 0.77 0.28};
      if obj.equalQuantalCatch
        obj.currentIntensity = intensities(index);
      else
        obj.currentIntensity = obj.intensity;
      end
      obj.currentColorWeights = obj.colorWeightsMatrix(index,:);

      % obj.currentChromaticClass = cones(index); obj.currentChromaticClass
      % [obj.currentColorWeights,~,~] = setColorWeightsLocal(obj, obj.currentChromaticClass);
      % Deal with the seed.
      if obj.useRandomSeed
          obj.seed = obj.seedList(obj.numEpochsCompleted+1);
          % Get the frame values for the epoch.
                % Get the number of frames.
                obj.getFrameValues();
      end


      epoch.addParameter('seed', obj.seed);
      epoch.addParameter('numXChecks', obj.numXChecks);
      epoch.addParameter('numYChecks', obj.numYChecks);
      epoch.addParameter('chromaticClass',obj.currentChromaticClass);
      epoch.addParameter('currentIntensity', obj.currentIntensity);
  end

  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end
end
