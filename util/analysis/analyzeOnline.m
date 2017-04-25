function r = analyzeOnline(r, varargin)
  % v2 of quick protocol specific data analysis
  % INPUT: r = data structure from parseOnline
  % OPTIONAL = neuron (1)     for dual recordings
  %             bpf (1)       binsPerFrame
  %             binRate (60)  for ChromaticGrating
  %             strfMethods (revCorr)     not sure STA works right now...
  %             useFrameTracker (false)    false for bad frame timing
  % OUTPUT: r = data structure with r.analysis
  %
  % 28Jan2016 - everything runs thru this function now


  ip = inputParser();
  ip.addParameter('neuron', 1, @(x)isvector(x));
  ip.addParameter('bpf', 1, @(x)isvector(x));
  ip.addParameter('binRate', 60, @(x)isvector(x));
  ip.addParameter('strfMethod', 'revCorr', @(x)ischar(x));
  ip.addParameter('useFrameTracker', false, @(x)islogical(x));
  ip.parse(varargin{:});
  neuron = ip.Results.neuron;
  binsPerFrame = ip.Results.bpf;
  binRate = ip.Results.binRate;
  strfMethod = ip.Results.strfMethod;
  useFrameTracker = ip.Results.useFrameTracker;

  r = makeCompatible(r, true);

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
  else
    % analysis = r.analysis;
    if ~strcmp(r.params.recordingType, 'voltage_clamp')
      spikes = r.spikes;
    end
  end
  Log = r.log;

  % protocol specific analysis
  switch r.protocol
    case 'edu.washington.riekelab.sara.protocols.FullChromaticGrating'
      f = fieldnames(r);
      ind = find(not(cellfun('isempty', strfind(f, 'deg'))));
      analysis.F1 = zeros(length(ind), length(unique(r.params.spatialFrequencies)));
      analysis.P1 = analysis.F1;
      deg = char(f{ind(1)});

      % get all the fft data
      if strcmp(r.params.recordingType, 'extracellular') || strcmp(ICmode, 'spikes')
        analysis = sMTFanalysis(r, r.spikes);
      else
        analysis = sMTFanalysis(r, r.analog);
      end

      % distribute data to each orientation
      if r.numEpochs >= r.params.spatialFreqs
        res = {'F0', 'F1', 'P1', 'F2', 'P2'};
        for ii = 1:length(res)
          % if analysis.(res{ii}) > r.numEpochs
          %   analysis.(res{ii})(1, r.numEpochs+1:end) = [];
          % end
          analysis.(res{ii}) = reshape(analysis.(res{ii}), [length(unique(r.params.spatialFrequencies)) length(r.params.orientations)]);
           analysis.(res{ii}) = analysis.(res{ii})';
          for jj = 1:length(r.params.orientations)
            deg = sprintf('deg%u', r.params.orientations(jj));
            analysis.(deg).(res{ii}) = analysis.(res{ii})(jj,:);
          end
        end
      end

      Log{end+1} = ['sMTFanalysis for ' length(ind) ' orientations at ' datestr(now)];

    case {'edu.washington.riekelab.sara.protocols.TempChromaticGrating', 'edu.washington.riekelab.manookin.protocols.ChromaticGrating'}
      analysis = sMTFanalysis(r, r.spikes);
      analysis.bins = (analysis.bins)';
      Log{end+1} = ['sMTFanalysis at ' datestr(now)];

    case {'edu.washington.riekelab.sara.protocols.ConeTestGrating'}
      analysis = sMTFanalysis(r, r.spikes, r.params.orientations);
      coneOrnt = reshape(analysis.F1, 4, length(r.params.orientations));
      % analysis.bins = (analysis.bins)';
      Log{end+1} = ['sMTFanalysis at ' datestr(now)];

    case {'edu.washington.riekelab.manookin.protocols.LMIsoSearch'}
      if isfield(r.params, 'temporalFrequency')
        for ep = 1:r.numEpochs
          r = CTRanalysis(r, ep);
        end

        cdata = cycleData(r);
        for ii = 1:40
          r.analysis.phaseOne(ii) = sum(cdata.ypts(ii,1:length(cdata.ypts)/2));
          r.analysis.phaseTwo(ii) = sum(cdata.ypts(ii,length(cdata.ypts)/2 + 1:end));
        end

      else
        analysis.spikeNum = zeros(length(unique(r.params.searchValues)), 3);
        tmp = squeeze(mean(r.spikeBlock,2));

        for ii = 1:length(unique(r.params.searchValues))
          analysis.spikeNum(ii,:) = [nnz(tmp(ii, 1:r.params.preTime*10)),... 
          nnz(tmp(ii,r.params.preTime*10+1:(r.params.preTime+r.params.stimTime)*10)),... 
          nnz(tmp(ii,10*(r.params.preTime+r.params.stimTime)+1:end))];
        end
      end

    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      if strcmp(r.params.recordingType, 'extracellular')
        r.instFt = zeros(size(r.respBlock));
      end

            switch r.params.recordingType
            case 'extracellular'
              for ep = 1:r.numEpochs
                [stim, trial] = ind2sub([length(r.params.stimClass) size(r.respBlock,2)], ep);
                r = CTRanalysis(r, ep)
                r.instFt(stim, trial, :) = getInstFiringRate(r.spikes(ep,:), r.params.sampleRate);
              end
              r.ptsh.binSize = 200; % remove this all later
              for sss = 1:length(r.params.stimClass)
                r.ptsh.(r.params.stimClass(sss)) = getPTSH(r, squeeze(r.spikeBlock(sss,:,:)), 200);
              end
              Log{end+1} = ['instFt vs PTSH calc at ' datestr(now)];
            case 'voltage_clamp'
              for ep = 1:r.numEpochs
                [stim, trial] = ind2sub([length(r.params.stimClass) size(r.respBlock,2)], ep);
                r.analogBlock(stim, trial, :) = r.analog(ep,:);
                r = CTRanalysis(r,ep);
              end
              for sss = 1:length(r.params.stimClass)
                r.avgResp.(r.params.stimClass(sss)) = mean(squeeze(r.analogBlock(sss,:,:)));
              end
            end

            rs = {'F0', 'F1', 'F2', 'P1', 'P2'};
            for ii = 1:length(rs)
              analysis.(rs{ii}) = reshape(analysis.(rs{ii}), [length(r.params.stimClass) size(r.respBlock, 2)]);
            end

            Log{end+1} = ['CTRanalysis at ' datestr(now)];

    case {'edu.washington.riekelab.sara.protocols.ColorExchange', 'edu.washington.riekelab.sara.protocols.ColorCircle'}
      for ep = 1:r.numEpochs
        r = CTRanalysis(r, ep);
      end
      Log{end+1} = [datestr(now) ' - CTRanalysis'];

    case 'edu.washington.riekelab.manookin.protocols.MovingBar'
      if strcmp(r.params.recordingType, 'extracellular')
        for ep = 1:r.numEpochs
          o = find(r.params.orientations == r.params.orientation(1,ep));
          r.instFt(o, ceil(ep/length(r.params.orientations)),:) = getInstFiringRate(r.spikes(ep,:), r.params.sampleRate);
        end
      end

    case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'

      for ep = 1:r.numEpochs
        r = CTRanalysis(r, ep);
      end

      xaxis = unique(r.params.contrasts);
      for xpt = 1:length(xaxis)
        numReps = find(r.params.contrasts == xaxis(xpt));
        analysis.avgF1(xpt) = mean(analysis.F1(numReps));
        analysis.avgP1(xpt) = mean(analysis.P1(numReps));
        analysis.avgF2(xpt) = mean(analysis.F2(numReps));
        analysis.avgP2(xpt) = mean(analysis.P2(numReps));
     end

    case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
       r.params.ledWeights = zeros(2*length(r.params.searchValues), 3);

       for ep = 1:2*length(r.params.searchValues)
         r = CTRanalysis(r, ep);
       end

       ap={'F0', 'F1', 'F2', 'P1', 'P2'}; % analysis params returned
       for ii = 1:length(ap)
         analysis.(sprintf('green%s', ap{ii})) = analysis.(ap{ii})(1:length(r.params.searchValues));
         analysis.(sprintf('red%s', ap{ii})) = analysis.(ap{ii})(length(r.params.searchValues)+1:end);
       end

       analysis.greenMin = r.params.searchValues(find(analysis.greenF1 == min(analysis.greenF1), 1));
       fprintf('greenMin is %.3f\n', analysis.greenMin);

       analysis.redMin = r.params.searchValues(find(analysis.redF1 == min(analysis.redF1)));
       fprintf('redMin is %.3f\n', analysis.redMin);

       for ii = 1:length(r.params.searchValues)
         r.params.ledWeights(ii,:) = [1 r.params.searchValues(ii) 0];
         r.params.ledWeights(ii+length(r.params.searchValues),:) = [r.params.searchValues(ii) analysis.greenMin 0];
       end

    case {'edu.washington.riekelab.sara.protocols.IsoSTA', 'edu.washington.riekelab.manookin.protocols.GaussianNoise'}

      analysis.binsPerFrame = binsPerFrame;
      analysis.binRate = r.params.frameRate * analysis.binsPerFrame;
      r.allResponses = [];
      r.stim.stimuli = [];
      analysis.linearFilter = zeros(1, analysis.binRate);
      analysis.lf = zeros(r.numEpochs, analysis.binRate);
      switch r.params.recordingType
      case 'extracellular'
        for ep = 1:r.numEpochs
          if useFrameTracker
            preFrames = r.params.frameRate * (r.params.preTime/1000);
            firstStimFrameFlip = r.stim.frameTimes(preFrames+1);
            stimFrames = round(r.params.frameRate * (r.params.stimTime/1e3));
            newResponse = r.spikes(ep,firstStimFrameFlip:end);
            filterLen = 800;
            freqCutoffFraction = 1;
            allStimuli = cat(1, allStimuli, noise);
            allResponses = cat(1, allResponses, response);

            updateRate = (r.params.frameRate/r.params.frameDwell);
            newFilter = getLinearFilterOnline(allStimuli, allResponses, updateRate, freqCutoffFraction * updateRate);

            filterPts = (filterLen/1000) * updateRate;
            filterTimes = linspace(0, filterLen, filterPts);
            newFilter = newFilter(1:filterPts);
            if ep == r.numEpochs
              analysis.linearFilter = newFilter;
              analysis.allStimuli = allStimuli;
              analysis.allResponses = allResponses;
            end
          else
            analysis.binRate = binRate * binsPerFrame;
            if iscell(r.params.seed) % TODO: clean
              [analysis.lf(ep,:), analysis.linearFilter, r.stim.stimuli, r.allResponses] = MTFanalysis(r, analysis, spikes(ep,:), r.params.seed{ep});
            else
              [analysis.lf(ep,:), analysis.linearFilter, r.stim.stimuli, r.allResponses] = MTFanalysis(r, analysis, spikes(ep,:), r.params.seed(1,ep));
            end
            if ep == r.numEpochs
              analysis.linearFilter = analysis.linearFilter/r.numEpochs;
            end
          end
        end
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

      % whiten
      analysis.freqCutoffFraction = 1;
      analysis.updateRate = (r.params.frameRate/r.params.frameDwell);
      analysis.whiteFilter = getLinearFilterOnline(r.stim.stimuli, r.allResponses, analysis.updateRate, analysis.freqCutoffFraction * analysis.updateRate);


      analysis.stdev = std(analysis.linearFilter);

      analysis.SNR = max(abs(analysis.linearFilter))/std(analysis.linearFilter);

      % temporal properties
      filterDuration = 1; % sec
      if abs(min(analysis.linearFilter)) > max(analysis.linearFilter)
        analysis.filterSign = -1;
        analysis.peakTime = find(analysis.linearFilter == min(analysis.linearFilter),1)/length(analysis.linearFilter)*1000*filterDuration;

        t = (analysis.linearFilter > 0);
        t(1:find(analysis.linearFilter == min(analysis.linearFilter), 1))=0;
        t = find(t==1,1);
        if ~isempty(t)
          analysis.zeroCross = t/length(analysis.linearFilter)*1000*filterDuration;
        end
      else
        analysis.filterSign = 1;
        analysis.peakTime = find(analysis.linearFilter == max(analysis.linearFilter), 1) / length(analysis.linearFilter) * 1000 * filterDuration;

        t = (analysis.linearFilter < 0);
        t(1:find(analysis.linearFilter == max(analysis.linearFilter), 1)) = 0;
        t = find(t==1,1);
        if ~isempty(t)
          analysis.zeroCross = t/length(analysis.linearFilter) * 1000 * filterDuration;
        end
      end
      analysis.biphasicIndex = abs(min(analysis.linearFilter)/max(analysis.linearFilter));

      % peak times from mike's code are off - method 2:
      [loc, pk] = peakfinder(analysis.linearFilter, [], [], analysis.filterSign);
      [~, ind] = max(abs(pk));
      analysis.xpts = linspace(0, 1000,analysis.binRate);
      analysis.peakTime = analysis.xpts(loc(ind));

      % normalize by the standard deviation
      analysis.linearFilter = analysis.linearFilter/std(analysis.linearFilter);

      % take the mean
      analysis.tempFT = abs(fft(analysis.linearFilter));

      % get the nonlinearity
      analysis.NL = nonlinearity(r);

      fprintf('time to peak = %.2f\n zero cross = %.2f\n biphasic index = %.2f\n', analysis.peakTime, analysis.zeroCross, analysis.biphasicIndex);

      Log{end+1} = ['MTFanalysis at ' datestr(now)];
      Log{end+1} = ['nonlinearity at ' datestr(now)];

    case {'edu.washington.riekelab.protocols.Pulse',...
        'edu.washington.riekelab.manookin.protocols.ResistanceAndCapacitance'}
      try
        analysis = biophys(r, r.resp, r.params.pulseAmplitude);
      catch
        r.log{end+1} = 'SLU comp: did not run biophys';
      end

      outputStr = {['Rin = ' num2str(mean(r.oa.rInput)) ' MOhm']; ...
        ['Rs = ' num2str(mean(r.oa.rSeries)) ' MOhm']; ...
        ['Rm = ' num2str(mean(r.oa.rMembrane)) ' MOhm']; ...
        ['Rtau = ' num2str(mean(r.oa.rTau)) ' MOhm']; ...
        ['Cm = ' num2str(mean(r.oa.capacitance)) ' pF']; ...
        ['tau = ' num2str(mean(r.oa.tau_msec)) ' ms']};
      fprintf('%s\n', outputStr{:});

    case {'edu.washington.riekelab.manookin.protocols.SpatialNoise',...
      'edu.washington.riekelab.manookin.protocols.TernaryNoise',...
      'edu.washington.riekelab.sara.protocols.SpatialReceptiveField'}
      r.epochCount = 0;

      % update to match binsPerFrame changes
      r.params.numFrames = floor(r.params.stimTime/1000 * r.params.frameRate) / r.params.frameDwell;
      r.params.preF = floor(r.params.preTime/1000 * r.params.frameRate * binsPerFrame);
      r.params.stimF = floor(r.params.stimTime/1000 * r.params.frameRate * binsPerFrame);

      analysis.binsPerFrame = binsPerFrame;

      analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * analysis.binsPerFrame * 0.5/r.params.frameDwell));
      analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);

      % x/y axes in microns
      r.params.xaxis = linspace(-r.params.numXChecks/2, r.params.numXChecks/2, r.params.numXChecks) * pix2micron(r.params.stixelSize, r);
      r.params.yaxis = linspace(-r.params.numYChecks/2, r.params.numYChecks/2, r.params.numYChecks) * pix2micron(r.params.stixelSize,r);

      switch strfMethod
      case 'revCorr'
        for ii = 1:r.numEpochs
          r.epochCount = r.epochCount + 1;
          if strcmp(r.params.chromaticClass, 'RGB')
            analysis.strf = zeros(3,r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * analysis.binsPerFrame * 0.5/r.params.frameDwell));
            analysis.spatialRF = zeros(3,r.params.numYChecks, r.params.numXChecks);
            if isfield(r, 'ICspikes')
              [r, analysis] = getSTRFOnline(r, analysis, r.ICspikes(ii,:), r.seed(ii));
            else
              [r, analysis] = getSTRFOnline(r, analysis, spikes(ii,:), r.seed(ii));
            end
          else
            [r, analysis] = getSTRFOnline(r, analysis, spikes(ii,:), r.seed(ii));
          end
          % track analysis
          Log{end+1} = ['getSTRFOnline - run at ' datestr(now)];
        end

        % not really sure why i'm saving these (not really a STS)
        analysis.sum.strf = analysis.strf;
        analysis.sum.spatialRF = analysis.spatialRF;

        analysis.stdev1 = std(analysis.strf(:));

        % run additional analyses on temporal RF
        [r, analysis] = spatialReverseCorr(r, analysis);

        analysis.strf = analysis.strf/std(analysis.strf(:));
        analysis.spatialRF = squeeze(mean(analysis.strf, 3));
      end

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

    case 'edu.washington.riekelab.manookin.protocols.MovingBar'
      prePts = r.params.preTime*1e-3*r.params.sampleRate;
      stimPts = r.params.stimTime*1e-3*r.params.sampleRate;
      analysis.DI = zeros(1,size(r.spikeBlock,1));
      for ii = 1:size(r.spikeBlock, 1)
        analysis.DI(ii) = mean(squeeze(sum(r.spikeBlock(ii, :, prePts : prePts+stimPts))));
      end

    case {'edu.washington.riekelab.sara.protocols.sMTFspot',...
            'edu.washington.riekelab.manookin.protocols.sMTFspot'}
      for ep = 1:r.numEpochs
        r = CTRanalysis(r, ep);
      end

      % fit F1 and F2 (on-off) amplitude
      analysis.f1Fit = struct();
      analysis.f1Fit = FTAmpFit(r, analysis.F1);
      if strcmp(r.params.temporalClass, 'squarewave')
        fprintf('FROM F2 AMP:\n');
        analysis.f2Fit = FTAmpFit(r, analysis.F2);
      end
      switch r.params.stimulusClass
        case 'spot'
          analysis.f1Fit.params = [analysis.f1Fit.Kc analysis.f1Fit.sigmaC analysis.f1Fit.Ks analysis.f1Fit.sigmaS];
        case 'annulus'
          analysis.f1Fit.params = [analysis.f1Fit.sigmaC analysis.f1Fit.sigmaS];
      end

      Log{end+1} = ['CTRanalysis + fits at ' datestr(now)];

    case {'edu.washington.riekelab.manookin.protocols.BarCentering',... 
            'edu.washington.riekelab.sara.protocols.BarCentering'}
      for ep = 1:r.numEpochs
        r = CTRanalysis(r, ep);
      end
      Log{end+1} = ['CTRanalysis at ' datestr(now)];
  end

  % save to structure
  if neuron == 2
    r.secondary.analysis = analysis;
  else
    try
      r.analysis = analysis;
    catch
      fprintf('no analysis field detected\n');
    end
  end
  r.log = Log;


