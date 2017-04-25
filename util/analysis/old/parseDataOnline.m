function r = parseDataOnline(symphonyInput, recordingType, varargin)
  % INPUTS:
  %     symphonyInput: epochBlock (or epochGroup for ChromaticSpot)
  %     recordingType: in case it isn't defined thru onlineAnalysis or epochGroup name.
  %                   options are 'extracellular', 'voltage_clamp', 'current_clamp'
  %     ampNum: which amplifier to analyze. for paired recordings
  %     spikeDM: detection method for spikes, default = SpikeDetector, 'check', 'online'
  %     analysisType: program should pick up on this unless it's a dual recording
  %         options for extracellular are 'single', 'paired' and 'dual'
  %         for voltage_clamp: 'excitation', 'inhibition'
  %         for current_clamp: 'spikes&subthresh' (in future: 'spikes', 'subthresh')
  %         TODO: paired w/ one dual amp, make sure inh, exc detection is legit
  %
  %
  %
  % also for quick offline data
  % will soon(ish) switch over to better object system

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
%%
  function r = parseSpotStimulus(r, epochBlock, eb)
    r.numEpochs = length(epochBlock.getEpochs);
    epoch = epochBlock.getEpochs{1}; % to grab params stored in epochs
    micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
    % parameters to display
    r.data(eb).label = epochBlock.epochGroup.source.label;
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
      r.data(eb).timingFlag(1, r.numEpochs) = checkFrames(epoch);
      % get response
      resp = epoch.getResponses{ampNum}.getData;
      if ep == 1
        r.data(eb).resp = zeros(r.numEpochs, length(resp));
      end
      r.data(eb).resp(ep,:) = resp;
      if ep == 1
        r.data(eb).recordingType = recordingType;
        % set analysisType
        if ~isempty(analysisType)
          r.data(eb).analysisType = analysisType;
        else
          switch r.data(eb).recordingType
          case 'extracellular'
            if length(epoch.getResponses) == 3
              r.data(eb).analysisType = sprintf('paired_amp%u', ampNum);
            else
              r.data(eb).analysisType = 'single';
            end
          case 'voltage_clamp'
            if mean(r.data(eb).resp) > 0
              r.data(eb).analysisType = 'inhibition';
            else
              r.data(eb).analysisType = 'excitation';
            end
          case 'current_clamp'
            r.data(eb).analysisType = 'spikes&subthresh';
          end
        end
      end
      % initial analysis
      switch r.data(eb).recordingType
      case 'extracellular'
        if ep == 1
          r.data(eb).spikes = zeros(size(r.data(eb).resp));
        end
        [r.data(eb).spikes(ep,:), r.data(eb).spikeData.times{ep}, r.data(eb).spikeData.amps{ep}] = getSpikes(resp, spikeDM);
        r.data(eb).spikeData.resp(ep, r.data(eb).spikeData.times{ep}) = r.data(eb).spikeData.amps{ep};
      case 'voltage_clamp'
        if ep == 1
          r.data(eb).analog = zeros(size(r.data(eb).resp));
        end
        if isKey(epoch.getStimuli{1}.parameters, 'offset')
          r.data(eb).params.holding = epoch.getStimuli{1}.parameters('offset');
        else
          r.data(eb).params.holding = epoch.getStimuli{1}.parameters('mean');
        end
        r.data(eb).params.holdingUnit = epoch.getStimuli{1}.parameters('units');
        tmp = getAnalog(resp, r.data(eb).params.preTime, r.data(eb).params.sampleRate);
        if isempty(nnz(tmp))
          fprintf('block %u epoch %u - empty analog', eb,ep);
        end
        r.data(eb).analog(ep,:) = tmp;
      end
    end
  end
