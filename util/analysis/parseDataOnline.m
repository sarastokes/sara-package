function r = parseDataOnline(symphonyInput, ampNum, comp)
  % also for quick offline data
  % will soon switch over to better object system

  if nargin < 2
    ampNum = 1;
    comp = 'laptop';
  end
  if nargin < 3
    comp = 'laptop';
  end

  % only ChromaticSpot epochGroups for now
  if strcmp(class(symphonyInput), 'symphonyui.core.persistent.EpochGroup')
    epochGroup = symphonyInput;
    numBlocks = length(epochGroup.getEpochBlocks);
    for eb = 1:numBlocks
      epochBlock = epochGroup.getEpochBlocks{eb}; % get epoch block
      r.protocol = epochBlock.protocolId;
        if eb == 1
          r.data = struct();
        end
        r = parseSpotStimulus(r, epochBlock, eb);
        % monitor for flow interruption, serious bath temp issues
        if ~isempty(find(r.data(eb).params.bathTemp) < 28)
          fprintf('Block %u low bath temp --> %.2f\n', eb, min(r.data(eb).params.bathTemp));
          r.data(eb).bathTempFlag = 1;
        end
    end
  elseif strcmp(class(symphonyInput), 'symphonyui.core.persistent.EpochBlock')
    r = parseEpochBlock(symphonyInput);
  end

  function r = parseSpotStimulus(r, epochBlock, eb)
    r.numEpochs = length(epochBlock.getEpochs);
    epoch = epochBlock.getEpochs{1}; % to grab params stored in epochs
    micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
    % parameters to display
    r.data(eb).label = epochBlock.epochGroup.source.label(10:end);
    r.data(eb).chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.data(eb).contrast = epochBlock.protocolParameters('contrast');
    r.data(eb).ndf = epoch.protocolParameters('ndf');
    r.data(eb).bkg = epochBlock.protocolParameters('backgroundIntensity');
    r.data(eb).radius = epochBlock.protocolParameters('outerRadius');
    r.data(eb).ring = epochBlock.protocolParameters('innerRadius');
    r.data(eb).pre = epochBlock.protocolParameters('preTime');
    r.data(eb).stim = epochBlock.protocolParameters('stimTime');
    r.data(eb).tail = epochBlock.protocolParameters('tailTime');
    r.data(eb).avg = epochBlock.protocolParameters('numberOfAverages');
    r.data(eb).objMag = epoch.protocolParameters('objectiveMag');
    r.data(eb).start = datestr(epochBlock.startTime, 'hh:mm:ss');
    % to params structure
    r.data(eb).params.preTime = r.data(eb).pre;
    r.data(eb).params.stimTime = r.data(eb).stim;
    r.data(eb).params.tailTime = r.data(eb).tail;
    r.data(eb).params.contrast = r.data(eb).contrast;
    r.data(eb).params.chromaticClass = r.data(eb).chromaticClass;
    r.data(eb).params.outerRadius = r.data(eb).radius;
    r.data(eb).params.innerRadius = r.data(eb).ring;
    r.data(eb).params.radiusMicrons = ceil(r.data(eb).radius * micronsPerPixel);
    r.data(eb).params.objectiveMag = epoch.protocolParameters('objectiveMag');
    r.data(eb).params.micronsPerPixel = micronsPerPixel;
    r.data(eb).params.ndf = r.data(eb).ndf;
    r.data(eb).params.frameRate = epoch.protocolParameters('frameRate');
    r.data(eb).params.backgroundIntensity = r.data(eb).bkg;
    r.data(eb).params.numberOfAverages = r.data(eb).avg;
    r.data(eb).params.sampleRate = 10000;
    r.data(eb).params.onlineAnalysis =epochBlock.protocolParameters('onlineAnalysis');
    r.data(eb).params.uuid.epochGroup = epochBlock.epochGroup.uuid;
    r.data(eb).params.uuid.epochBlock = epochBlock.uuid;
    r.data(eb).params.protocol = epochBlock.protocolId;
    r.data(eb).params.ampNum = ampNum;
    r.data(eb).params.bathTemp = zeros(1, r.numEpochs);
    r.data(eb).params.timingFlag = zeros(1, r.numEpochs);
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep};
      r.data(eb).params.uuid.epochs{ep} = epoch.uuid;
      % check on bath temp + flow
      r.data(eb).params.bathTemp(1, ep) = epoch.protocolParameters('bathTemperature');
      % check on frame timing (work in progress)
      r.data(eb).timingFlag(1, r.numEpochs) = getFrames(epoch);
      % get response
      resp = epoch.getResponses{ampNum}.getData;
      if ep == 1
        r.data(eb).resp = zeros(r.numEpochs, length(resp));
      end
      r.data(eb).resp(ep,:) = resp;
     if strcmp(r.data(eb).params.onlineAnalysis, 'analog') || ~isempty(strfind('WC ', r.data(eb).label))
        if ep == 1
        analog = zeros(size(r.data(eb).resp));
        end
        analog(ep,:) = getAnalog(resp);
        if mean(r.data(eb).resp) > 0
          r.data(eb).recType = 'WC_inh';
        else
          r.data(eb).recType = 'WC_exc';
        end
      else % extracellular
        if ep == 1
          r.data(eb).spikes = zeros(size(r.data(eb).resp));
        end
        r.data(eb).recType = 'extracellular';
        [r.data(eb).spikes(ep,:), r.data(eb).spikeData.times{ep}, r.data(eb).spikeData.amps{ep}] = getSpikes(resp, comp);
        r.data(eb).spikeData.resp(ep, r.data(eb).spikeData.times{ep}) = r.data(eb).spikeData.amps{ep};
      end
    end
  end

  function r = parseEpochBlock(epochBlock)
  r.numEpochs = length(epochBlock.getEpochs);

  r.cellName = epochBlock.epochGroup.source.label;
  r.protocol = epochBlock.protocolId; % get protocol name
  r.groupName = epochBlock.epochGroup.label;
  r.uuid = epochBlock.uuid;
  r.params.preTime = epochBlock.protocolParameters('preTime');
  r.params.stimTime = epochBlock.protocolParameters('stimTime');
  r.params.tailTime = epochBlock.protocolParameters('tailTime');
  r.params.backgroundIntensity = epochBlock.protocolParameters('backgroundIntensity');
  r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
  r.params.sampleRate = 10000;
  r.params.onlineAnalysis =epochBlock.protocolParameters('onlineAnalysis');

  % init new monitoring params
  r.params.bathTemp = zeros(1, r.numEpochs);
  r.params.timingFlag = zeros(1, r.numEpochs);


  % data from all protocols and epoch parameters
  for ep = 1:r.numEpochs
    epoch = epochBlock.getEpochs{ep}; % get epoch
    resp = epoch.getResponses{ampNum}.getData; % get response
    if ep == 1
      r.resp = zeros(r.numEpochs, length(resp));
      if strcmp(r.params.onlineAnalysis, 'analog') || ~isempty(strfind('WC ', r.groupName))
        r.analog = zeros(size(r.resp));
      else
        r.spikes = zeros(size(r.resp));
        r.spikeData.resp = zeros(size(resp));
      end
      r.params.ndf = epoch.protocolParameters('ndf');
      r.params.objectiveMag = epoch.protocolParameters('objectiveMag');
      r.params.micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
      r.params.frameRate = epoch.protocolParameters('frameRate');
    end
    % check on bath temp + flow
    r.params.bathTemp(1, ep) = epoch.protocolParameters('bathTemperature');
    % check on frame tracker
    r.params.timingFlag = checkFrames(epoch);

    r.uuidEpoch{ep} = epoch.uuid;
    r.resp(ep,:) = resp;
    if strcmp(r.params.onlineAnalysis, 'analog') || ~isempty(strfind('WC ', r.groupName))
      r.analog(ep,:) = getAnalog(resp, r.params.preTime, r.params.sampleRate);      
    else
      [r.spikes(ep,:), r.spikeData.times{ep}, r.spikeData.amps{ep}] = getSpikes(resp, comp);
      r.spikeData.resp(ep, r.spikeData.times{ep}) = r.spikeData.amps{ep};
    end
    r.startTimes{ep} = datestr(epoch.startTime);
  end

  %% protocol specific data - could be condensed but keeping separate for now.
  switch r.protocol
  case {'edu.washington.riekelab.manookin.protocols.ChromaticGrating', 'edu.washington.riekelab.sara.protocols.TempChromaticGrating'}
    epoch = epochBlock.getEpochs{1};
    r.params.waitTime = epochBlock.protocolParameters('waitTime');
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.spatialClass = epochBlock.protocolParameters('spatialClass');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.orientation = epochBlock.protocolParameters('orientation');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.spatialFrequencies = epochBlock.protocolParameters('spatialFreqs');
    r.params.spatialPhase = epochBlock.protocolParameters('spatialPhase');
    r.params.randomOrder = epochBlock.protocolParameters('randomOrder');
    if isKey(epoch.protocolParameters,'sContrast')
      r.params.sContrast = epoch.protocolParameters('sContrast');
      r.params.rodContrast = epoch.protocolParameters('rodContrast');
    end
    r.params.apertureClass = epochBlock.protocolParameters('apertureClass');
    r.params.apertureRadius = epochBlock.protocolParameters('apertureRadius');
    r.params.apertureRadiusMicrons = r.params.apertureRadius * r.params.micronsPerPixel;
    r.params.plotColor = getPlotColor(r.params.chromaticClass);
    r.params.stimStart = (r.params.preTime + r.params.waitTime) * 10 + 1;
    r.params.stimEnd = (r.params.preTime + r.params.stimTime) * 10;

  case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
    r.params.stimulusClass = epochBlock.protocolParameters('stimulusClass');
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.radii = epochBlock.protocolParameters('radii');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    [r.params.plotColor,~] = getPlotColor(r.params.chromaticClass);

  case 'edu.washington.riekelab.sara.protocols.ConeSweep'
    r.params.stimClass = epochBlock.protocolParameters('stimClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    if isKey(epochBlock.protocolParameters, 'reverseOrder)')
      r.params.reverseOrder = epochBlock.protocolParameters('reverseOrder');
    end
    if isKey(epochBlock.protocolParameters, 'equalQuantalCatch')
      r.params.equalQuantalCatch = epochBlock.protocolParameters('equalQuantalCatch');
    else
      r.params.equalQuantalCatch = 0;
    end
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep}; % get epoch
      if ep <= length(r.params.stimClass) && isKey(epoch.protocolParameters, 'sweepColor')
          r.params.plotColors(ep,:) = epoch.protocolParameters('sweepColor');
      end
      r.trials(ep).chromaticClass = epoch.protocolParameters('chromaticClass');
    end

  case 'edu.washington.riekelab.sara.protocols.IsoSTC'
    r.params.paradigmClass = epochBlock.protocolParameters('paradigmClass');
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    if strcmp(r.params.paradigmClass,'ID')
      r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
      r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    elseif strcmp(r.params.paradigmClass, 'STA')
      r.params.randomSeed = epochBlock.protocolParameters('randomSeed');
      r.params.stdev = epochBlock.protocolParameters('stdev');
    end
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    [r.params.plotColor, ~] = getPlotColor(r.params.chromaticClass);
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep}; % get epoch
      if strcmp(r.params.paradigmClass, 'STA')
        r.params.seed{ep} = epoch.protocolParameters('seed');
      end
    end

  case 'edu.washington.riekelab.manookin.protocols.GaussianNoise'
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.stimulusClass = epochBlock.protocolParameters('stimulusClass');
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    r.params.stdev = epochBlock.protocolParameters('stdev');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    r.params.randomSeed = epochBlock.protocolParameters('randomSeed');

    % init analysis variables
    [r.params.plotColor, ~] = getPlotColor(r.params.chromaticClass);
    r.params.seed = zeros(1, r.numEpochs);

    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep};
      r.params.seed(1, ep) = epoch.protocolParameters('seed');
    end

  case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.stimulusClass = epochBlock.protocolParameters('stimulusClass');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.contrasts = epochBlock.protocolParameters('contrasts');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    [r.params.plotColor, ~] = getPlotColor(r.params.chromaticClass);

  case 'edu.washington.riekelab.manookin.protocols.BarCentering'
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.searchAxis = epochBlock.protocolParameters('searchAxis');
    r.params.barSize = epochBlock.protocolParameters('barSize');
    r.params.barSizeMicrons = r.params.barSize * r.params.micronsPerPixel;
    r.params.intensity = epochBlock.protocolParameters('intensity');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.positions = epochBlock.protocolParameters('positions');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');

  case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
