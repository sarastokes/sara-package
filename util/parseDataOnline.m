function r = parseDataOnline(epochBlock)
  % also for quick offline data

  numEpochs = length(epochBlock.epochs);
  trial = 0;
  % data from all protocols
  for ii = 1:numEpochs
    epoch = epochBlock.epochs{ii}; % get epoch
    resp = epoch.responses{1}.getData; % get response
    if ii == 1
      r.protocol = epochBlock.protocolId; % get protocol name
      r.resp = zeros(numEpochs, length(resp));
      r.spikes = zeros(size(r.resp));
      r.startTime = epoch.startTime;
      r.params.preTime = epochBlock.protocolParameters('preTime');
      r.params.stimTime = epochBlock.protocolParameters('stimTime');
      r.params.tailTime = epochBlock.protocolParameters('tailTime');
      r.params.backgroundIntensity = epochBlock.protocolParameters('backgroundIntensity');
      r.params.ndf = epoch.protocolParameters('ndf');
      r.params.objectiveMag = epoch.protocolParameters('objectiveMag');
      r.params.micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
      r.params. numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
      r.params.frameRate = epoch.protocolParameters('frameRate');
      r.params.sampleRate = 10000;
      r.params.onlineAnalysis =epochBlock.protocolParameters('onlineAnalysis');
    end
      r.resp(ii,:) = resp;
      spikes = getSpikes(resp); % assuming cell-attached
      foo = size(spikes);
      fprintf('size of spikes is %u %u\n', foo(1), foo(2));
  end

  % protocol specific data - could be condensed but keeping each protocol separate for now.

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticGrating')
    for ii = 1:numEpochs
      epoch = epochBlock.epochs{ii};
      if ii == 1
        r.params.waitTime = protocolParameters('waitTime');
        r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
        r.params.contrast = epochBlock.protocolParameters('contrast');
        r.params.spatialClass = epochBlock.protocolParameters('spatialClass');
        r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
        r.params.orientation = epochBlock.protocolParameters('orientation');
        r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
        r.params.spatialFrequencies = epochBlock.protocolParameters('spatialFreqs');
        r.params.spatialPhase = epochBlock.protocolParameters('spatialPhase');
        r.params.randomOrder = epochBlock.protocolParameters('randomOrder');
        r.params.apertureClass = epochBlock.protocolParameters('apertureClass');
        r.params.apertureRadius = epochBlock.protocolParameters('apertureRadius');
        r.params.apertureRadiusMicrons = r.params.apertureRadius * r.params.micronsPerPixel;
      end
      [r.params.f1amp(ii), r.params.f1phase(ii), r.params.f2amp(ii), r.params.f2phase(ii)] = CTRanalysis(r, r.spikes(ii,:));
    end
  end


  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ConeSweep')
    for ii = 1:numEpochs
      epoch = epochBlock.epochs{ii}; % get epoch
      if ii == 1
        r.params.stimClass = epochBlock.protocolParameters('stimClass');
        r.params.contrast = epochBlock.protocolParameters('contrast');
        r.params.radius = epochBlock.protocolParameters('radius');
        r.params.radiusMicrons = r.params.radius * r.params.micronsPerPix;
        r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
        r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
        r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
        r.params.reverseOrder = epochBlock.protocolParameters('reverseOrder');
        r.analysis.f1amp = zeros(length(r.params.stimClass), numEpochs/length(r.params.stimClass));
        r.analysis.f1phase = zeros(length(r.params.stimClass), numEpochs/length(r.params.stimClass));
      end
      index = rem(ii, length(r.params.stimClass));
      if index == 0
        index = length(r.params.stimClass);
      elseif index == 1
        trial = trial + 1;
      end
      r.trials(ii).chromaticClass = epoch.protocolParameters('chromaticClass');
      [r.analysis.f1amp(index,trial), r.analysis.f1phase(index,trial)] = CTRAnalysis(r, r.spikes(ii,:));
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.IsoSTC')
    for ii = 1:numEpochs
      epoch = epochBlock.epochs{ii}; % get epoch
      if ii == 1
        r.params.paradigmClass = epochBlock.protocolParameters('paradigmClass');
        r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
        r.params.contrast = epochBlock.protocolParameters('contrast');
        r.params.radius = epochBlock.protocolParameters('radius');
        r.params.radiusMicrons = r.params.radius * r.params.micronsPerPix;
        if strcmp(r.params.paradigmClass,'ID')
          r.params.temporalClass = epoch.protocolParameters('temporalClass');
        elseif strcmp(r.params.paradigmClass, 'STA')
          r.params.randomSeed = epochBlock.protocolParameters('randomSeed');
          r.params.stdev = epochBlock.protocolParameters('stdev');
          r.analysis.lf = zeros(numEpochs, 60);
          r.analysis.linearFilter = zeros(1, 60);
        end
        r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
      end
      r.params.seed = epoch.protocolParameters('seed');
      [r.analysis.lf(ii,:), r.analysis.linearFilter] = MTFanalysis(r, r.spikes(ii,:));
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.BarCentering')
    r.params.searchAxis = epochBlock.protocolParameters('searchAxis');
    r.params.barSize = epochBlock.protocolParameters('barSize');
    r.params.intensity = epochBlock.protocolParameters('intensity');
    r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
    r.params.positions = epochBlock.protocolParameters('positions');
    r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
    for ii = 1:numEpochs
      [r.params.f1amp(ii), r.params.f1phase(ii), r.params.f2amp(ii), r.params.f2phase(ii)] = CTRanalysis(r, r.spikes(ii,:));
    end
  end



