function r = parseDataOnline(symphonyInput, recordingType, varargin)
  % INPUTS:
  %     symphonyInput: epochBlock (or epochGroup for ChromaticSpot)
  %     ampNum: which amplifier to analyze. for paired recordings
  %     comp: input 'slu' if don't have wavelet toolbox
  %     recordingType: in case it isn't defined thru onlineAnalysis or epochGroup name. 
  %                   options are 'extracellular', 'voltage_clamp', 'current_clamp'
  %     analysisType: program should pick up on this unless it's a dual recording
  %         options for extracellular are 'single', 'paired' and 'dual'
  %         for voltage_clamp: 'excitation', 'inhibition'
  %         for current_clamp: 'spikes&subthresh' (in future: 'spikes', 'subthresh')
  %         TODO: paired w/ one dual amp, make sure inh, exc detection is legit
  %
  %
  %
  % also for quick offline data
  % will soon switch over to better object system

  ip = inputParser();
  ip.addParameter('ampNum', 1, @(x)isvector(x));
  ip.addParameter('comp', 'laptop', @(x)ischar(x));
  ip.addParameter('analysisType', [], @(x)ischar(x));
  ip.parse(varargin{:});
  ampNum = ip.Results.ampNum;
  comp = ip.Results.comp;
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
      r.data(eb).timingFlag(1, r.numEpochs) = checkFrames(epoch);
      % get response
      resp = epoch.getResponses{ampNum}.getData;
      if ep == 1
        r.data(eb).resp = zeros(r.numEpochs, length(resp));
      end
      r.data(eb).resp(ep,:) = resp;
      % get recording type --> TODO: clean up once i figure out how to access EpochGroup properties
      if ep == 1
        if ~isempty(recordingType)
          r.data(eb).recordingType = recordingType;          
        else
          if strcmp(r.data(eb).params.onlineAnalysis, 'analog') || ~isempty(strfind('WC ', r.data(eb).label))
              r.data(eb).recordingType = 'voltage_clamp';
          else % extracellular
              r.data(eb).recordingType = 'extracellular';
          end
        end
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
        [r.data(eb).spikes(ep,:), r.data(eb).spikeData.times{ep}, r.data(eb).spikeData.amps{ep}] = getSpikes(resp, comp);
        r.data(eb).spikeData.resp(ep, r.data(eb).spikeData.times{ep}) = r.data(eb).spikeData.amps{ep};
      case 'voltage_clamp'        
        if ep == 1
          r.data(eb).analog = zeros(size(r.data(eb).resp));
        end
        r.data(eb).analog(ep,:) = getAnalog(resp, r.data(eb).params.preTime, r.data(eb).params.sampleRate);
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
  if isKey(epochBlock.protocolParameters, 'backgroundIntensity')
    r.params.backgroundIntensity = epochBlock.protocolParameters('backgroundIntensity');
    r.params.onlineAnalysis =epochBlock.protocolParameters('onlineAnalysis');
  end
    r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
  r.params.sampleRate = 10000;

  % init new monitoring params
  r.params.bathTemp = zeros(1, r.numEpochs);
  r.params.timingFlag = zeros(1, r.numEpochs);

  % data from all protocols and epoch parameters
  for ep = 1:r.numEpochs
    epoch = epochBlock.getEpochs{ep}; % get epoch
    resp = epoch.getResponses{ampNum}.getData; % get response
    if ep == 1
      r.resp = zeros(r.numEpochs, length(resp));
      % set the recording type
      if ~isempty(recordingType)
        r.params.recordingType = recordingType;
      else
        if strcmp(r.params.onlineAnalysis, 'analog') || ~isempty(strfind('WC ', r.groupName))
          r.params.recordingType = 'voltage_clamp';
        elseif ~isempty(strfind('IC ', r.groupName(1:2)))
          r.params.recordingType = 'current_clamp';
        else 
          r.params.recordingType = 'extracellular';
        end
      end
      % preallocate initial data analysis 
      switch r.params.recordingType
          case 'voltage_clamp'
            r.analog = zeros(size(r.resp)); 
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
  %        [r.spikes(ep,:), r.spikeData.times{ep}, r.spikeData.amps{ep}] = getSpikes(resp, comp);
   %       r.spikeData.resp(ep, r.spikeData.times{ep}) = r.spikeData.amps{ep};
        case 'voltage_clamp'
          if mean(resp) > 0
            r.params.analysisType = 'inhibition';
          else
            r.params.analysisType = 'excitation';
          end
 %         r.analog(ep,:) = getAnalog(resp, r.params.preTime, r.params.sampleRate);   
        case 'current_clamp'
          r.params.analysisType = 'spikes&subthresh';
