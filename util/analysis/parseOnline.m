function r = parseOnline(symphonyInput, recordingType, varargin)


  if strcmp(class(symphonyInput), 'symphonyui.core.persistent.EpochGroup') %#ok<STISA>
    error('Not ready yet, use old parse function');
  else
    epochBlock = symphonyInput; % for now
  end

  if nargin < 2
    recordingType = 'extracellular';
    fprintf('Recording type set to extracellular\n');
  elseif strcmp(recordingType, 'vc')
    recordingType = 'voltage_clamp';
  elseif strcmp(recordingType, 'ic')
    recordingType = 'current_clamp';
  elseif strcmp(recordingType, 'ec')
    recordingType = 'extracellular';
  end


  ip = inputParser();
  ip.addParameter('ampNum', 1, @(x)isvector(x));
  ip.addParameter('spikeDM', 'SpikeDetector', @(x)ischar(x));
  ip.addParameter('analysisType', [], @(x)ischar(x));
  ip.parse(varargin{:});
  ampNum = ip.Results.ampNum;
  spikeDM = ip.Results.spikeDM;
  analysisType = ip.Results.analysisType;

  % basic info
  r.numEpochs = length(epochBlock.getEpochs);
  r.cellName = epochBlock.epochGroup.source.label;
  r.protocol = epochBlock.protocolId; % get protocol name
  r.groupName = epochBlock.epochGroup.label;
  r.uuid = epochBlock.uuid;
  r.params.recordingType = recordingType;
  r.params.sampleRate = 10000;

  % init new monitoring params
  r.params.bathTemp = zeros(1, r.numEpochs);
  r.params.timingFlag = zeros(1, r.numEpochs);


  k = epochBlock.protocolParameters.keys;
  for ii = 1:length(k)
    r.params.(k{ii}) = epochBlock.protocolParameters(k{ii});
  end

  r.params.numberOfAverages = double(r.params.numberOfAverages);
  if r.numEpochs < r.params.numberOfAverages
    fprintf('number of epochs (%u) less than number of averages (%u)\n', r.numEpochs, r.params.numberOfAverages);
  end

  for ep = 1:r.numEpochs
    epoch = epochBlock.getEpochs{ep};
    resp = epoch.getResponses{ampNum}.getData;
    if ep == 1
      deviceNum = length(epoch.getResponses);
      r.resp = zeros(r.numEpochs, length(resp));
      % preallocate initial data analysis
      switch r.params.recordingType
        case 'voltage_clamp'
          r.analog = zeros(size(r.resp));
          if isKey(epoch.getStimuli{1}.parameters, 'offset')
            r.holding = epoch.getStimuli{1}.parameters('offset');
          else
            r.holding = epoch.getStimuli{1}.parameters('mean');
          end
          r.holdingUnit = epoch.getStimuli{1}.parameters('units');
          r.params.sampleRate = epoch.getStimuli{1}.parameters('sampleRate');
        case 'current_clamp'
          r.analog = zeros(r.numEpochs, length(r.resp));
          r.spikes = zeros(r.numEpochs, length(r.resp));
        case 'extracellular'
          r.spikes = zeros(size(r.resp));
          r.spikeData.resp = zeros(size(resp));
      end
      % set the analysis type
      if ~isempty(analysisType)
        r.params.analysisType = analysisType;
      else
        switch r.params.recordingType
        case 'extracellular'
          if length(epoch.getResponses) == 3
            r.params.analysisType = 'paired';
          else
            r.params.analysisType = 'single';
          end
        case 'voltage_clamp'
          if mean(resp) > 0
            r.params.analysisType = 'inhibition';
          else
            r.params.analysisType = 'excitation';
          end
        case 'current_clamp'
          r.params.analysisType = 'spikes&subthresh';
        end
      end

      % light stimuli stuff
      if isKey(epoch.protocolParameters, 'ndf')
        r.params.ndf = epoch.protocolParameters('ndf');
        r.params.objectiveMag = epoch.protocolParameters('objectiveMag');
        r.params.micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
        % compare these two:
        r.params.frameRate = epoch.protocolParameters('frameRate');
        if strcmp(epoch.getResponses{deviceNum}.device.name, 'Frame Monitor')
          r.stim.frameTimes = cell(r.numEpochs,1);
          r.stim.frameRate = zeros(r.numEpochs, 1);
          frameFlag = true;
          fprintf('found frame data\n');
        end
        % check on frame tracker
        % r.params.timingFlag = checkFrames(epoch);
      end
      r.ampNum = ampNum;
    end

    % get frame data TODO: don't include in fast version
    if frameFlag && strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.SpatialReceptiveField')
      % TODO: speed up
        [r.stim.frameTimes{ep,1}, r.stim.frameRate(ep)] = edu.washington.riekelab.sara.utils.getFrameTiming(epoch.getResponses{deviceNum}.getData);
    end

    % analyze by type
    switch r.params.recordingType
    case 'extracellular'
      [r.spikes(ep,:), r.spikeData.times{ep}, r.spikeData.amps{ep}] = getSpikes(resp, spikeDM, ep);
      r.spikeData.resp(ep, r.spikeData.times{ep}) = r.spikeData.amps{ep};
    case 'voltage_clamp'
      r.analog(ep,:) = getAnalog(resp, r.params.preTime, r.params.sampleRate);
    case 'current_clamp'
      [r.spikes(ep,:), r.spikeTimes{ep}, r.analog(ep,:)] = getSubthreshSpikes(resp, r.params.preTime, r.params.sampleRate);
    end

    % check on bath temp + flow
    r.params.bathTemp(1, ep) = epoch.protocolParameters('bathTemperature');

    % set some epoch info
    r.uuidEpoch{ep} = epoch.uuid;
    r.resp(ep,:) = resp;
    r.startTimes{ep} = datestr(epoch.startTime);
  end

  % deal with name changes
  switch r.protocol
    case 'edu.washington.riekelab.sara.protocols.TempSpatialNoise'
      r.protocol = 'edu.washington.riekelab.sara.protocols.SpatialReceptiveField';
    case 'edu.washington.riekelab.sara.protocols.IsoSTC'
      if strcmp(r.params.paradigmClass, 'STA')
        r.protocol = 'edu.washington.riekelab.sara.protocols.IsoSTA';
      end
  end

  % protocol specific data
  switch r.protocol %#ok<ALIGN>
    case 'edu.washington.riekelab.sara.protocols.FullChromaticGrating'
      r.params.spatialFrequencies = repmat(r.params.spatialFreqs, [1 length(r.params.orientations)]);
      r.params.spatialFrequencies = r.params.spatialFrequencies(1:r.numEpochs);

      r.params.apertureRadiusMicrons = r.params.apertureRadius * r.params.micronsPerPixel;

      r.params.SFs = unique(r.params.spatialFrequencies);
      if r.numEpochs < double(r.params.numberOfAverages)
        fprintf('under epoch flag - %u of %u\n', r.numEpochs, double(r.params.numberOfAverages));
        x = floor(r.numEpochs/length(r.params.SFs));
        r.params.orientations = r.params.orientations(1:x);
        if rem(r.numEpochs,length(r.params.SFs)) ~= 0
          r.respOver = r.resp(x*length(r.params.SFs)+1, :);
          r.resp(x*length(r.params.SFs)+1,:) = [];
        end
      end
      r.respBlock = reshape(r.resp, length(r.params.orientations), length(r.params.SFs), size(r.resp,2));
      % current clamp gets both
      if ~strcmp(r.params.recordingType, 'voltage_clamp')
        r.spikeBlock = reshape(r.spikes, length(r.params.orientations), length(r.params.SFs), size(r.spikes,2));
      end
      if ~strcmp(r.params.recordingType, 'extracellular')
        r.analogBlock = reshape(r.analog, length(r.params.orientations), length(r.params.SFs), size(r.analog,2));
      end

      for ii = 1:length(r.params.orientations)
        deg = sprintf('deg%u', r.params.orientations(ii));
        r.(deg).resp = r.resp(ii,:,:);
        if ~strcmp(r.params.recordingType, 'voltage_clamp')
          r.(deg).spikes = r.spikes(ii,:);
        end
        if ~strcmp(r.params.recordingType, 'extracellular')
          r.(deg).analog = r.analog(ii,:);
        end
      end

      case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
      r.params.minStep = 2^r.params.minStepBits / 256 * 2;
      r.params.maxStep = 2^r.params.maxStepBits / 256 * 2;
      r.params.searchValues = [(-1 : r.params.maxStep : 1), (-0.4375 : r.params.minStep : -0.2031), (0 : r.params.minStep : 0.125)];
      r.params.searchValues = unique(r.params.searchValues);
      r.params.plotColor = zeros(2,3);
      r.params.plotColor(1,:) = getPlotColor('l');
      r.params.plotColor(2,:) = getPlotColor('m');

    case 'edu.washington.riekelab.sara.protocols.CompareCones'
      r.params.coneWeights = zeros(r.numEpochs, 3);
      r.params.ledWeights = zeros(r.numEpochs, 3);
      for ep = 1:r.numEpochs
        epoch = epochBlock.getEpochs{ep};
        r.params.coneWeights(ep,:) = epoch.protocolParameters('coneWeights');
        r.params.ledWeights(ep,:) = epoch.protocolParameters('ledWeights');
      end
      if isempty(strfind('LMS', r.params.coneOne)) && isempty(strfind('LMS', r.params.coneTwo))
        r.params.stimSpace = 'led';
      else
        r.params.stimSpace = 'cone';
      end

    case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
      if r.numEpochs <= length(r.params.radii)
        r.params.radii = r.params.radii(1:r.numEpochs);
      else
        r.params.radii = [r.params.radii r.params.radii(1:r.numEpochs-length(r.params.radii))];
      end

    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;

      r.respBlock = zeros(length(r.params.stimClass), ceil(r.numEpochs/length(r.params.stimClass)), size(r.resp, 2));
      if strcmp(r.params.recordingType, 'extracellular')
        r.spikeBlock = zeros(size(r.respBlock));
      else
        r.analogBlock = zeros(size(r.respBlock));
      end

      for ep = 1:r.numEpochs
        [ind1, ind2] = ind2sub([length(r.params.stimClass), size(r.respBlock, 2)], ep);
        r.respBlock(ind1, ind2, :) = r.resp(ep,:);
        if strcmp(r.params.recordingType, 'extracellular')
          r.spikeBlock(ind1, ind2, :) = r.spikes(ep,:);
        else
          r.analogBlock(ind1, ind2, :) = r.analog(ep,:);
        end
      end

    case 'edu.washington.riekelab.protocols.PulseFamily'
      % init sorting variables
      r.params.pulses = zeros(1, r.params.pulsesInFamily);
      r.stim = zeros(r.params.pulsesInFamily, size(r.resp, 2));
      r.respBlock = zeros(r.params.pulsesInFamily, ceil(r.numEpochs/r.params.pulsesInFamily), size(r.resp,2));
      for ep = 1:r.numEpochs
        [ind1,ind2] = ind2sub([r.params.pulsesInFamily, size(r.respBlock,2)], ep);
        r.respBlock(ind1, ind2, :) = r.resp(ep, :);
        if ep <= r.params.pulsesInFamily
          r.stim(ep,:) = epochBlock.getEpochs{ep}.getStimuli{1}.getData; % get the stim
          r.params.pulses(1,ep) = r.params.incrementPerPulse * (double(ep) - 1) + r.params.firstPulseSignal;
        end
      end
      for ii = 1:length(r.params.pulses)
        r.meanResp = squeeze(mean(r.respBlock(ii,:,:), 2));
      end

    case {'edu.washington.riekelab.protocols.Pulse', 'edu.washington.riekelab.manookin.ResistanceAndCapacitance'}
      epoch = epochBlock.getEpochs{1};
      k = epoch.getStimuli{1}.parameters.keys;
      for ii = 1:length(k)
        r.stim.(k{ii}) = epoch.getStimuli{1}.parameters(k{ii});
      end
      r.stim.trace = r.stim.mean*ones(1, r.stim.preTime+r.stim.stimTime+r.stim.tailTime);
      r.stim.trace(1, r.stim.preTime+1:r.stim.preTime + r.stim.stimTime) = r.stim.amplitude + r.stim.trace(1, r.stim.preTime+1:r.stim.preTime+r.stim.stimTime);
      r.stim.trace = repelem(r.stim.trace, 10);

      if ~isempty(strfind(r.protocol, 'Resistance'))
        for ii = 1:r.numEpochs
          epoch = epochBlock.getEpochs{ii};
          if length(epoch.protocolParameters) > 5
            fprintf('found online analysis\n');
            r.analysis.oa.rInput = epoch.protocolParameters('rInput');
            r.analysis.oa.rSeries = epoch.protocolParameters('rSeries');
            r.analysis.oa.rMembrane = epoch.protocolParameters('rMembrane');
            r.analysis.oa.rTau = epoch.protocolParameters('rTau');
            r.analysis.oa.capacitance = epoch.protocolParameters('capacitance');
            r.analysis.oa.tau_msec = epoch.protocolParameters('tau_msec');
          end
        end
      end

    case {'edu.washington.riekelab.manookin.protocols.GaussianNoise', 'edu.washington.riekelab.sara.protocols.IsoSTA'}
      r.params.seed = zeros(1, r.numEpochs);
      for ep = 1:r.numEpochs
        epoch = epochBlock.getEpochs{ep};
        r.params.seed(1, ep) = epoch.protocolParameters('seed');
      end
      if ~isfield(r.params, 'frameDwell')
        r.params.frameDwell = 1;
      end

    case {'edu.washington.riekelab.sara.protocols.SpatialReceptiveField', 'edu.washington.riekelab.sara.protocols.TempSpatialNoise', 'edu.washington.riekelab.manookin.protocols.SpatialNoise', 'edu.washington.riekelab.manookin.protocols.TernaryNoise'}

      r.params.numFrames = floor(r.params.stimTime/1000 * r.params.frameRate / r.params.frameDwell);

      r.seed = zeros(r.numEpochs, 1);
      if r.params.useRandomSeed
        for ep = 1:r.numEpochs
          epoch = epochBlock.getEpochs{ep}; % get epoch
          % r.frame(ep,:) = epoch.getResponses{2}.getData; % get frames
          r.seed(ep) = epoch.protocolParameters('seed');
          if ep == 1
            r.params.numXChecks = epoch.protocolParameters('numXChecks');
            r.params.numYChecks = epoch.protocolParameters('numYChecks');
          end
        end
      else
        r.seed(:) = 1;
      end

    case 'edu.washington.riekelab.manookin.OrthographicAnnulus'
      r.params.intensity = zeros(1, r.numEpochs);
      r.params.direction = cell(1, r.numEpochs);

      for ep = 1:r.numEpochs
        epoch = epochBlock.getEpochs{ep};
        r.params.intensity(1, ep) = epoch.protocolParameters('intensity');
        r.params.direction{1, ep} = epoch.protocolParameters('direction');
      end
    end % switch

    % flag for serious bathTemp issues (indicative of flow issues usually)
    if ~isempty(find(r.params.bathTemp < 28)) %#ok<EFIND>
      fprintf('Low bath temp --> %.2f\n', min(r.params.bathTemp));
      r.bathTempFlag = 1;
    end

    % save date parsed
    r.log = cell(2,1);
    r.log{1} = ['recorded at ' r.startTimes{1}];
    r.log{2} = ['parsed at ' datestr(now)];


    %% ANALYSIS FUNCTIONS------------------------------------------
    function [spikes, spikeTimes, spikeAmps, refViols] = getSpikes(response, detectionMethod, epochNum)
      if nargin < 3
        epochNum = 1;
      end
      switch detectionMethod
        case 'SpikeDetector'
          [spikeTimes, spikeAmps, refViols] = SpikeDetector(response, 'epochNum',  epochNum);
        case 'check'
          [spikeTimes, spikeAmps, refViols] = SpikeDetector(response, 'checkDetection', true, 'epochNum', epochNum);
        case 'online'
          try
            response = wavefilter(response(:)', 6);
          catch
            fprintf('Running without wavefilter toolbox');
          end
          S = spikeDetectorOnline(response);
          spikeAmps = S.spikeAmps;
          spikeTimes = S.sp;
          refViols = [];
      end
      spikes = zeros(size(response));
      spikes(spikeTimes) = 1;
    end

    function analog = getAnalog(response, preTime, sampleRate)
      % analog = highPassFilter(response, 0.5, 1/sampleRate);
       analog = bandPassFilter(response, 0.2, 500, 1/sampleRate);
      % Subtract the median.
      if preTime > 0
        analog = analog - median(analog(1:round(sampleRate*preTime/1000)));
      else
        analog = analog - median(analog);
      end
    end

    function [spikes, spikeTimes, subthresh] = getSubthreshSpikes(response, preTime, sampleRate)
      spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
      spikes = zeros(size(response));
      spikes(spikeTimes) = 1;
      % Get the subthreshold potential.
      if ~isempty(spikeTimes)
        subthresh = getSubthreshold(response(:)', spikeTimes);
      else
        subthresh = response(:)';
      end
      % Subtract the median.
      if preTime > 0
        subthresh = subthresh - median(subthresh(1:round(sampleRate*preTime/1000)));
      else
        subthresh = subthresh - median(subthresh);
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
