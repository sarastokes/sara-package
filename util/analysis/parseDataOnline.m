function r = parseDataOnline(symphonyInput)
  % also for quick offline data
  % will soon switch over to better object system

  % only ChromaticSpot epochGroups for now
  if strcmp(class(symphonyInput), 'symphonyui.core.persistent.EpochGroup')
    epochGroup = symphonyInput;
    numBlocks = length(epochGroup.getEpochBlocks);
    for eb = 1:numBlocks
      epochBlock = epochGroup.getEpochBlocks{eb}; % get epoch block
      r.protocol = epochBlock.protocolId;
        if eb == 1
          % must be some way around this
          r.data = struct();
            % r.data(1).label = 'foo'; r.data(2).label = 'foo'; r.data(1).chromaticClass = 'foo';
        end
        r = parseSpotStimulus(r, epochBlock, eb);
    end
  elseif strcmp(class(symphonyInput), 'symphonyui.core.persistent.EpochBlock')
    r = parseEpochBlock(symphonyInput);
  end

  function r = parseSpotStimulus(r, epochBlock, eb)
    r.numEpochs = length(epochBlock.getEpochs);
    epoch = epochBlock.getEpochs{1}; % to grab params stored in epochs
    micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
    % parameters to display
   % r.data(eb).label = epochBlock.epochs.source.label(10:end);
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
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep};
      r.data(eb).params.uuid.epochs{ep} = epoch.uuid;
      resp = epoch.getResponses{1}.getData; % get response
      if ep == 1
        r.data(eb).resp = zeros(r.numEpochs, length(resp));
        spikes = zeros(size(r.data(eb).resp));
      end
      r.data(eb).resp(ep,:) = resp;
      [spikes(ep,:), spikeData.times{ep}, spikeData.amps{ep}] = getSpikes(resp);
      spikeData.resp(ep, spikeData.times{ep}) = spikeData.amps{ep};
    end
    r.data(eb).spikes = spikes;
    r.data(eb).spikeData = spikeData;
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

  % data from all protocols and epoch parameters
  for ep = 1:r.numEpochs
    epoch = epochBlock.getEpochs{ep}; % get epoch
    resp = epoch.getResponses{1}.getData; % get response
    if ep == 1
      r.resp = zeros(r.numEpochs, length(resp));
      r.spikes = zeros(size(r.resp));
      r.spikeData.resp = zeros(size(resp));
      r.params.ndf = epoch.protocolParameters('ndf');
      r.params.objectiveMag = epoch.protocolParameters('objectiveMag');
      r.params.micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
      r.params.frameRate = epoch.protocolParameters('frameRate');
    end
    r.uuidEpoch{ep} = epoch.uuid;
    r.resp(ep,:) = resp;
    [r.spikes(ep,:), r.spikeData.times{ep}, r.spikeData.amps{ep}] = getSpikes(resp);
    r.spikeData.resp(ep, r.spikeData.times{ep}) = r.spikeData.amps{ep};
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
    r.params.sContrast = epoch.protocolParameters('sContrast');
    r.params.rodContrast = epoch.protocolParameters('rodContrast');
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
    r.params.reverseOrder = epochBlock.protocolParameters('reverseOrder');
    r.params.equalQuantalCatch = epochBlock.protocolParameters('equalQuantalCatch');
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep}; % get epoch
      if ep <= length(r.params.stimClass)
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
    r.params.searchAxis = epochBlock.protocolParameters('searchAxis');
    r.params.barSize = epochBlock.protocolParameters('barSize');
    r.params.barSizeMicrons = r.params.barSize * r.params.micronsPerPixel;
    r.params.intensity = epochBlock.protocolParameters('intensity');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.positions = epochBlock.protocolParameters('positions');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');

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
    
    % for ep = 1:r.numEpochs
    %   index = rem(ep-1, 3) + 1;
    %   stim = cones{index};
    %   epoch = epochBlock.getEpochs{ep};
    %   r.(stim).resp(indCount,:) = r.resp(ep,:);
    %   r.(stim).spikes(indCount,:) = r.spikes(ep,:)
    %   r.(stim).spikeData.resp(indCount, :) = r.spikeData.resp(ep,:);
    %   r.(stim).spikeData.times{indCount} = r.spikeData.times{ep};
    %   r.(stim).spikeData.amps{indCount} = r.spikeData.amps{ep};
    %   % r.(stim).frame(indCount,:) = epoch.getResponses{2}.getData; % get frame
    %   r.(stim).seed(indCount) = epoch.protocolParameters('seed');
    %   if index == 3
    %     indCount = indCount + 1;
    %   end
    % end
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
    r.params.numXChecks = epoch.protocolParameters('numXChecks');
    r.params.numYChecks = epoch.protocolParameters('numYChecks');
    r.params.useRandomSeed = epochBlock.protocolParameters('useRandomSeed');

    if r.params.useRandomSeed
      r.seed = zeros(r.numEpochs, 1);
    else
      r.seed = 1;
    end
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep}; % get epoch
      % r.frame(ep,:) = epoch.getResponses{2}.getData; % get frames
      r.seed(ep) = epoch.protocolParameters('seed');
    end
  end
end 


%% ANALYSIS FUNCTIONS------------------------------------------
  function [spikes, spikeTimes, spikeAmps] = getSpikes(response)
      response = wavefilter(response(:)', 6);
      S = spikeDetectorOnline(response);
      spikes = zeros(size(response));
      spikes(S.sp) = 1;
      spikeAmps = S.spikeAmps;
      spikeTimes = S.sp;
  end
end % overall function