%          [r.ICspikes(ep,:), r.ICstikeTimes(ep,:), r.subthresh(ep,:)] = getSubthreshSpikes(resp, r.params.preTime, r.params.sampleRate);
        end 
      end
      if isempty(strfind(r.protocol, 'Pulse')) && isempty(strfind(r.protocol, 'Inject'))
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
          [r.spikes(ep,:), r.spikeData.times{ep}, r.spikeData.amps{ep}] = getSpikes(resp, comp);
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

  case {'edu.washington.riekelab.protocols.Pulse', 'edu.washington.riekelab.manookin.protocols.ResistanceAndCapacitance'}
    r.params.pulseAmplitude = epochBlock.protocolParameters('pulseAmplitude');
    r.params.numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
    r.params.interpulseInterval = epochBlock.protocolParameters('interpulseInterval');
    r.params.amp2PulseAmplitude = epochBlock.protocolParameters('amp2PulseAmplitude');
    r.params.onlineAnalysis = epochBlock.protocolParameters('onlineAnalysis');

    if ~isempty(strfind(r.protocol, 'Resistance'))
      % get the online analysis properties attached to the last epoch
      lastEpoch = epochBlock.getEpochs{r.numEpochs};
      r.oa.rInput = epochBlock.protocolParameters('rInput');
      r.oa.rSeries = epochBlock.protocolParameters('rSeries');
      r.oa.rMembrane = epochBlock.protocolParameters('rMembrane');
      r.oa.rTau = epochBlock.protocolParameters('rTau');
      r.oa.capacitance = epochBlock.protocolParamters('capacitance');
      r.oa.tau_msec = epochBlock.protocolParameters('tau_msec');
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
%   sequence = (1:length(r.params.stimuli))' * ones(1, r.numEpochs);
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
%      case 'extracellular'
%        r.block.spikes(ind1, ind2, :) = r.spikes(ep, :);
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
%     r.params.parity{ii} = epoch.protocolParameters('stimulusType');
%     r.params.stimulusName{ii} = r.params.stimuli{mod(ii -1, length(r.params.stimuli)) + 1};
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
      fprintf('epoch %u - parity = %u, stim = %s, glider = %u x %u\n',... 
          ii, r.params.parity(ii), r.params.stimulusType{ii},... 
          size(r.params.glider{ii},1), size(r.params.glider{ii},2));
      % get frames - either noise or glider
      if strcmp(r.params.stimulusType{ii}, 'uncorrelated')
        noiseStream = RandStream('mt19937ar', 'Seed', r.params.seed(ii));
        r.params.frameSequence{ii} = (noiseStream.rand(r.params.numYChecks, r.params.numXChecks, r.params.numStimFrames) > 0.5);
      else
        r.params.frameSequence{ii} = makeGlider(r.params.numYChecks, r.params.numXChecks, r.params.numStimFrames, r.params.glider{ii}, r.params.parity(ii), r.params.seed(ii));
      end
    end

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
  if ~isempty(find(r.params.bathTemp < 28))
    fprintf('Low bath temp --> %.2f\n', min(r.params.bathTemp));
    r.bathTempFlag = 1;
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
  end % parseEpochBlock
end % overall function