%% SUPPORT FUNCTIONS

    function cw = getConeWeights(r)
      % cw.f1 = getConeF1(r, true);
      % if strcmp(r.params.recordingType, 'extracellular')
      %   cw.ft = getConeFt(r);
      % end
    end

    function s = FTAmpFit(r, amp)
      yd = abs(amp(:)');
      s.params0 = [max(yd) 200 0.1*max(yd) 400];
      switch r.params.stimulusClass
      case 'spot'
        [s.Kc, s.sigmaC, s.Ks, s.sigmaS] = fitDoGAreaSummation(2*r.params.radii(:)', yd, s.params0);
        s.fit = DoGAreaSummation([s.Kc, s.sigmaC, s.Ks, s.sigmaS], 2*r.params.radii(:)');
        fprintf('fcn1 --> Kc = %.2f, sigmaC = %.2f, Ks = %.2f, sigmaS = %.2f\n',...
          s.Kc, pix2micron(s.sigmaC,10), s.Ks, pix2micron(s.sigmaS,10));
        [s.offset.params s.offset.fit] = fitOffsetDoG(r.params.radii, yd, [s.params0 0], true);
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

    function r = CTRanalysis(r, epochNum)
      if r.params.temporalFrequency > 20
        binRate = 120;
        fprintf('%u hz - binRate to %u', r.params.temporalFrequency, binRate);
      else
        binRate = 60;
      end
      if isfield(r.params, 'waitTime')
        prePts = (r.params.preTime + r.params.waitTime) * 1e-3 * r.params.sampleRate;
        stimFrames = (r.params.stimTime - r.params.waitTime) * 1e-3 * binRate;
      else
        prePts = r.params.preTime*1e-3*r.params.sampleRate;
        stimFrames = r.params.stimTime * 1e-3 * binRate;
      end
      if strcmp(r.params.recordingType, 'extracellular')
        y = BinSpikeRate(r.spikes(epochNum, prePts+1:end), binRate, r.params.sampleRate);
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
      end
    end

    function result = sMTFanalysis(r, resp, xvals)

      if nargin < 3
        xvals = r.params.spatialFrequencies;
      end

      result.params.binRate = 60;
      result.params.allOrAvg = 'avg';
      result.params.discardCycles = [];

      if ~isfield(r.params, 'waitTime')
        stimStart = r.params.preTime*10 + 1;
      else
        stimStart = (r.params.preTime + r.params.waitTime)*10 + 1;
      end

      stimEnd = (r.params.preTime + r.params.stimTime) * 10;

      xNum = length(xvals);
      if isfield(r, 'omitEpochs')
        xNum = xNum - length(r.omitEpochs);
      end
      result.F0 = zeros(1, xNum); result.ph0 = zeros(1, xNum);
      result.F1 = zeros(1, xNum); result.F2 = zeros(1, xNum);
      result.ph1 = zeros(1, xNum); result.ph2 = zeros(1, xNum);

      if isfield(r, 'numEpochs')
        n = r.numEpochs;
      else
        n = length(xvals);
      end
      result.bins = [];

      for ee = 1:n
        data = resp(ee,:);

        % Bin the data according to type.
        switch r.params.recordingType
          case {'current_clamp','extracellular'}
            bData = BinSpikeRate(data(stimStart:stimEnd), result.params.binRate, r.params.sampleRate);
          otherwise
            bData = binData(data(stimStart:stimEnd), result.params.binRate, r.params.sampleRate);
        end

          [f0, p0] = frequencyModulation(bData, result.params.binRate, r.params.temporalFrequency, result.params.allOrAvg, 0, result.params.discardCycles);
          [f1, p1] = frequencyModulation(bData, result.params.binRate, r.params.temporalFrequency, result.params.allOrAvg, 1, result.params.discardCycles);
          [f2, p2] = frequencyModulation(bData, result.params.binRate, r.params.temporalFrequency, result.params.allOrAvg, 2, result.params.discardCycles);

          result.F0(ee) = f0;
          result.F1(ee) = f1;
          result.F2(ee) = f2;
          results.ph0(ee) = p0;
          result.ph1(ee) = p1;
          result.ph2(ee) = p2;
          result.bins = [bData, result.bins];
       end
        result.P0 = result.ph0 * 180/pi;
        result.P1 = result.ph1 * 180/pi;
        result.P2 = result.ph2 * 180/pi;
    end

    function [localFilter, linearFilter, allStim, allResponses] = MTFanalysis(r, analysis, data, seed)

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

      allStim = cat(1, r.stim.stimuli, frameValues);
      allResponses = cat(1, r.allResponses, binData);

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
        if isempty(analysis.linearFilter)
          linearFilter = lf(:,1:analysis.binRate);
        end
        linearFilter = analysis.linearFilter + lf(:,1:analysis.binRate);
        localFilter = lf(:,1:analysis.binRate);
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
end