%% ANALYSIS FUNCTIONS------------------------------------------

  function spikes = getSpikes(response)
    response = wavefilter(response(:)', 6)';
    S = spikeDetectorOnline(response);
    spikes = zeros(size(response));
    spikes(S.sp) = 1;
  end

  function [f1amp, f1phase, f2amp, f2phase] = CTRanalysis(r, spikes)
    responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate+1 : end);
    binRate = 60;
    binWidth = r.params.sampleRate/binRate;
    numBins = floor(r.params.stimTime/1000 * binRate);
    binData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end
    binsPerCycle = binRate / r.params.temporalFrequency;
    numCycles = floor(length(binData) / binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));

    for k = 1:numCycles
      index = round((k-1) * binsPerCycle) + (1:floor(binsPerCycle));
      cycleData = cycleData + binData(index);
    end
    cycleData = cycleData / k;

    % get the F1 response
    ft = fft(cycleData);
    f1amp = abs(ft(2))/length(ft)*2; f1phase = angle(ft(2)) * 180/pi;
    f2amp = abs(ft(3))/length(ft)*2; f2phase = angle(ft(3)) * 180/pi;
  end

  function [lf, linearFilter] = MTFanalysis(r, spikes)
    % lf is individual epoch
    % linearFilter is mean of epochs analyzed so far, pulled from struct
    responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate);
    binWidth = r.params.sampleRate / r.params.frameRate;
    numBins = floor(r.params.stimTime/1000 * r.params.frameRate);
    binData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end

    % seed random number generator
    noiseStream = RandStream('mt19937ar', 'seed', r.params.seed);

    % get the frame values
    frameValues = r.params.stdev * noiseStream.randn(1, numBins);

    % get rid of the first 0.5s
    frameValues(1:30) = 0;
    binData(1:30) = 0;

    % run reverse correlation
    lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
    linearFilter = r.analysis.linearFilter * lf(1 : floor(r.params.frameRate));
  end

%% functions that should be in utils - here for offline if not in path
  function results = spikeDetectorOnline(D,thresh,sampleRate)
    %For online analysis
    %D is matrix of spike recording data
    %Thresh is deflection threshold to call an event a spike and not noise
    %If no thresh, automatically uses 1/3 maximum deflection amplitude as
    %threshold
    %This does a pretty good job for big-ish spikes, and it's fast. I would use
    %something a little more versatile for offline analysis, though
    %MHT 080514

    % AIW 121014
    % Added section "make sure detected spikes aren't just noise"
    % Previously, code would find many spikes on trials with no spikes

    if (nargin < 2)
        thresh = []; %define on trace-by-trace basis automatically, as 1/3rd of maximum deflection. Decent job.
        sampleRate = 1e4; %Hz, default at 10kHz
    end
    HighPassCut_spikes = 500; %Hz, in order to remove everything but spikes
    SampleInterval = sampleRate^-1;
    ref_period = 2E-3; %s
    ref_period_points = round(ref_period./SampleInterval); %data points

    [Ntraces,L] = size(D);
    Dhighpass = highPassFilter(D,HighPassCut_spikes,SampleInterval);

    %initialize output stuff...
    sp = cell(Ntraces,1);
    spikeAmps = cell(Ntraces,1);
    violation_ind = cell(Ntraces,1);

    for i=1:Ntraces
        %get the trace
        trace = Dhighpass(i,:);
        trace = trace - median(trace); %remove baseline
        if abs(max(trace)) < abs(min(trace)) %flip it over
            trace = -trace;
        end
        if isempty(thresh)
            thresh = max(trace)/3;
        end

        %get peaks
        [peaks,peak_times] = getPeaks(trace,1); %positive peaks
        peak_times = peak_times(peaks>0); %only positive deflections
        peaks = trace(peak_times);
        peak_times = peak_times(peaks>thresh);
        peaks = peaks(peaks>thresh);

        %%% make sure detected spikes aren't just noise
        peakIdx = zeros(size(trace));
        peakIdx(peak_times) = 1;
        nonspike_peaks = trace(~peakIdx); % trace values at time points that weren't detected as spikes
        % compare magnitude of detected spikes to trace values that aren't "spikes"
        if mean((peaks)) < mean((nonspike_peaks)) + 4*std((nonspike_peaks)); % avg spike must be 4 stdevs from average non-spike, otherwise no spikes
            peak_times = [];
            peaks = [];
        end
        %%%

        sp{i} = peak_times;
        spikeAmps{i} = peaks;
        violation_ind{i} = find(diff(sp{i})<ref_period_points) + 1;
    end

    if length(sp) == 1 %return vector not cell array if only 1 trial
        sp = sp{1};
        spikeAmps = spikeAmps{1};
        violation_ind = violation_ind{1};
    end

    results.sp = sp; %spike times (data points)
    results.spikeAmps = spikeAmps;
    results.violation_ind = violation_ind; %refractory violations in results.sp
  end

  function [peaks,Ind] = getPeaks(X,dir)
    if dir > 0 %local max
        Ind = find(diff(diff(X)>0)<0)+1;
    else %local min
        Ind = find(diff(diff(X)>0)>0)+1;
    end
    peaks = X(Ind);
  end

  function Xfilt = highPassFilter(X,F,SampleInterval)
    % %F is in Hz
    % %Sample interval is in seconds
    % %X is a vector or a matrix of row vectors
    L = size(X,2);
    if L == 1 %flip if given a column vector
      X=X';
      L = size(X,2);
    end
    FreqStepSize = 1/(SampleInterval * L);
    FreqKeepPts = round(F / FreqStepSize);

    % eliminate frequencies beyond cutoff (middle of matrix given fft
    % representation)

    FFTData = fft(X, [], 2);
    FFTData(:,1:FreqKeepPts) = 0;
    FFTData(end-FreqKeepPts:end) = 0;
    Xfilt = real(ifft(FFTData, [], 2));
  end
end % overall function
