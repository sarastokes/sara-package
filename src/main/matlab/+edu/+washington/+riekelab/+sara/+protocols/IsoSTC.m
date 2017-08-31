classdef IsoSTC < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % ID and get temporal RF - will divide up into seperate protocols eventually
    % 25Jul16 - rgb sta works, f1f2 mtf doesn't

properties
  amp                                     % amplifier
  greenLED = '570nm'                      % greenLED
  preTime = 500                           % before stim (ms)
  stimTime = 2000                         % stim duration (ms)
  tailTime = 500                          % after stim (ms)
  contrast = 1                            % contrast (0 - 1)
  temporalFrequency = 2                   % modulation frequency
  radius = 150                            % spot size (pixels)
  lightMean = 0.5               % mean (0 - 1)
  centerOffset = [0,0]                    % spot center (pixels x,y)
  paradigmClass = 'ID';                   % ID=sin/sqr, STA=gaussian noise
  temporalClass = 'sinewave'              % if ID, sine or sqrwave
  chromaticClass = 'achromatic'           % spot color!
  onlineAnalysis = 'none'                 % type of online analysis
  randomSeed = true                       % if STA, use random seed
  stdev = 0.3;                            % if STA, gaussian noise sd
  checkSpikes = false                     % pulls up SpikeDetectionFigure
  demoMode = false
  numberOfAverages = uint16(1)            % number of epochs
end

properties (Hidden)
  ampType
  greenLEDType = symphonyui.core.PropertyType('char', 'row', {'570nm','505nm'})
  paradigmClassType = symphonyui.core.PropertyType('char', 'row', {'ID', 'STA'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
  chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'achrom2','L-iso', 'M-iso', 'S-iso', 'LM-iso', 'MS-iso', 'LS-iso', 'LMS-iso' 'RGB-binary', 'RGB-gaussian', 'custom'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  seed
  noiseStream
end

properties (Hidden) % for online analysis
  xaxis
  F1
  F2
  linearFilter
  stimValues
  stimTrace
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
    prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
    
    obj.setLEDs();

    if numel(obj.rig.getDeviceNames('Amp')) < 2
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',... 
        obj.rig.getDevice(obj.amp), 'stimTrace', getLightStim(obj),... 
        'stimColor', getStimColor(obj.chromaticClass));
    else
      obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure',... 
          obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
    end

    if ~strcmp(obj.onlineAnalysis, 'none')
      if strcmp(obj.paradigmClass, 'STA')
        obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.MTFanalysis);
        f = obj.analysisFigure.getFigureHandle();
        set(f, 'Name', 'linear filter');
        obj.analysisFigure.userData.axesHandle = axes('Parent', f);
        % init the linear filter
        if ~isempty(strfind(obj.chromaticClass, 'RGB'))
          obj.linearFilter = zeros(3, floor(obj.frameRate));
        else
          obj.linearFilter = zeros(1, floor(obj.frameRate));
        end
        y = size(obj.linearFilter);
      elseif strcmp(obj.paradigmClass, 'ID')
        obj.xaxis = 1:obj.numberOfAverages;
        obj.F1 = zeros(1, obj.numberOfAverages);
        obj.F2 = zeros(1, obj.numberOfAverages);
        obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CRFanalysis);
        f = obj.analysisFigure.getFigureHandle();
        set(f, 'Name', 'Contrast Response Function');
        obj.analysisFigure.userData.axesHandle = axes('Parent', f);
      end
    end
  end

