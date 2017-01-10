function r = analyzeDataOnline(r, neuron, varargin)
  % INPUT = r, neuron
  % OPTIONAL =  neuron (empty = 1, 2 for 2nd neuron)
  %             bpf = bins per frame (default = 1 for light/ 480 for i/v)
  %             strfMethod = revCorr, STA (default revCorr, STA is slower)
  %
  % 5Oct2016 - added 2nd neuron option
  % 11Nov2016 - using analysisType and recordingType now rather than onlineAnalysis & assuming extracellular (lines 26-33 should keep things compatible)
  % 5Dec2016 - lots of changes, added some of mike's stimuli, most significant: now saving time of analysis
  % 19Dec2016 - restructured for 2nd neuron - using analysis, not r.analysis


  if nargin < 2
    neuron = 1;
  end

  ip = inputParser();
  ip.addParameter('bpf', 1, @(x)isvector(x));
  ip.addParameter('strfMethod', 'revCorr', @(x)ischar(x));
  ip.parse(varargin{:});
  binsPerFrame = ip.Results.bpf;
  strfMethod = ip.Results.strfMethod;

  % keep up with new log changes
  if ~isfield(r, 'log')
    r.log{1} = ['recorded at ' r.startTimes{1}];
    r.log{2} = 'parsed before 10Dec2016 log update';
    fprintf('created log\n');
    return;
  end
  Log = r.log;

  if neuron == 1 
    if isfield(r, 'spikes')
      spikes = r.spikes;
    elseif isfield(r, 'analog')
      analog = r.analog;
    end
    if isfield(r, 'analysis')
      analysis = r.analysis;
    else
      analysis = struct;
    end
    Log{end+1} = ['analyzeDataOnline at ' datestr(now)];
  end

  % doubt i'll need paired WC analysis anytime soon...
  if neuron == 2
    if ~isfield(r, 'secondary')
      error('Second neuron not found');
    else
      spikes = r.secondary.spikes;
      if isfield(r.secondary, 'analysis')
        analysis = r.secondary.analysis;
      else
        analysis = struct;
      end
      fprintf('Analyzed with second neuron\n');
      Log{end+1} = ['analyzeDataOnline with 2nd neuron at ' datestr(now)];
    end
  end

  if neuron ~= 1 && neuron ~= 2
    error('Neuron must be either empty (1) or 2');
  end

  % if neuron doesn't have analysisType and recordingType yet, it was most likely extracellular
  if ~isfield(r.params, 'recordingType')
    r.params.recordingType = 'extracellular';
    fprintf('Set recordingType to extracellular\n');
  end

  if ~isfield(r.params, 'analysisType')
    if isfield(r, 'secondary')
      if neuron == 1
        r.params.analysisType = 'dual_c1';
      else
        r.params.analysisType = 'dual_c2';
      end
    else
      r.params.analysisType = 'single';
    end
    % not sure how to extract paired recordings at this stage
  end


  switch r.protocol
    case {'edu.washington.riekelab.sara.protocols.TempChromaticGrating',...
      'edu.washington.riekelab.manookin.protocols.ChromaticGrating'}
      analysis = sMTFanalysis(r);
      Log{end+1} = ['sMTFanalysis at ' datestr(now)];

    case 'edu.washington.riekelab.sara.protocols.FullChromaticGrating'
      f = fieldnames(r);
      ind = find(not(cellfun('isempty', strfind(f, 'deg'))));
      analysis.F1 = zeros(length(ind), length(unique(r.params.spatialFrequencies)));
      analysis.P1 = zeros(size(analysis.F1));
      deg = char(f{ind(1)});
      % get all the fft data
      analysis = sMTFanalysis(r, r.params);

      % distribute data to each orientation
      res = {'F1', 'P1', 'F2', 'P2'};
      for ii = 1:length(res)
        analysis.(res{ii}) = reshape(analysis.(res{ii}), [length(unique(r.params.spatialFrequencies)) length(r.params.orientations)]);
         analysis.(res{ii}) = analysis.(res{ii})';
        for jj = 1:length(r.params.orientations)
          deg = sprintf('deg%u', r.params.orientations(jj));
          analysis.(deg).(res{ii}) = analysis.(res{ii})(jj,:);
        end
      end

      Log{end+1} = ['sMTFanalysis for ' length(ind) ' orientations at ' datestr(now)];

    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      analysis.f1amp = zeros(length(r.params.stimClass), r.numEpochs/length(r.params.stimClass));
      analysis.f1phase = zeros(length(r.params.stimClass), r.numEpochs/length(r.params.stimClass));
      r.params.plotColors = zeros(length(r.params.stimClass), 3);
      if strcmp(r.params.recordingType, 'extracellular')
        r.instFt = zeros(size(r.respBlock));
      end

      switch r.params.recordingType
      case 'extracellular'
        for ep = 1:r.numEpochs
          [stim, trial] = ind2sub([length(r.params.stimClass) size(r.respBlock,2)], ep);
          [analysis.f1amp(stim,trial), analysis.f1phase(stim,trial), ~, ~] = CTRanalysis(r, spikes(ep,:));
          r.instFt(stim, trial, :) = getInstFiringRate(spikes(ep,:), r.params.sampleRate);
        end
        r.ptsh.binSize = 200;
        for sss = 1:length(r.params.stimClass)
          r.ptsh.(r.params.stimClass(sss)) = getPTSH(r, squeeze(r.spikeBlock(sss,:,:)), 200);
        end
        Log{end+1} = ['instFt calc at ' datestr(now)];
      case 'voltage_clamp'
        for ep = 1:r.numEpochs
          [stim, trial] = ind2sub([length(r.params.stimClass) size(r.respBlock,2)], ep);
          r.analogBlock(stim, trial, :) = r.analog(ep,:);
          [analysis.f1amp(stim,trial), analysis.f1phase(stim,trial), ~, ~] = CTRanalysis(r, r.analog(ep,:));
        end
        for sss = 1:length(r.params.stimClass)
          r.avgResp.(r.params.stimClass(sss)) = mean(squeeze(r.analogBlock(sss,:,:)));
        end
      case 'current_clamp'
        % not yet
      end
      Log{end+1} = ['CTRanalysis at ' datestr(now)];

    case 'edu.washington.riekelab.sara.protocols.IsoSTC'
      switch r.params.paradigmClass
        case 'STA'
        analysis.binsPerFrame = binsPerFrame; % default is 6
        analysis.binRate = 60 * analysis.binsPerFrame;
          if isempty(strfind(r.params.chromaticClass, 'RGB'))
            analysis.lf = zeros(r.numEpochs, analysis.binRate);
            analysis.linearFilter = zeros(1, analysis.binRate);
          else
            analysis.lf = zeros(r.numEpochs, 3, analysis.binRate);
            analysis.linearFilter = zeros(3, analysis.binRate);
          end
          for ep = 1:r.numEpochs
            if isempty(strfind(r.params.chromaticClass,'RGB'))
              [analysis.lf(ep,:), analysis.linearFilter] = MTFanalysis(r, analysis, spikes(ep,:), r.params.seed{ep});
            else
              [analysis.lf(ep,:,:), analysis.linearFilter] = MTFanalysis(r, analysis, spikes(ep,:), r.params.seed{ep});
            end
          end
          analysis.linearFilter = analysis.linearFilter/r.numEpochs;

          if isempty(strfind(r.params.chromaticClass, 'RGB'))
            analysis.linearFilter = analysis.linearFilter/std(analysis.linearFilter);
            % take the mean
            analysis.tempFT = abs(fft(analysis.linearFilter));

            % get the nonlinearity
            NL = nonlinearity(r, spikes);
            analysis.NL = NL;
          else
            analysis.tempFT = zeros(size(analysis.linearFilter));
            for ii = 1:3 % is it okay looking at RGB gun stdev separately?
              analysis.linearFilter(ii,:) = analysis.linearFilter(ii,:)/std(analysis.linearFilter(ii,:));
              analysis.tempFT(ii,:) = abs(fft(analysis.linearFilter(ii,:)));
            end
          end
            Log{end+1} = ['MTFanalysis at ' datestr(now)];
            Log{end+1} = ['nonlinearity at ' datestr(now)];
        case 'ID'
          switch r.params.recordingType
          case 'extracellular'
            for ep = 1:r.numEpochs
              [analysis.f1amp(ep), analysis.f1phase(ep), ~, ~] = CTRanalysis(r, spikes(ep,:));
            end
            analysis.ptshBin = 200;
            analysis.ptsh = getPTSH(r, spikes, 200);
          case 'voltage_clamp'
            for ep = 1:r.numEpochs
              [analysis.f1amp(ep), analysis.f1phase(ep), ~, ~] = CTRanalysis(r, r.analog(ep,:));
            end
            analysis.avgResp = mean(r.analog);
          end
          if r.numEpochs > 1
            analysis.meanAmp = mean(analysis.f1amp(ep));
            analysis.meanPhase = mean(analysis.f1phase(ep));
          else
            analysis.meanAmp = analysis.f1amp;
            analysis.meanPhase = analysis.f1phase;
          end
        end

    case 'edu.washington.riekelab.manookin.protocols.BarCentering'
      for ep = 1:r.numEpochs
        r = sMTFanalysis2(r, ep);
      end
      Log{end+1} = ['CTRanalysis at ' datestr(now)];

    case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'
      analysis.f1amp = zeros(1, length(r.numEpochs));
      analysis.f1phase = zeros(size(analysis.f1amp));
      analysis.f2amp = zeros(size(analysis.f1amp));
      analysis.f2phase = zeros(size(analysis.f1phase));
      analysis.xaxis = unique(r.params.contrasts);
      analysis.mean_f1amp = zeros(size(analysis.xaxis));

      for ep = 1:r.numEpochs
        [analysis.f1amp(ep), analysis.f1phase(ep), analysis.f2amp(ep), analysis.f2phase(ep)] = CTRanalysis(r, spikes(ep,:));
      end

      for xpt = 1:length(analysis.xaxis)
  	     numReps = find(r.params.contrasts == analysis.xaxis(xpt));
  	     analysis.mean_f1amp(xpt) = mean(analysis.f1amp(numReps));
         analysis.mean_f1phase(xpt) = mean(analysis.f1phase(numReps));
         analysis.mean_f2amp(xpt) = mean(analysis.f2amp(numReps));
         analysis.mean_f2phase(xpt) = mean(analysis.f2phase(numReps));
      end

    case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
      r.params.ledWeights = zeros(2*length(r.params.searchValues), 3);

      for ep = 1:2*length(r.params.searchValues)
        r = sMTFanalysis2(r, ep);
      end

      ap={'F0', 'F1', 'F2', 'P1', 'P2'}; % analysis params returned
      for ii = 1:length(ap)
        analysis.(sprintf('green%s', ap{ii})) = analysis.(ap{ii})(1:length(r.params.searchValues));
        analysis.(sprintf('red%s', ap{ii})) = analysis.(ap{ii})(length(r.params.searchValues)+1:end);
      end
      
      analysis.greenMin = r.params.searchValues(find(analysis.greenF1==min(analysis.greenF1), 1));
      fprintf('greenMin is %.3f\n', analysis.greenMin);          
      analysis.redMin = r.params.searchValues(find(analysis.redF1==min(analysis.redF1)));
      fprintf('redMin is %.3f\n', analysis.redMin);

    case 'edu.washington.riekelab.manookin.protocols.GaussianNoise'
      analysis.binsPerFrame = binsPerFrame; % default is 1
      analysis.binRate = 60 * analysis.binsPerFrame;
      analysis.linearFilter = zeros(1, analysis.binRate);
      analysis.lf = zeros(r.numEpochs, analysis.binRate);

      switch r.params.recordingType
      case 'extracellular'
        for ep = 1:r.numEpochs
          [analysis.lf(ep,:), analysis.linearFilter] = MTFanalysis(r, analysis, spikes(ep,:), r.params.seed(1,ep));
        end
        analysis.linearFilter = analysis.linearFilter/r.numEpochs;
      case 'voltage_clamp'
        for ep = 1:r.numEpochs
          [analysis.lf(ep,:), analysis.linearFilter] = MTFanalysis(r, analysis, r.analog(ep,:), r.params.seed(1,ep));
          analysis.linearFilter = analysis.linearFilter/r.numEpochs;
          if analysis.binsPerFrame == 6
            analysis.linearFilter = analysis.linearFilter - analysis.linearFilter(3);
            analysis.linearFilter(1:3) = 0;
          end
        end
      end
      analysis.linearFilter = analysis.linearFilter/std(analysis.linearFilter);

      % take the mean
      analysis.tempFT = abs(fft(analysis.linearFilter));

      % get the nonlinearity
      r = nonlinearity(r);

      Log{end+1} = ['MTFanalysis at ' datestr(now)];
      Log{end+1} = ['nonlinearity at ' datestr(now)];

    case {'edu.washington.riekelab.protocols.Pulse',... 
      'edu.washington.riekelab.manookin.protocols.ResistanceAndCapacitance'}
      try
        analysis = biophys(r, r.resp, r.params.pulseAmplitude);
      catch
        r.log{end+1} = 'SLU comp: did not run biophys';
      end

      outputStr = {['Rin = ' num2str(mean(analysis.oa.rInput)) ' MOhm']; ...
        ['Rs = ' num2str(mean(analysis.oa.rSeries)) ' MOhm']; ...
        ['Rm = ' num2str(mean(analysis.oa.rMembrane)) ' MOhm']; ...
        ['Rtau = ' num2str(mean(analysis.oa.rTau)) ' MOhm']; ...
        ['Cm = ' num2str(mean(analysis.oa.capacitance)) ' pF']; ...
        ['tau = ' num2str(mean(analysis.oa.tau_msec)) ' ms']};
      fprintf('%s\n', outputStr{:});

    case {'edu.washington.riekelab.protocols.PulseFamily'}
      for ii = 1:length(r.params.pulses)
        result = biophys(r, squeeze(r.respBlock(ii,:,:)), r.params.pulses(ii));
        analysis.charge(ii) = result.charge;
        analysis.current0(ii) = result.charge;
        analysis.currentSS(ii) = result.currentSS;
        analysis.rMem(ii) = result.rInput - result.rSeries;
        analysis.rSeries(ii) = result.rSeries;
        analysis.rInput(ii) = result.rInput;
        analysis.capacitance(ii) = result.capacitance;
        analysis.tauCharge(ii) = result.tauCharge;
        % calcs
        analysis.rTau(ii) = analysis.tauCharge(ii)/(analysis.capacitance(ii)* 1e-12)/1e9;
      end

      % clean all this up later.. just trying to see it work for now
      props = fieldnames(analysis);
      for ii = 1:length(props)
        outlier = getOutliers(analysis.(props{ii}), 5);
        ind = nonzeros(outlier);
        if ~isempty(ind) && ~isempty(find(ind == 0)) % all 1s is trouble
          analysis.(props{ii})(ind) = [];
          fprintf('found %u outliers in %s\n', ind, props{ii});
        end
      end

      outputStr = {['Rin = ' num2str(mean(analysis.rInput)) ' MOhm']; ...
          ['Rs = ' num2str(mean(analysis.rSeries)) ' MOhm']; ...
          ['Rm = ' num2str(mean(analysis.rMem)) ' MOhm']; ...
          ['Rtau = ' num2str(mean(analysis.rTau)) ' MOhm']; ...
          ['Cm = ' num2str(mean(analysis.capacitance)) ' pF']; ...
          ['tau = ' num2str(mean(analysis.tauCharge)) ' ms']};
      outputStr % to the cmd line

    case 'edu.washington.riekelab.manookin.protocols.InjectNoise'
      analysis.linearFilter = [];
      analysis.xaxis = [];
      analysis.yaxis = [];
      analysis.nonlinearityBins = 200;
      for ii = 1:r.numEpochs
        % starting with just spikes
        y = r.ICspikes(ii,:);

        binRate = 480; %TODO: check on this
        analysis.binRate = binRate;

        prePts = r.params.preTime*1e-3*r.params.sampleRate;
        stimPts = r.params.stimTime*1e-3*r.params.sampleRate;
        if strcmp(r.params.recordingType,'extracellular') || strcmp(r.params.recordingType, 'current_clamp')
            if r.params.sampleRate > binRate
                y = BinSpikeRate(y(prePts+1:end), binRate, r.params.sampleRate);
            else
                y = y(prePts+1:end)*r.params.sampleRate;
            end
        else
            % High-pass filter to get rid of drift.
            y = highPassFilter(y, 0.5, 1/r.params.sampleRate);
            if prePts > 0
                y = y - median(y(1:prePts));
            else
                y = y - median(y);
            end
            y = binData(y(prePts+1:end), binRate, r.params.sampleRate);
        end
         % Make sure it's a row.
        y = y(:)';

        frameValues = generateCurrentStim(r, r.params.seed(ii));
        frameValues = frameValues(prePts+1:stimPts);
        if r.params.sampleRate > binRate
            frameValues = decimate(frameValues, round(r.params.sampleRate/binRate));
        end
        analysis.plotLngth = round(binRate*0.025);

        % Make it the same size as the stim frames.
        y = y(1 : length(frameValues));

        % Zero out the first half-second while cell is adapting to
        % stimulus.
        y(1 : floor(binRate/2)) = 0;
        frameValues(1 : floor(binRate/2)) = 0;

        % Reverse correlation.
        lf = real(ifft( fft([y(:)' zeros(1,100)]) .* conj(fft([frameValues(:)' zeros(1,100)])) ));

        if isempty(analysis.linearFilter)
            analysis.linearFilter = lf;
        else
            analysis.linearFilter = (analysis.linearFilter*(ii-1) + lf)/ii;
        end
        % Re-bin the response for the nonlinearity.
        resp = binData(y, 60, binRate);
        if isempty(analysis.yaxis)
          analysis.yaxis = resp(:)';
        else
          analysis.yaxis = [analysis.yaxis, resp(:)'];
        end

        % Convolve stimulus with filter to get generator signal.
        pred = ifft(fft([frameValues(:)' zeros(1,100)]) .* fft(analysis.linearFilter(:)'));

        pred = binData(pred, 60, binRate); pred=pred(:)';
        analysis.xaxis = [analysis.xaxis, pred(1 : length(resp))];

        % Get the binned nonlinearity.
        [analysis.xBin, analysis.yBin] = getNL(r, analysis.xaxis, analysis.yaxis);
      end
      analysis.tempFT = abs(fft(analysis.linearFilter));

      analysis.log{end+1} = ['injectNoise analysis - run at ' datestr(now)];

    case {'edu.washington.riekelab.manookin.protocols.SpatialNoise',...
      'edu.washington.riekelab.manookin.protocols.TernaryNoise',...
      'edu.washington.riekelab.sara.protocols.TempSpatialNoise',...
      'edu.washington.riekelab.sara.protocols.SpatialReceptiveField'}
      r.epochCount = 0;

      analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
      analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);

      % x/y axes in microns
      r.params.xaxis = linspace(-r.params.numXChecks/2, r.params.numXChecks/2, r.params.numXChecks) * r.params.stixelSize;
      r.params.yaxis = linspace(-r.params.numYChecks/2, r.params.numYChecks/2, r.params.numYChecks) * r.params.stixelSize;

      switch strfMethod
      case 'revCorr'
        for ii = 1:r.numEpochs
          r.epochCount = r.epochCount + 1;
          if strcmp(r.params.chromaticClass, 'RGB')
            analysis.strf = zeros(3,r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
            analysis.spatialRF = zeros(3,r.params.numYChecks, r.params.numXChecks);
            if isfield(r, 'ICspikes')
              [r, analysis] = getSTRFOnline(r, analysis, r.ICspikes(ii,:), r.seed(ii));
            else
              [r, analysis] = getSTRFOnline(r, analysis, spikes(ii,:), r.seed(ii));
            end
          else
            % updated with mike's new online analysis stuff but now throws errors for RGB noise, will fix at some pt
            [r, analysis] = getSTRFOnline(r, analysis, spikes(ii,:), r.seed(ii));
          end
          % track analysis
          if isfield(analysis, 'log')
            analysis.log{end+1} = ['getSTRFOnline - run at ' datestr(now)];
          else
            analysis.log{1} = ['getSTRFOnline - run at ' datestr(now)];
          end
        end

      % not really sure why i'm saving these (not really a STS)
      analysis.sum.strf = analysis.strf;
      analysis.sum.spatialRF = analysis.spatialRF;
      % spike triggered average
      analysis.strf = analysis.strf/r.numEpochs;
      analysis.spatialRF = squeeze(mean(analysis.strf, 3));
      end

      % run additional analyses on temporal RF
      [r, analysis] = spatialReverseCorr(r, analysis);

      % NOTE: just testing this out for now, not sure how good it is
      if ~strcmp(r.params.chromaticClass, 'RGB')
        analysis.peaks.on = FastPeakFind(analysis.spatialRF);
        analysis.peaks.off = FastPeakFind(-1 * analysis.spatialRF);
        if ~isempty(analysis.peaks.on)
          fprintf('Found %u on peaks:', length(analysis.peaks.on));
        end
        if ~isempty(analysis.peaks.off)
          fprintf('Found %u off peaks\n', length(analysis.peaks.on));
        end
      else
        analysis.spatialRF = shiftdim(analysis.spatialRF, 1);
      end

    case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
      for ep = 1:r.numEpochs
        r = sMTFanalysis2(r, ep);
      end

      % fit F1 and F2 (on-off) amplitude
      analysis.f1Fit = struct();
      analysis.f1Fit = FTAmpFit(r, analysis.f1amp);
      if strcmp(r.params.temporalClass, 'squarewave')
        analysis.f2Fit = FTAmpFit(r, analysis.f2amp);
      end

      r.log{end+1} = ['sMTFanalysis2 + fits at ' datestr(now)];

    case 'edu.washington.riekelab.manookin.protocols.OrthographicAnnulus'
      analysis.binRate = 60;
      prePts = r.params.preTime * 1e-3 * r.params.sampleRate;
      stimPts = r.params.stimTime * 1e-3 * r.params.sampleRate;
      for ii = 1:r.numEpochs
        switch r.params.recordingType
          case 'extracellular'
            y = r.spikes(ii,:);
          case 'voltage_clamp'
            y = r.analog(ii,:);
        end
      if strcmp(r.params.recordingType, 'extracellular')
        if r.params.sampleRate > analysis.binRate
          y = BinSpikeRate(y(prePts+1:end), analysis.binRate, r.params.sampleRate);
        else
          y = y(prePts+1:end)*r.params.sampleRate;
        end
      else
        y = highPassFilter(y, 0.5, 1/r.params.sampleRate);
        if prePts > 0
          y = y - median(y(1:prePts));
        else
          y = y - median(y);
        end
        y = binData(y(prePts+1:end), analysis.binRate, r.params.sampleRate);
      end
      if ii == 1
        analysis.binnedData = zeros(r.numEpochs, size(y,2));
      end
      analysis.binnedData(ii, :) = y;
    end
    analysis.binAvg = mean(analysis.binnedData, 1);

    case 'edu.washington.riekelab.manookin.protocols.GliderStimulus'
      analysis.binRate = 60;
      prePts = r.params.preTime*1e-3*r.params.sampleRate;
      stimPts = r.params.stimTime*1e-3*r.params.sampleRate;
      for ii = 1:r.numEpochs
        switch r.params.recordingType
        case 'extracellular'
          y = r.spikes(ii, :);
        case 'voltage_clamp'
          y = r.analog(ii, :);
        case 'current_clamp'
          y = r.analog(ii, :);
        end
        if strcmp(r.params.recordingType,'extracellular') || strcmp(r.params.recordingType, 'current_clamp')
          if r.params.sampleRate > analysis.binRate
            y = BinSpikeRate(y(prePts+1:end), analysis.binRate, r.params.sampleRate);
          else
            y = y(prePts+1:end)*r.params.sampleRate;
          end
        else
          % High-pass filter to get rid of drift.
          y = highPassFilter(y, 0.5, 1/r.params.sampleRate);
          if prePts > 0
              y = y - median(y(1:prePts));
          else
              y = y - median(y);
          end
          y = binData(y(prePts+1:end), analysis.binRate, r.params.sampleRate);
        end
        y = y(:)';
        if ii == 1
          analysis.bins = zeros(length(r.params.stimuli), ceil(r.numEpochs/length(r.params.stimuli)), size(y,2));
          analysis.binAvg = zeros(length(r.params.stimuli), size(y,2));
        end
        [ind1, ind2] = ind2sub([length(r.params.stimuli), size(y,2)], ii);
        if ii == 1
          ift = getInstFiringRate(r.resp(ii,:), r.params.sampleRate);
          analysis.instFt = zeros(length(r.params.stimuli), size(y,2), length(ift));
        end
        analysis.instFt(ind1, ind2, :) = getInstFiringRate(r.resp(ii,:), r.params.sampleRate);
        analysis.bins(ind1, ind2, :) = y;
        % for now this will avoid counting zeros when not all stim were run equal times
        analysis.binAvg(ind1, :) = squeeze(mean(analysis.bins(ind1, 1:ind2, :),2));
      end

  end % parse epoch block

  if neuron == 2
    r.secondary.analysis = analysis;
  else
    r.analysis = analysis;
  end

r.log = Log;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function s = FTAmpFit(r, amp)
    yd = abs(amp(:)');
    s.params0 = [max(yd) 200 0.1*max(yd) 400];
    switch r.params.stimulusClass
    case 'spot'
      [s.Kc, s.sigmaC, s.Ks, s.sigmaS] = fitDoGAreaSummation(2*r.params.radii(:)', yd, s.params0);
      s.fit = DoGAreaSummation([s.Kc, s.sigmaC, s.Ks, s.sigmaS], 2*r.params.radii(:)');
      fprintf('Kc = %.2f, sigmaC = %.2f, Ks = %.2f, sigmaS = %.2f\n',...
        s.Kc, s.sigmaC, s.Ks, s.sigmaS);
    case 'annulus'
      s.params = fitAnnulusAreaSum([r.params.radii(:)' 456], yd, s.params0);
      s.fit = annulusAreaSummation(s.params, [r.params.radii(:)' 456]);
      s.sigmaC = s.params(2);
      s.sigmaS = s.params(4);
      fprintf('sigmaC = %.2f, sigmaS = %.2f\n', s.sigmaC, s.sigmaS);
    end
  end

  function instFt = getInstFiringRate(spikes, sampleRate)
    % instantaneous firing rate
    n = size(spikes,1);

    filterSigma = (20/1000)*sampleRate;
    newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);

    instFt = zeros(size(spikes));
    for ii = 1:n
      instFt(ii,:) = sampleRate*conv(spikes(ii,:), newFilt, 'same');
    end
  end

  function r = sMTFanalysis2(r, epochNum)
    binRate = 60;
    if isfield(r.params, 'waitTime')
      prePts = (r.params.preTime + r.params.stimTime) * 1e-3 * r.params.sampleRate;
      stimFrames = (r.params.stimTime - r.params.waitTime) * 1e-3 * binRate;
    else
      prePts = r.params.preTime*1e-3*r.params.sampleRate;
      stimFrames = r.params.stimTime * 1e-3 * binRate;
    end
    if strcmp(r.params.recordingType, 'extracellular')
      y = BinSpikeRate(r.spikes(epochNum, :), binRate, r.params.sampleRate);
    elseif strcmp(r.params.recordingType, 'voltage_clamp')
      y = r.analog(epochNum, :);
      y = binData(y(prePts+1:end), binRate, r.params.sampleRate);
    end

    binSize = binRate/r.params.temporalFrequency;
    numBins = floor(stimFrames/binSize);
    avgCycle = zeros(1, floor(binSize));
    for k = 1:numBins
      index = round((k-1)*binSize)+(1:floor(binSize));
      index(index > length(y)) = [];
      ytmp = y(index);
      avgCycle = avgCycle + ytmp(:)';
    end
    avgCycle = avgCycle / numBins;

    ft = fft(avgCycle);
    analysis.F0(epochNum) = abs(ft(1))/length(avgCycle*2);
    analysis.F1(epochNum) = abs(ft(2))/length(avgCycle*2);
    analysis.F2(epochNum) = abs(ft(3))/length(avgCycle*2);
    analysis.P1(epochNum) = angle(ft(2)) * 180/pi;
    analysis.P2(epochNum) = angle(ft(3)) * 180/pi;

    % save analysis information
    analysis.avgCycle(epochNum,:) = avgCycle;
    if epochNum == 1
      analysis.params.binRate = binRate;
      analysis.params.prePts = prePts;
      analysis.params.stimFrames = stimFrames;
      logstr = sprintf('SMTFanalysis2 - run at %s', datestr(now));
      if isfield(analysis, 'log')
        analysis.log{end+1} = logstr;
      else
        analysis.log{1} = logstr;
      end
    end
  end

  function [f1amp, f1phase, f2amp, f2phase] = CTRanalysis(r, data)
    switch r.params.recordingType
    case 'extracellular'
      responseTrace = data(r.params.preTime/1000 * r.params.sampleRate+1 : end);
    case 'voltage_clamp'
          % Subtract the leak and clip out the pre-time.
      if r.params.preTime > 0
          data(1 : round(r.params.sampleRate*(r.params.preTime-16.7)*1e-3)) = [];
          responseTrace = data;
      end
    end
    binRate = 60;
    binWidth = r.params.sampleRate/binRate;
    numBins = floor(r.params.stimTime/1000 * binRate);
    binnedData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binnedData(k) = mean(responseTrace(index));
    end
    % convert to conductance (nS)
    if strcmp(r.params.recordingType, 'analog')
      if strcmp(r.params.analysisType, 'excitation')
        binnedData = binnedData/-70/1000;
      else
        binnedData = binnedData/70/1000;
      end
    end
    binsPerCycle = binRate / r.params.temporalFrequency;
    numCycles = floor(length(binnedData) / binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));

    for k = 1:numCycles
      index = round((k-1) * binsPerCycle) + (1:floor(binsPerCycle));
      cycleData = cycleData + binnedData(index);
    end
    cycleData = cycleData / k;

    % get the F1 response
    ft = fft(cycleData);
    f1amp = abs(ft(2))/length(ft)*2; f1phase = angle(ft(2)) * 180/pi;
    f2amp = abs(ft(3))/length(ft)*2; f2phase = angle(ft(3)) * 180/pi;
  end

  function result = sMTFanalysis(r, params, resp)
    if nargin < 3
      spikes;
    end
    if nargin < 2
      params = r.params;
    end
    result.params.binRate = 60;
    result.params.allOrAvg = 'avg';
    result.params.discardCycles = [];

    sfNum = length(params.spatialFrequencies);
    result.F1 = zeros(1, sfNum); result.F2 = zeros(1, sfNum);
    result.ph1 = zeros(1, sfNum); result.ph2 = zeros(1, sfNum);

    if isfield(r, 'numEpochs')
      n = r.numEpochs;
    else
      n = length(params.spatialFrequencies);
    end

    for ee = 1:n
      data = spikes(ee,:);

      % Bin the data according to type.
      switch params.recordingType
        case 'extracellular'
          bData = BinSpikeRate(data(params.stimStart:params.stimEnd), result.params.binRate, params.sampleRate);
        otherwise
          bData = binData(data(params.stimStart:params.stimEnd), result.params.binRate, params.sampleRate);
        end

        [f1, p1] = frequencyModulation(bData, result.params.binRate, params.temporalFrequency, result.params.allOrAvg, 1, result.params.discardCycles);
        [f2, p2] = frequencyModulation(bData, result.params.binRate, params.temporalFrequency, result.params.allOrAvg, 2, result.params.discardCycles);

        result.F1(ee) = f1;
        result.F2(ee) = f2;
        result.ph1(ee) = p1;
        result.ph2(ee) = p2;
     end
      result.P1 = result.ph1 * 180/pi;
      result.P2 = result.ph2 * 180/pi;
  end

  function [localFilter, linearFilter] = MTFanalysis(r, analysis, data, seed)

    numBins = floor(r.params.stimTime/1000 * analysis.binRate);
    binSize = r.params.sampleRate / analysis.binRate;
    binData = zeros(1, numBins);

    switch r.params.recordingType
    case 'extracellular'
      data = data(r.params.preTime/1000 * r.params.sampleRate+1:end);
      % bin the data
      for k = 1:numBins
        index = round((k-1) * binSize + 1 : k*binSize);
        binData(k) = sum(data(index)) * analysis.binRate;
      end
    case 'voltage_clamp'
      if r.params.preTime > 0
        data(1 : round(r.params.sampleRate * (r.params.preTime - 16.7) * 1e-3)) = [];
      end

      for m = 1:numBins
        index = round((m-1) * binSize)+1 : round(m*binSize);
        binData(m) = mean(data(index));
      end

      if strcmp(r.params.analysisType, 'excitation')
        binData = binData/-70/1000;
      else
        binData = binData/70/1000;
      end
    end

    % seed random number generator
    noiseStream = RandStream('mt19937ar', 'Seed', seed);

    % get the frame values
    if strcmp(r.params.chromaticClass, 'RGB-gaussian')
      frameValues = r.params.stdev * noiseStream.randn(3, numBins);
    elseif strcmp(r.params.chromaticClass, 'RGB-binary')
      frameValues = noiseStream.randn(3, numBins) > 0.5;
    else
      frameValues = r.params.stdev * noiseStream.randn(1, numBins/analysis.binsPerFrame);
    end

    % Upsample if necessary.
    if analysis.binsPerFrame > 1
        frameValues = ones(analysis.binsPerFrame,1) * frameValues;
        frameValues = frameValues(:)';
    end

    % get rid of the first 0.5 sec
    frameValues(1:round(analysis.binRate/2)) = 0;
    binData(1:round(analysis.binRate/2)) = 0;

    % run reverse correlation
    if isempty(strfind(r.params.chromaticClass, 'RGB'))
      lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
      linearFilter = analysis.linearFilter + lf(1 : analysis.binRate);
      localFilter = lf(1:analysis.binRate);
    else
      lf = zeros(size(analysis.linearFilter));
      for ii = 1:3
        tmp = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([squeeze(frameValues(ii,:)), zeros(1,60)]))));
        lf(ii,:) = tmp(1:floor(r.params.frameRate));
      end
      linearFilter = analysis.linearFilter + lf(:,1:analysis.binRate);
      localFilter = lf(:,1:analysis.binRate);
    end
  end

  function  isOutlier = getOutliers(data, SD)
    isOutlier = zeros(size(data));
    for ii = 1:length(data)
      if data(ii) > (mean(data) + SD*std(data)) || data(ii) < (mean(data) + SD*std(data))
        isOutlier(ii) = 1;
      end
    end
  end

  function stimValues = generateCurrentStim(r, seed)
      gen = edu.washington.riekelab.manookin.stimuli.GaussianNoiseGeneratorV2();

      gen.tailTime = 100;
      gen.preTime = r.params.preTime;
      gen.stimTime = r.params.stimTime;
      gen.stDev = r.params.stdev;
      gen.freqCutoff = r.params.frequencyCutoff;
      gen.numFilters = r.params.numberOfFilters;
      gen.mean = 0;
      gen.seed = seed;
      gen.sampleRate = r.params.sampleRate;
      gen.units = 'pA';

      stim = gen.generate();
      stimValues = stim.getData();
  end

  function [xBin, yBin] = getNL(r, P, R)
      % Sort the data; xaxis = prediction; yaxis = response;
      [a, b] = sort(P(:));
      xSort = a;
      ySort = R(b);

      % Bin the data.
      valsPerBin = floor(length(xSort) / analysis.nonlinearityBins);
      xBin = mean(reshape(xSort(1 : analysis.nonlinearityBins*valsPerBin),valsPerBin,analysis.nonlinearityBins));
      yBin = mean(reshape(ySort(1 : analysis.nonlinearityBins*valsPerBin),valsPerBin,analysis.nonlinearityBins));
  end

end % analyzeDataOnline
