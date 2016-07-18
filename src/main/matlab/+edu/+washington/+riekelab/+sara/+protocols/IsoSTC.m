classdef IsoSTC < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
    % ID and get temporal RF

properties
  amp                                     % amplifier
  preTime = 500                           % before stim (ms)
  stimTime = 2000                         % stim duration (ms)
  tailTime = 500                          % after stim (ms)
  contrast = 1                            % contrast (0 - 1)
  temporalFrequency = 2                   % modulation frequency
  radius = 150                            % spot size (pixels)
  backgroundIntensity = 0.5               % mean (0 - 1)
  centerOffset = [0,0]                    % spot center (pixels x,y)
  paradigmClass = 'ID';                   % ID=sin/sqr, STA=gaussian noise
  temporalClass = 'sinewave'              % if ID, sine or sqrwave
  chromaticClass = 'achromatic'           % spot color!
  onlineAnalysis = 'none'                 % type of online analysis
  randomSeed = true                       % if STA, use random seed
  stdev = 0.3;                            % if STA, gaussian noise sd
  numberOfAverages = uint16(1)            % number of epochs
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

properties (Hidden) % for online analysis
  xaxis
  F1Amp
  repsPerX
  linearFilter
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
    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

    % why is this here?
    if obj.backgroundIntensity == 0
        obj.bkg = 0.5;
    else
        obj.bkg = obj.backgroundIntensity;
    end

    if ~strcmp(obj.onlineAnalysis, 'none')
      % get plot color
      if strcmp(obj.chromaticClass, 'S-iso')
        obj.plotColor = [0.14118, 0.20784, 0.84314];
      elseif strcmp(obj.chromaticClass, 'M-iso')
        obj.plotColor = [0, 0.72941, 0.29804];
      elseif strcmp(obj.chromaticClass, 'L-iso')
        obj.plotColor = [0.82353, 0, 0];
      else
        obj.plotColor = [0 0 0];
      end
      if strcmp(obj.paradigmClass, 'STA')
        obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.MTFanalysis);
        f = obj.analysisFigure.getFigureHandle();
        set(f, 'Name', 'linear filter');
        obj.analysisFigure.userData.axesHandle = axes('Parent', f);
        % init the linear filter
        obj.linearFilter = zeros(1, floor(obj.frameRate));
      elseif strcmp(obj.paradigmClass, 'ID')
        obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CRFanalysis);
        f = obj.analysisFigure.getFigureHandle();
        set(f, 'Name', 'Contrast Response Function');
        obj.analysisFigure.userData.axesHandle = axes('Parent', f);
      end
    end

    obj.setColorWeights();
  end

%% analysis figure functions
  function MTFanalysis(obj, ~, epoch) % for STA
    response = epoch.getResponse(obj.rig.getDevice(obj.amp));
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    % analyze response by type
    responseTrace = obj.getResponseByType(responseTrace, obj.onlineAnalysis);

    % get f1 amplitude and phase
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
    frameValues = obj.stdev * obj.noiseStream.randn(1, numBins);

    % get rid of the first 0.5 sec
    frameValues(1:30) = 0;
    binData(1:30) = 0;

    % run reverse correlation
    lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
    obj.linearFilter = obj.linearFilter + lf(1:floor(obj.frameRate));

    % plot to figure
    axesHandle = obj.analysisFigure.userData.axesHandle;
    cla(axesHandle);
    plot((0:length(obj.linearFilter)-1)/length(obj.linearFilter), obj.linearFilter, 'color', sc, 'Parent', axesHandle);
    set(axesHandle, 'TickDir', 'out');
    xlabel(axesHandle, 'msec');
    ylabel(axesHandle, 'filter units');
    title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', axesHandle);
  end

  function CRFanalysis(obj, ~, epoch)
    response = epoch.getResponse.(obj.rig.getDevice(obj.amp));
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    % get the f1 amplitude and phase
    responseTrace = responseTrace(obj.preTime/1000*sampleRate+1:end);
    binRate = 60;
    binWidth = sampleRate / binRate;
    numBins = floor(obj.stimTime/1000 * binRate);
    binData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1)*binWidth+1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end
    binsPerCycle = binRate / obj.temporalFrequency;
    numCycles = floor(length(binData)/binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));
    for k = 1:numCycles
      index = round((k-1)*binsPerCycle) + (1:floor(binsPerCycle));
      cycleData = cycleData + binData(index);
    end
    cycleData = cycleData / k;

    ft = fft(cycleData);

    index = find(obj.xaxis == obj.contrast, 1);
    r = obj.F1Amp(index) * obj.repsPerX(index);
    r = r + abs(ft(2))/length(ft)*2;

    % increment the count
    obj.repsPerX(index) = obj.repsPerX(index) + 1;
    obj.F1Amp(index) = r / obj.repsPerX(index);

    % plot to figure
    axesHandle = obj.analysisFigure.userData.axesHandle;
    cla(axesHandle);
    h1 = axesHandle;
    plot(obj.xaxis, obj.F1Amp, 'o-', 'color', sc, 'Parent', h1);
    set(h1, 'TickDir', 'out');
    ylabel(h1, 'F1 amp');
    title(['Epoch ', num2str(obj.numEpochsCompleted) , ' of ', num2str(obj.numberOfAverages)], 'Parent', h1);
  end

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

%    device = obj.rig.getDevice(obj.amp);
%    duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
%    epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
%    epoch.addResponse(device);

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