%    r.params.temporalClass = epochBlock.temporalClass('temporalClass');
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    r.params.maxStepBits = epochBlock.protocolParameters('maxStepBits');
    r.params.minStepBits = epochBlock.protocolParameters('minStepBits');
    r.params.minStep = 2^r.params.minStepBits / 256 * 2;
    r.params.maxStep = 2^r.params.maxStepBits / 256 * 2;
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    r.params.searchValues = [(-1 : r.params.maxStep : 1), (-0.4375 : r.params.minStep : -0.2031), (0 : r.params.minStep : 0.125)];
    r.params.searchValues = unique(r.params.searchValues);
    r.params.plotColor = zeros(2,3);
    r.params.plotColor(1,:) = getPlotColor('l');
    r.params.plotColor(2,:) = getPlotColor('m');

  case 'edu.washington.riekelab.sara.protocols.ChromaticSpatialNoise'
    r.params.noiseClass =  epochBlock.protocolParameters('noiseClass');
    r.params.stixelSize = epochBlock.protocolParameters('stixelSize');
    r.params.stixelSizeMicrons = r.params.stixelSize * r.params.micronsPerPixel;
    r.params.frameDwell = epochBlock.protocolParameters('frameDwell');
    r.params.intensity = epochBlock.protocolParameters('intensity');
    r.params.maskRadius = epochBlock.protocolParameters('maskRadius');
    r.params.maskRadiusMicrons = r.params.maskRadius * r.params.micronsPerPixel;
    r.params.numXChecks = epoch.protocolParameters('numXChecks');
    r.params.numYChecks = epoch.protocolParameters('numYChecks');
    r.params.useRandomSeed = epochBlock.protocolParameters('useRandomSeed');
    r.params.runFullProtocol = epochBlock.protocolParameters('runFullProtocol');
    r.params.equalQuantalCatch = epochBlock.protocolParameters('equalQuantalCatch');

    if r.params.runFullProtocol
      cones = {'liso' 'miso' 'siso'};
      indCount = 1; % where to store within each cone iso struct
      for ii = 1:3
        stim = cones{ii};
        r.(stim).params = r.params;
        r.(stim).params.chromaticClass = char(stim);
        r.(stim).protocol = r.protocol;
        r.(stim).cellName = r.cellName;
      end
    end

    if ~r.params.useRandomSeed
      r.seed = 1;
    else
      for ii = 1:r.numEpochs
        r.seed(ii) = epoch.protocolParameters('seed');
      end
    end
    epochCounter = 0;

    for ep = 1:3:r.numEpochs
      epochCounter = epochCounter + 1;
      fprintf('ep%u\n', ep);
      r.liso.resp(epochCounter, :) = r.resp(ep, :);
      r.liso.spikes(epochCounter, :) = r.spikes(ep, :);
      r.liso.spikeData.resp(epochCounter, :) = r.spikeData.resp(ep,:);
      r.liso.spikeData.times{epochCounter} = r.spikeData.times{ep};
      r.liso.spikeData.amps{epochCounter} = r.spikeData.times{ep};
      r.liso.seed(epochCounter) = r.seed(ep);
      if ep + 1 <= r.numEpochs
        r.miso.resp(epochCounter, :) = r.resp(ep+1, :);
        r.miso.spikes(epochCounter, :) = r.spikes(ep+1, :);
        r.miso.spikeData.resp(epochCounter, :) = r.spikeData.resp(ep+1, :);
        r.miso.spikeData.times{epochCounter} = r.spikeData.times{ep+1};
        r.miso.spikeData.amps{epochCounter} = r.spikeData.amps{ep+1};
        r.miso.seed(epochCounter) = r.seed(ep + 1);
      end
      if ep+2 <= r.numEpochs
        r.siso.resp(epochCounter, :) = r.resp(ep+2, :);
        r.siso.spikes(epochCounter, :) = r.spikes(ep+2, :);
        r.siso.spikeData.resp(epochCounter, :) = r.spikeData.resp(ep+2,:);
        r.siso.spikeData.times{epochCounter} = r.spikeData.times{ep+2};
        r.siso.spikeData.amps{epochCounter} = r.spikeData.amps{ep+2};
        r.siso.seed(epochCounter) = r.seed(epochCounter + 2);
      end
    end

  case 'edu.washington.riekelab.manookin.protocols.SpatialNoise'
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.noiseClass =  epochBlock.protocolParameters('noiseClass');
    r.params.chromaticClass =  epochBlock.protocolParameters('chromaticClass');
    r.params.stixelSize = epochBlock.protocolParameters('stixelSize');
    r.params.stixelSizeMicrons = r.params.stixelSize * r.params.micronsPerPixel;
    r.params.frameDwell = epochBlock.protocolParameters('frameDwell');
    r.params.intensity = epochBlock.protocolParameters('intensity');
    r.params.maskRadius = epochBlock.protocolParameters('maskRadius');
    r.params.maskRadiusMicrons = r.params.maskRadius * r.params.micronsPerPixel;
    if isKey(epoch.protocolParameters, 'apertureRadius')
      r.params.apertureRadius = epochBlock.protocolParameters('apertureRadius');
      r.params.apertureRadiusMicrons = r.params.apertureRadius * r.params.micronsPerPixel;
    end
    r.params.numXChecks = epoch.protocolParameters('numXChecks');
    r.params.numYChecks = epoch.protocolParameters('numYChecks');
    r.params.useRandomSeed = epochBlock.protocolParameters('useRandomSeed');
    r.params.numFrames = floor(r.params.stimTime/1000 * r.params.frameRate / r.params.frameDwell);

    r.seed = zeros(r.numEpochs, 1);
    if r.params.useRandomSeed
      for ep = 1:r.numEpochs
        epoch = epochBlock.getEpochs{ep}; % get epoch
        % r.frame(ep,:) = epoch.getResponses{2}.getData; % get frames
        r.seed(ep) = epoch.protocolParameters('seed');
      end
    else
      r.seed(:) = 1;
    end

  case 'edu.washington.riekelab.manookin.protocols.TernaryNoise'
    r.params.stixelSize = epochBlock.protocolParameters('stixelSize');
    r.params.noiseClass = epochBlock.protocolParameters('noiseClass');
    r.params.outerRadius = epochBlock.protocolParameters('outerRadius');
    r.params.orientation = epochBlock.protocolParameters('orientation');
    r.params.corr = epochBlock.protocolParameters('corr');
    r.params.dimensionality = epochBlock.protocolParameters('dimensionality');
    r.params.innerRadius = epochBlock.protocolParameters('innerRadius');
    r.params.waitTime = epochBlock.protocolParameters('waitTime');
    r.params.randomSeed = epochBlock.protocolParameters('randomSeed');
    r.params.numFrames = floor(r.params.stimTime/1000 * r.params.frameRate / r.params.frameDwell);

    r.seed = zeros(r.numEpochs, 1);
    if r.params.useRandomSeed
      for ep = 1:r.numEpochs
        epoch = epochBlock.getEpochs{ep};
        % r.frame(ep,:) = epoch.getResponses{2}.getData; % get frames
        r.seed(ep) = epoch.protocolParameters('seed');
      end
    else
      r.seed(:) = 1;
    end
  end

  if isfield(r.params, 'chromaticClass')
    r.params.plotColor = getPlotColor(r.params.chromaticClass);
  end

  % flag for serious bathTemp issues (usually bc out of ames)
  if ~isempty(find(r.params.bathTemp) < 28)
    fprintf('Low bath temp --> %.2f\n', min(r.params.bathTemp));
    r.bathTempFlag = 1;
  end