%%
  function r = parseEpochBlock(epochBlock)
  r.numEpochs = length(epochBlock.getEpochs);
  r.cellName = epochBlock.epochGroup.source.label;
  r.protocol = epochBlock.protocolId; % get protocol name
  r.groupName = epochBlock.epochGroup.label;
  r.uuid = epochBlock.uuid;
  r.params.recordingType = recordingType;
  r.params.preTime = epochBlock.protocolParameters('preTime');
  r.params.stimTime = epochBlock.protocolParameters('stimTime');
  r.params.tailTime = epochBlock.protocolParameters('tailTime');
  if isKey(epochBlock.protocolParameters, 'backgroundIntensity')
    r.params.backgroundIntensity = epochBlock.protocolParameters('backgroundIntensity');
    r.params.onlineAnalysis =epochBlock.protocolParameters('onlineAnalysis');
  end
  r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
  r.params.sampleRate = 10000; % fix at some point

  % init new monitoring params
  r.params.bathTemp = zeros(1, r.numEpochs);
  r.params.timingFlag = zeros(1, r.numEpochs);

  % data from all protocols and epoch parameters
  for ep = 1:r.numEpochs
    epoch = epochBlock.getEpochs{ep}; % get epoch
    resp = epoch.getResponses{ampNum}.getData; % get response
    if ep == 1
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
            r.subthresh = zeros(r.numEpochs, length(r.resp));
            r.ICspikes = zeros(r.numEpochs, length(r.resp));
          case 'extracellular'
            r.spikes = zeros(size(r.resp));
            r.spikeData.resp = zeros(size(resp));
      end
      % set the analysis type & do initial analysis
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
      if isKey(epoch.protocolParameters, 'ndf')
        r.params.ndf = epoch.protocolParameters('ndf');
        r.params.objectiveMag = epoch.protocolParameters('objectiveMag');
        r.params.micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
        r.params.frameRate = epoch.protocolParameters('frameRate');
        % check on frame tracker
        r.params.timingFlag = checkFrames(epoch);
      end
      r.ampNum = ampNum;
      end
        switch r.params.recordingType
        case 'extracellular'
          [r.spikes(ep,:), r.spikeData.times{ep}, r.spikeData.amps{ep}] = getSpikes(resp, spikeDM);
          r.spikeData.resp(ep, r.spikeData.times{ep}) = r.spikeData.amps{ep};
        case 'voltage_clamp'
          r.analog(ep,:) = getAnalog(resp, r.params.preTime, r.params.sampleRate);
        case 'current_clamp'
          [r.ICspikes(ep,:), r.ICstikeTimes{ep}, r.subthresh(ep,:)] = getSubthreshSpikes(resp, r.params.preTime, r.params.sampleRate);
        end
      r.ampNum = ampNum;
    % check on bath temp + flow
    r.params.bathTemp(1, ep) = epoch.protocolParameters('bathTemperature');

    r.uuidEpoch{ep} = epoch.uuid;
    r.resp(ep,:) = resp;
    r.startTimes{ep} = datestr(epoch.startTime);
  end

  %% protocol specific data - could be condensed but keeping separate for now.
  switch r.protocol
  case {'edu.washington.riekelab.sara.protocols.FullChromaticGrating',...
    'edu.washington.riekelab.manookin.protocols.ChromaticGrating',...
    'edu.washington.riekelab.sara.protocols.TempChromaticGrating'}
    if ~isempty(strfind(r.protocol, 'FullChromaticGrating'))
      fullGrate = true;
    else
      fullGrate = false;
    end
    epoch = epochBlock.getEpochs{1};
    r.params.waitTime = epochBlock.protocolParameters('waitTime');
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.spatialClass = epochBlock.protocolParameters('spatialClass');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    if isKey(epochBlock.protocolParameters, 'orientations')
      if fullGrate
        r.params.orientations = epochBlock.protocolParameters('orientations');
      else
        r.params.orientation = epochBlock.protocolParameters('orientations');
      end
    else
      r.params.orientation = epochBlock.protocolParameters('orientation');
    end
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.spatialFrequencies = epochBlock.protocolParameters('spatialFreqs');
    if fullGrate
      r.params.spatialFrequencies = repmat(r.params.spatialFrequencies, [1 length(r.params.orientations)]);
    end
    r.params.spatialFrequencies = r.params.spatialFrequencies(1:r.numEpochs);
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

    if fullGrate
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
      switch r.params.recordingType
      case 'extracellular'
        r.spikeBlock = reshape(r.spikes, length(r.params.orientations), length(r.params.SFs), size(r.spikes,2));
      case 'voltage_clamp'
        r.analogBlock = reshape(r.analog, length(r.params.orientations), length(r.params.SFs), size(r.analog,2));
      end

      for ii = 1:length(r.params.orientations)
        deg = sprintf('deg%u', r.params.orientations(ii));
        r.(deg).resp = r.resp(ii,:,:);
        switch r.params.recordingType
        case 'extracellular'
          r.(deg).spikes = r.spikes(ii,:);
        case 'voltage_clamp'
          r.(deg).analog = r.analog(ii,:);
        end
      end
    end

  case 'edu.washington.riekelab.sara.protocols.CompareCones'
    r.params.coneOne = epochBlock.protocolParameters('coneOne');
    r.params.coneTwo = epochBlock.protocolParameters('coneTwo');
    r.params.contrast = epochBlock.protocolParameters('contrast');


  case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
    r.params.stimulusClass = epochBlock.protocolParameters('stimulusClass');
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.radii = epochBlock.protocolParameters('radii');
    if r.numEpochs <= length(r.params.radii)
      r.params.radii = r.params.radii(1:r.numEpochs);
    else
      r.params.radii = [r.params.radii r.params.radii(1:r.numEpochs-length(r.params.radii))];
    end
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
    if isKey(epochBlock.protocolParameters, 'maskRadius')
      r.params.maskRadius = epochBlock.protocolParameters('maskRadius');
    end
    if isKey(epochBlock.protocolParameters, 'equalQuantalCatch')
      r.params.equalQuantalCatch = epochBlock.protocolParameters('equalQuantalCatch');
    else
      r.params.equalQuantalCatch = 0;
    end
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
      epoch = epochBlock.getEpochs{ep}; % get epoch
      if ep <= length(r.params.stimClass) && isKey(epoch.protocolParameters, 'sweepColor')
          r.params.plotColors(ep,:) = epoch.protocolParameters('sweepColor');
      end
      r.trials(ep).chromaticClass = epoch.protocolParameters('chromaticClass');
    end

  case 'edu.washington.riekelab.protocols.PulseFamily'
    r.params.firstPulseSignal = epochBlock.protocolParameters('firstPulseSignal');
    r.params.incrementPerPulse = epochBlock.protocolParameters('incrementPerPulse');
    r.params.pulsesInFamily = epochBlock.protocolParameters('pulsesInFamily');
    r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');

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

  case 'edu.washington.riekelab.manookin.protocols.InjectNoise'
    r.params.frequencyCutoff = epochBlock.protocolParameters('frequencyCutoff');
    r.params.numberOfFilters = epochBlock.protocolParameters('numberOfFilters');
    r.params.stdev = epochBlock.protocolParameters('stdev');
    r.params.randomSeed = epochBlock.protocolParameters('randomSeed');
    r.params.correlation = epochBlock.protocolParameters('correlation');
    if isKey(epochBlock.protocolParameters, 'amp2PulseAmplitude');
      r.params.amp2PulseAmplitude = epochBlock.protocolParameters('amp2PulseAmplitude');
      r.params.interpulseInterval = epochBlock.protocolParamters('interpulseInterval');
    end
    r.param.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
    r.params.onlineAnalysis = epochBlock.protocolParameters('onlineAnalysis');
    r.params.seed = zeros(r.numEpochs, 1);
    for ii = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ii};
      r.params.seed(ii) = epoch.protocolParameters('seed');
    end

  case 'edu.washington.riekelab.manookin.protocols.InjectChirp'
    r.params.chirpRate = epochBlock.protocolParameters('chirpRate');
    r.params.invertRate = epochBlock.protocolParameters('invertRate');
    r.params.interpulseInterval = epochBlock.protocolParamters('interpulseInterval');
    r.params.amplitude = epochBlock.protocolParameters('amplitude');
    % TODO: sample rate

  case {'edu.washington.riekelab.protocols.Pulse',...
    'edu.washington.riekelab.manookin.protocols.ResistanceAndCapacitance'}
    r.params.pulseAmplitude = epochBlock.protocolParameters('pulseAmplitude');
    r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
    r.params.interpulseInterval = epochBlock.protocolParameters('interpulseInterval');
    if isKey(epochBlock.protocolParameters, 'amp2PulseAmplitude')
      r.params.amp2PulseAmplitude = epochBlock.protocolParameters('amp2PulseAmplitude');
    end
    if isKey(epochBlock.protocolParameters, 'onlineAnalysis')
      r.params.onlineAnalysis = epochBlock.protocolParameters('onlineAnalysis');
    end

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

  case 'edu.washington.riekelab.sara.protocols.IsoSTC'
    r.params.paradigmClass = epochBlock.protocolParameters('paradigmClass');
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    switch r.params.paradigmClass
    case 'ID'
      r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
      r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    case 'STA'
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

  case 'edu.washington.riekelab.manookin.protocols.MovingBar'
    r.params.barSize = epochBlock.protocolParameters('barSize');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    r.params.intensity = epochBlock.protocolParameters('intensity');
    r.params.outerMaskRadius = epochBlock.protocolParameters('outerMaskRadius');
    r.params.innerMaskRadius = epochBlock.protocolParameters('innerMaskRadius');
    r.params.orientations = epochBlock.protocolParameters('orientations');
    r.params.randomOrder = epochBlock.protocolParameters('randomOrder');
    r.params.interpulseInterval = epochBlock.protocolParameters('interpulseInterval');
    r.params.speed = epochBlock.protocolParameters('speed');

    r.respBlock = zeros(length(r.params.orientations), ceil(r.numEpochs/length(r.params.orientations)), size(r.resp,2));
    if strcmp(r.params.recordingType, 'extracellular')
      r.instFt = zeros(size(r.respBlock));
    else
      r.analog = zeros(size(r.respBlock));
    end
    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep};
      r.params.orientation(1, ep) = epoch.protocolParameters('orientation');
      o = find(r.params.orientations == r.params.orientation(1, ep)); % for rand order
      r.respBlock(o, ceil(ep/length(r.params.orientations)), :) = r.resp(ep, :);
      if strcmp(r.params.recordingType, 'extracellular')
        % r.instFt(o, ceil(ep/length(r.params.orientations)), :) = getInstFiringRate(r.spikes(ep,:), r.params.sampleRate);
      else
        r.analogBlock(o, ceil(ep/length(r.params.orientations)), :) = r.analog(ep, :);
      end
    end

  case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'
    r.params.radius = epochBlock.protocolParameters('radius');
    r.params.radiusMicrons = r.params.radius * r.params.micronsPerPixel;
    r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
    r.params.stimulusClass = epochBlock.protocolParameters('stimulusClass');
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.contrasts = epochBlock.protocolParameters('contrasts');
    if r.numEpochs <= r.params.contrasts
      r.params.contrasts = r.params.contrasts(1:r.numEpochs);
    else
      r.params.contrasts = [r.params.contrasts r.params.contrasts(1:r.numEpochs-length(r.params.contrasts))];
    end
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
    r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
    r.params.positions = epochBlock.protocolParameters('positions');
    if r.numEpochs <= length(r.params.positions)
      r.params.positions = r.params.positions(1:r.numEpochs);
    else
      r.params.positions = [r.params.positions r.params.positions(1:r.numEpochs-length(r.params.positions))];
    end
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');

  case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
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

  case 'edu.washington.riekelab.manookin.protocols.GliderStimulus'
    r.params.stimuli = {'uncorrelated', '2-point positive', '2-point negative', '3-point diverging positive', '3-point converging positive', '3-point diverging negative', '3-point converging negative'};
    r.params.numStimFrames = ceil(r.params.stimTime/1000*r.params.frameRate) + 10;
    r.params.stixelSize = epochBlock.protocolParameters('stixelSize');
    r.params.stixelSizeMicrons = r.params.stixelSize * r.params.micronsPerPixel;
    r.params.orientation = epochBlock.protocolParameters('orientation');
    r.params.dimensionality = epochBlock.protocolParameters('dimensionality');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.waitTime = epochBlock.protocolParameters('waitTime');
    r.params.innerRadius = epochBlock.protocolParameters('innerRadius');
    r.params.innerRadiusMicrons = r.params.innerRadius * r.params.micronsPerPixel;
    r.params.outerRadius = epochBlock.protocolParameters('outerRadius');
    r.params.outerRadiusMicrons = r.params.outerRadius * r.params.micronsPerPixel;
    r.params.randomSeed = epochBlock.protocolParameters('randomSeed');
    if isKey(epochBlock.protocolParameters, 'centerOffset')
      r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    end

    % group by stimulus
    r.block.resp = zeros(length(r.params.stimuli), ceil(r.numEpochs/length(r.params.stimuli)), size(r.resp,2));
    switch r.params.recordingType
      case 'extracellular'
        r.block.spikes = size(r.block.resp);
      case 'voltage_clamp'
        r.block.analog = size(r.block.resp);
      case 'current_clamp'
        r.block.spikes = size(r.block.resp);
        r.block.subthresh = size(r.block.resp);
    end
    for ep = 1:r.numEpochs
      [ind1, ind2] = ind2sub([length(r.params.stimuli), size(r.block.resp,2)], ep);
      r.block.resp(ind1, ind2, :) = r.resp(ep,:);
      switch r.params.recordingType
      % case 'extracellular'
      %   r.block.spikes(ind1, ind2, :) = r.spikes(ep, :);
      case 'voltage_clamp'
        r.block.analog(ind1, ind2, :) = r.analog(ep, :);
      case 'current_clamp'
        r.block.spikes(ind1, ind2, :) = r.ICspikes(ep, :);
        r.block.subthresh(ind1, ind2, :) = r.subthresh(ep, :);
      end
    end

    % init epoch specific parameters
    r.params.seed = zeros(r.numEpochs, 1);
    r.params.parity = zeros(r.numEpochs, 1);
    r.params.stimulusType = cell(r.numEpochs, 1);
    r.params.glider = cell(r.numEpochs, 1);

    % get epoch specific parameters
    for ii = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ii};
      if ii == 1
        r.params.numYChecks = epoch.protocolParameters('numYChecks');
        r.params.numXChecks = epoch.protocolParameters('numXChecks');
      end
      r.params.stimulusType{ii} = epoch.protocolParameters('stimulusType');
      r.params.seed(ii) = epoch.protocolParameters('seed');

      if isempty(strfind(r.params.stimulusType{ii}, 'uncorrelated'))
        if isempty(strfind(r.params.stimulusType{ii}, 'positive'))
          r.params.parity(ii) = 1; % negative
        else
          r.params.parity(ii) = 0; % positive
        end
      else
        r.params.glider{ii} = 0;
      end
      % get the glider matrix
      switch r.params.stimulusType{ii}
        case {'2-point positive', '2-point negative'}
          r.params.glider{ii} = [0 1 1; 1 1 0];
        case {'3-point diverging positive', '3-point diverging negative'}
          r.params.glider{ii} = [0 1 1; 1 1 1; 1 1 0];
        case {'3-point converging positive', '3-point converging negative'}
          r.params.glider{ii} = [0 0 0; 1 0 0; 1 0 1];
      end
      % get frames - either noise or glider
      if strcmp(r.params.stimulusType{ii}, 'uncorrelated')
        noiseStream = RandStream('mt19937ar', 'Seed', r.params.seed(ii));
        r.params.frameSequence{ii} = (noiseStream.rand(r.params.numYChecks,...
          r.params.numXChecks, r.params.numStimFrames) > 0.5);
      else
        r.params.frameSequence{ii} = makeGlider(r.params.numYChecks, r.params.numXChecks,...
          r.params.numStimFrames, r.params.glider{ii}, r.params.parity(ii), r.params.seed(ii));
      end
    end

  case {'edu.washington.riekelab.manookin.protocols.SpatialNoise',...
    'edu.washington.riekelab.sara.protocols.TempSpatialNoise',...
    'edu.washington.riekelab.sara.protocols.SpatialReceptiveField'}
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

  case 'edu.washington.riekelab.manookin.protocols.OrthographicAnnulus'
    r.params.sequence = epochBlock.protocolParameters('sequence');
    r.params.widthPix = epochBlock.protocolParameters('widthPix');
    r.params.spatialClass = epochBlock.protocolParameters('spatialClass');
    r.params.minRadius = epochBlock.protocolParameters('minRadius');
    r.params.maxRadius = epochBlock.protocolParameters('maxRadius');
    r.params.speed = epochBlock.protocolParameters('speed');
    r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
    r.params.contrast = epochBlock.protocolParameters('contrast');
    r.params.backgroundIntensity = epochBlock.protocolParameters('backgroundIntensity');
    r.params.waitTime = epochBlock.protocolParameters('waitTime');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    r.params.onlineAnalysis = epochBlock.protocolParameters('onlineAnalysis');

    r.params.intensity = zeros(1, r.numEpochs);
    r.params.direction = cell(1, r.numEpochs);

    for ep = 1:r.numEpochs
      epoch = epochBlock.getEpochs{ep};
      r.params.intensity(1, ep) = epoch.protocolParameters('intensity');
      r.params.direction{1, ep} = epoch.protocolParameters('direction');
    end
  end


  if isfield(r.params, 'chromaticClass')
    r.params.plotColor = getPlotColor(r.params.chromaticClass);
  end

  % flag for serious bathTemp issues (usually bc out of ames)
  if ~isempty(find(r.params.bathTemp < 28))
    fprintf('Low bath temp --> %.2f\n', min(r.params.bathTemp));
    r.bathTempFlag = 1;
  end

  % save date parsed
  r.log = cell(2,1);
  r.log{1} = ['recorded at ' r.startTimes{1}];
  r.log{2} = ['parsed at ' datestr(now)];
end % parseEpochBlock

%% ANALYSIS FUNCTIONS------------------------------------------
  function [spikes, spikeTimes, spikeAmps, refViols] = getSpikes(response, detectionMethod)
    switch detectionMethod
      case 'SpikeDetector'
        [spikeTimes, spikeAmps, refViols] = SpikeDetector(response);
      case 'check'
        [spikeTimes, spikeAmps, refViols] = SpikeDetector(response, 'checkDetection', true);
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

  function instFt = getInstFiringRate(response, sampleRate)
    % instantaneous firing rate
    filterSigma = (20/1000)*sampleRate;
    newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);
    instFt = sampleRate*conv(response, newFilt, 'same');
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