%% analysis figure functions
  function MTFanalysis(obj, ~, epoch) % for STA
    if obj.demoMode
      load demoResponse; % mat file saved in utils
      expTime = (obj.preTime + obj.stimTime + obj.tailTime) * 10;
      n = randi(length(response) - expTime, 1);
      responseTrace = response(n + 1 : n + expTime);
      sampleRate = 10000;
    else
      response = epoch.getResponse(obj.rig.getDevice(obj.amp));
      responseTrace = response.getData();
      sampleRate = response.sampleRate.quantityInBaseUnits;
    end
    
    % analyze response by type
    responseTrace = obj.getResponseByType(responseTrace, obj.onlineAnalysis);
    responseTrace = responseTrace(obj.preTime/1000*sampleRate+1:end);

    % bin data at 60 hz
    binWidth = sampleRate / obj.frameRate;
    numBins = floor(obj.stimTime/1000 * obj.frameRate);
    for k = 1:numBins
      index = round((k-1) * binWidth + 1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end

    % seed random number generator
    obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);

    % get the frame values
    if strcmp(obj.chromaticClass, 'RGB-gaussian')
      frameValues = obj.stdev * obj.noiseStream.randn(3, numBins);
    elseif strcmp(obj.chromaticClass, 'RGB-binary')
      frameValues = obj.noiseStream.randn(3, numBins) > 0.5;
    else
      frameValues = obj.stdev * obj.noiseStream.randn(1, numBins);
    end

    % get rid of the first 0.5 sec
    frameValues(:, 1:30) = 0;
    binData(:, 1:30) = 0;

    % run reverse correlation
    if isempty(strfind(obj.chromaticClass, 'RGB'))
      lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
      obj.linearFilter = obj.linearFilter + lf(1:floor(obj.frameRate));
    else
      lf = zeros(size(obj.linearFilter));
      y = size(lf);
      for ii = 1:3
        tmp = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([squeeze(frameValues(ii,:)), zeros(1,60)]))));
        x = size(tmp(1:floor(obj.frameRate)));
        lf(ii,:) = tmp(1:floor(obj.frameRate));
      end
      obj.linearFilter = obj.linearFilter + lf;
    end

    % plot to figure
    axesHandle = obj.analysisFigure.userData.axesHandle;
    cla(axesHandle);
    if isempty(strfind(obj.chromaticClass, 'RGB'))
      plot((0:length(obj.linearFilter)-1)/length(obj.linearFilter), obj.linearFilter, 'color', obj.plotColor, 'Parent', axesHandle);
    else
      plot((0:length(obj.linearFilter) - 1) / length(obj.linearFilter), obj.linearFilter, 'Parent', axesHandle);
    set(axesHandle, 'TickDir', 'out');
    end

    xlabel(axesHandle, 'msec');
    ylabel(axesHandle, 'filter units');
    title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', axesHandle);
  end

  function p = createPresentation(obj)

    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.lightMean);

    spot = stage.builtin.stimuli.Ellipse();
    spot.radiusX = obj.radius;
    spot.radiusY = obj.radius;
    spot.position = obj.canvasSize/2 + obj.centerOffset;

    % control when the spot is visible
    spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

    % Add the stimulus to the presentation.
    p.addStimulus(spot);
    p.addController(spotColorController);
    p.addController(spotVisibleController);

    function c = getSpotColor(obj, time)
      if time >= 0
        if strcmpi(obj.paradigmClass, 'ID')
          if strcmpi(obj.temporalClass, 'squarewave')
            c = obj.contrast * obj.ledWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.lightMean + obj.lightMean;
            c = c(:)';
          else
            c = obj.contrast * obj.ledWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.lightMean + obj.lightMean;
            c = c(:)';
          end
        elseif strcmpi(obj.paradigmClass, 'STA')
          if strcmp(obj.chromaticClass, 'RGB-binary')
            c = obj.contrast * obj.noiseStream.randn(1,3) > 0.5;
          elseif strcmp(obj.chromaticClass, 'RGB-gaussian')
            c = uint8((obj.stdev * obj.contrast * obj.noiseStream.rand(1,3) * 0.5 + 0.5) * 255);
          else
            c = obj.stdev * (obj.noiseStream.randn * obj.ledWeights) * obj.lightMean + obj.lightMean;
            c = c(:)';
          end
        end
      else
        c = obj.lightMean;
      end
    end
  end

  function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

    if strcmpi(obj.paradigmClass, 'STA')
      if obj.randomSeed
        obj.seed = RandStream.shuffleSeed;
      else
        obj.seed = 1;
      end
      obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);
      epoch.addParameter('seed', obj.seed);
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