end


%% ANALYSIS FUNCTIONS------------------------------------------
  function [spikes, spikeTimes, spikeAmps] = getSpikes(response, comp)
    if ~strcmp(comp, 'slu')
      response = wavefilter(response(:)', 6);
    end
      S = spikeDetectorOnline(response);
      spikes = zeros(size(response));
      spikes(S.sp) = 1;
      spikeAmps = S.spikeAmps;
      spikeTimes = S.sp;
  end

  function analog = getAnalog(response, preTime, sampleRate)
      % Deal with band-pass filtering analog data here.
      analog = bandPassFilter(response, 0.2, 500, 1/sampleRate);
      % Subtract the median.
      if preTime > 0
        analog = analog - median(analog(1:round(sampleRate*preTime/1000)));
      else
        analog = analog - median(analog);
      end
  end

  function timingFlag = checkFrames(epoch)  
    deviceNum = length(epoch.getResponses);
    if strcmp(epoch.getResponses{deviceNum}.device.name, 'Frame Monitor')
      frames = epoch.getResponses{deviceNum}.getData;
      xpts = length(frames);
      if isempty(find(frames(1:10000) < 0.25*(max(frames)))) %#ok<EFIND>
        fprintf('Warning: stimuli triggered late\n');
        timingFlag = 1;
      elseif isempty(find(frames(xpts-10000:xpts) > 0.25*(max(frames)))) %#ok<EFIND>
        fprintf('Warning: stimulus triggered early\n');
        timingFlag = 2;
      else
        timingFlag = 0;
      end
    else
      fprintf('Frame monitor not found\n');
    end
  end

end % overall function
