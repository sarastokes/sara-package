function r = analyzeDataOnline(r, varargin)
  % INPUT = r,
  % optional 2nd input to specify secondary neuron or binsPerFrame

  % 5Oct2016 - added 2nd neuron option
  % 11Nov2016 - using analysisType and recordingType now rather than onlineAnalysis & assuming extracellular (lines 26-33 should keep things compatible)
  % 5Dec2016 - lots of changes, added some of mike's stimuli, most significant: now saving time of analysis

  ip = inputParser();
  ip.addParameter('neuron', 1, @(x)isvector(x));
  ip.addParameter('binsPerFrame', 1, @(x)isvector(x));
  ip.parse(varargin{:});
  neuron = ip.Results.neuron;
  binsPerFrame = ip.Results.binsPerFrame;

  % doubt i'll need paired WC analysis anytime soon...
  if neuron == 1 && isfield(r, 'spikes')
    spikes = r.spikes;
    %analysis = r.analysis;
  elseif neuron == 2
    if ~isfield(r, 'secondary')
      error('Second neuron not found');
    else
      spikes = r.secondary.spikes;
      r.primaryAnalysis = r.analysis;
      %analysis = r.secondary.analysis;
      fprintf('Analyzed with second neuron\n');
    end
  end

  % if neuron doesn't have analysisType and recordingType yet, it was most likely extracellular
  if ~isfield(r.params, 'recordingType')
    r.params.recordingType = 'extracellular';
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
    case {'edu.washington.riekelab.manookin.protocols.ChromaticGrating',  'edu.washington.riekelab.sara.protocols.TempChromaticGrating'}
      r.analysis = sMTFanalysis(r);

    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      r.analysis.f1amp = zeros(length(r.params.stimClass), r.numEpochs/length(r.params.stimClass));
      r.analysis.f1phase = zeros(length(r.params.stimClass), r.numEpochs/length(r.params.stimClass));
      r.params.plotColors = zeros(length(r.params.stimClass), 3);

      r.respBlock = zeros(length(r.params.stimClass), (r.numEpochs/length(r.params.stimClass)), length(r.resp));
      r.instFt = zeros(size(r.respBlock));

      for ep = 1:r.numEpochs
        stim = rem(ep, length(r.params.stimClass));
        if stim == 0
          stim = length(r.params.stimClass);
        end
        trial = ceil(ep / length(r.params.stimClass));
        if strcmp(r.params.recordingType, 'extracellular')
          r.respBlock(stim, trial, :) = spikes(ep,:);
          [r.analysis.f1amp(stim,trial), r.analysis.f1phase(stim,trial), ~, ~] = CTRanalysis(r, spikes(ep,:));
          r.ptsh.binSize = 200;
            r.instFt(stim, trial, :) = getInstFiringRate(spikes(ep,:), r.params.sampleRate);
          if ep == r.numEpochs
%            for stim = 1:length(r.params.stimClass) % TODO: this shouldn't be here right?
%              r.ptsh.(r.params.stimClass(stim)) = getPTSH(r, squeeze(r.respBlock(stim,:,:)), 200);
%            end
          end
        else % voltage_clamp
          r.respBlock(stim, trial, :) = r.analog(ep,:);
          [r.analysis.f1amp(stim,trial), r.analysis.f1phase(stim,trial), ~, ~] = CTRanalysis(r, r.analog(ep,:));
          if ep == r.numEpochs
            for sss = 1:length(r.params.stimClass)
              r.avgResp.(r.params.stimClass(stim)) = mean(squeeze(respBlock(sss,:,:)));
            end
          end
        end
      end

    case 'edu.washington.riekelab.sara.protocols.IsoSTC'
      switch r.params.paradigmClass
        case 'STA'
          if isempty(strfind(r.params.chromaticClass, 'RGB'))
            c = 1;
          else
            c = 3;
          end
          r.analysis.lf = zeros(r.numEpochs, c, 60);
          r.analysis.linearFilter = zeros(c, 60);
          for ep = 1:r.numEpochs
            if isempty(strfind(r.params.chromaticClass,'RGB'))
              [r.analysis.lf(ep,:), r.analysis.linearFilter] = MTFanalysis(r, spikes(ep,:), r.params.seed{ep});
            else
              [r.analysis.lf(ep,:,:), r.analysis.linearFilter] = MTFanalysis(r, spikes(ep,:), r.params.seed{ep});
            end
          end
          r.analysis.linearFilter = r.analysis.linearFilter/r.numEpochs;
        case 'ID'
          switch r.params.recordingType
          case 'extracellular'
            for ep = 1:r.numEpochs
              [r.analysis.f1amp(ep), r.analysis.f1phase(ep), ~, ~] = CTRanalysis(r, spikes(ep,:));
            end
            r.analysis.ptshBin = 200;
            r.analysis.ptsh = getPTSH(r, spikes, 200);
          case 'voltage_clamp'
            for ep = 1:r.numEpochs
              [r.analysis.f1amp(ep), r.analysis.f1phase(ep), ~, ~] = CTRanalysis(r, r.analog(ep,:));
            end
            r.analysis.avgResp = mean(r.analog);
          end
          if r.numEpochs > 1
            r.analysis.meanAmp = mean(r.analysis.f1amp(ep));
            r.analysis.meanPhase = mean(r.analysis.f1phase(ep));
          else
            r.analysis.meanAmp = r.analysis.f1amp;
            r.analysis.meanPhase = r.analysis.f1phase;
          end
        end

    case 'edu.washington.riekelab.manookin.protocols.BarCentering'
      for ep = 1:r.numEpochs
        [r.analysis.f1amp(ep), r.analysis.f1phase(ep), r.analysis.f2amp(ep), r.analysis.f2phase(ep)] = CTRanalysis(r, spikes(ep,:));
      end

    case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'
      r.analysis.f1amp = zeros(1, length(r.numEpochs));
      r.analysis.f1phase = zeros(size(r.analysis.f1amp));
      r.analysis.f2amp = zeros(size(r.analysis.f1amp));
      r.analysis.f2phase = zeros(size(r.analysis.f1phase));
      r.analysis.xaxis = unique(r.params.contrasts);
      r.analysis.mean_f1amp = zeros(size(r.analysis.xaxis));

      for ep = 1:r.numEpochs
        [r.analysis.f1amp(ep), r.analysis.f1phase(ep), r.analysis.f2amp(ep), r.analysis.f2phase(ep)] = CTRanalysis(r, spikes(ep,:));
      end

      for xpt = 1:length(r.analysis.xaxis)
  	     numReps = find(r.params.contrasts == r.analysis.xaxis(xpt));
  	     r.analysis.mean_f1amp(xpt) = mean(r.analysis.f1amp(numReps));
         r.analysis.mean_f1phase(xpt) = mean(r.analysis.f1phase(numReps));
         r.analysis.mean_f2amp(xpt) = mean(r.analysis.f2amp(numReps));
         r.analysis.mean_f2phase(xpt) = mean(r.analysis.f2phase(numReps));
      end

    case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
      r.analysis.greenF1 = zeros(1, length(r.params.searchValues));
      r.analysis.greenP1 = zeros(size(r.analysis.greenF1));
      r.analysis.greenF2 = zeros(size(r.analysis.greenF1));
      r.analysis.greenP2 = zeros(size(r.analysis.greenF1));
      r.analysis.redF1 = r.analysis.greenF1; r.analysis.redF2 = r.analysis.greenF1;
      r.analysis.redP1 = r.analysis.greenF1; r.analysis.redP2 = r.analysis.greenF1;
      r.params.ledWeights = zeros(2*length(r.params.searchValues), 3);

      for ep = 1:2*length(r.params.searchValues)
        if ep > length(r.params.searchValues)
          % search axis = red
          index = ep - length(r.params.searchValues);
          % [r.params.searchValues(index) r.analysis.greenMin 1]
          [r.analysis.redF1(index), r.analysis.redP1(index), r.analysis.redF2(index), r.analysis.redP2(index)] = CTRanalysis(r, spikes(ep,:));
          % r.params.ledWeights(ep,:) = [(r.params.searchValues(index)) (r.analysis.greenMin) 1];
        elseif ep == length(r.params.searchValues)
          % last green axis trial
          r.params.ledWeights(ep,:) = [0 r.params.searchValues(ep) 1];
          [r.analysis.greenF1(ep), r.analysis.greenP1(ep), r.analysis.greenF2(ep), r.analysis.greenP2(ep)] = CTRanalysis(r, spikes(ep,:));
          % now get the green min (TODO: something like gradient descent)
          r.analysis.greenMin = r.params.searchValues(find(r.analysis.greenF1==min(r.analysis.greenF1), 1));
          fprintf('greenMin is %.3f\n', r.analysis.greenMin);
        elseif ep < length(r.params.searchValues)
          % search axis = green
          r.params.ledWeights(ep,:) = [0 r.params.searchValues(ep) 1];
          [r.analysis.greenF1(ep), r.analysis.greenP1(ep), r.analysis.greenF2(ep), r.analysis.greenP2(ep)] = CTRanalysis(r, spikes(ep,:));
        end
      end
      % get the red min too
      r.analysis.redMin = r.params.searchValues(find(r.analysis.redF1==min(r.analysis.redF1)));
      fprintf('redMin is %.3f\n', r.analysis.redMin);

    case 'edu.washington.riekelab.manookin.protocols.GaussianNoise'
      r.analysis.binsPerFrame = binsPerFrame; % default is 1
      r.analysis.binRate = 60 * r.analysis.binsPerFrame;
      r.analysis.linearFilter = zeros(1, r.analysis.binRate);
      r.analysis.lf = zeros(r.numEpochs, r.analysis.binRate);

      switch r.params.recordingType
      case 'extracellular'
        for ep = 1:r.numEpochs
          [r.analysis.lf(ep,:), r.analysis.linearFilter] = MTFanalysis(r, spikes(ep,:), r.params.seed(1,ep));
        end
        r.analysis.linearFilter = r.analysis.linearFilter/r.numEpochs;
      case 'voltage_clamp'
        for ep = 1:r.numEpochs
          [r.analysis.lf(ep,:), r.analysis.linearFilter] = MTFanalysis(r, r.analog(ep,:), r.params.seed(1,ep));
          r.analysis.linearFilter = r.analysis.linearFilter/r.numEpochs;
          if r.analysis.binsPerFrame == 6
            r.analysis.linearFilter = r.analysis.linearFilter - r.analysis.linearFilter(3);
            r.analysis.linearFilter(1:3) = 0;
          end
        end
      end
      r.analysis.linearFilter = r.analysis.linearFilter/std(r.analysis.linearFilter);

      % take the mean
      r.analysis.tempFT = abs(fft(r.analysis.linearFilter));

      % get the nonlinearity
      r = nonlinearity(r);

    case {'edu.washington.riekelab.protocols.Pulse', 'edu.washington.riekelab.manookin.protocols.ResistanceAndCapacitance'}
      r.analysis = pulseAnalysis(r, r.resp, r.params.pulseAmplitude);

    case {'edu.washington.riekelab.protocols.PulseFamily'}
      for ii = 1:length(r.params.pulses)
        result = biophys(r, squeeze(r.respBlock(ii,:,:)), r.params.pulses(ii));
        r.analysis.charge(ii) = result.charge;
        r.analysis.current0(ii) = result.charge;
        r.analysis.currentSS(ii) = result.currentSS;
        r.analysis.rMem(ii) = result.rInput - result.rSeries;
        r.analysis.rSeries(ii) = result.rSeries;
        r.analysis.rInput(ii) = result.rInput;
        r.analysis.capacitance(ii) = result.capacitance;
        r.analysis.tauCharge(ii) = result.tauCharge;
        % calcs
        r.analysis.rTau(ii) = r.analysis.tauCharge(ii)/(r.analysis.capacitance(ii)* 1e-12)/1e9;
      end

      % clean all this up later.. just trying to see it work for now
      props = fieldnames(r.analysis);
      for ii = 1:length(props)
        outlier = getOutliers(r.analysis.(props{ii}), 5);
        ind = nonzeros(outlier);
        if ~isempty(ind) && ~isempty(find(ind == 0)) % all 1s is trouble
          r.analysis.(props{ii})(ind) = [];
          fprintf('found %u outliers in %s\n', ind, props{ii});
        end
      end

      outputStr = {['Rin = ' num2str(mean(r.analysis.rInput)) ' MOhm']; ...
          ['Rs = ' num2str(mean(r.analysis.rSeries)) ' MOhm']; ...
          ['Rm = ' num2str(mean(r.analysis.rMem)) ' MOhm']; ...
          ['Rtau = ' num2str(mean(r.analysis.rTau)) ' MOhm']; ...
          ['Cm = ' num2str(mean(r.analysis.capacitance)) ' pF']; ...
          ['tau = ' num2str(mean(r.analysis.tauCharge)) ' ms']};
      outputStr % to the cmd line

    case 'edu.washington.riekelab.manookin.protocols.InjectNoise'
      r.analysis.linearFilter = [];
      r.analysis.xaxis = []; 
      r.analysis.yaxis = [];
      r.analysis.nonlinearityBins = 200;
      for ii = 1:r.numEpochs
        % starting with just spikes
        y = r.ICspikes(ii,:);

        binRate = 480; %TODO: check on this
        r.analysis.binRate = binRate;

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
        r.analysis.plotLngth = round(binRate*0.025);

        % Make it the same size as the stim frames.
        y = y(1 : length(frameValues));

        % Zero out the first half-second while cell is adapting to
        % stimulus.
        y(1 : floor(binRate/2)) = 0;
        frameValues(1 : floor(binRate/2)) = 0;

        % Reverse correlation.
        lf = real(ifft( fft([y(:)' zeros(1,100)]) .* conj(fft([frameValues(:)' zeros(1,100)])) ));

        if isempty(r.analysis.linearFilter)
            r.analysis.linearFilter = lf;
        else
            r.analysis.linearFilter = (r.analysis.linearFilter*(ii-1) + lf)/ii;
        end
        % Re-bin the response for the nonlinearity.
        resp = binData(y, 60, binRate);
        if isempty(r.analysis.yaxis)
          r.analysis.yaxis = resp(:)';
        else
          r.analysis.yaxis = [r.analysis.yaxis, resp(:)'];
        end

        % Convolve stimulus with filter to get generator signal.
        pred = ifft(fft([frameValues(:)' zeros(1,100)]) .* fft(r.analysis.linearFilter(:)'));

        pred = binData(pred, 60, binRate); pred=pred(:)';
        r.analysis.xaxis = [r.analysis.xaxis, pred(1 : length(resp))];

        % Get the binned nonlinearity.
        [r.analysis.xBin, r.analysis.yBin] = getNL(r, r.analysis.xaxis, r.analysis.yaxis);
      end
      r.analysis.tempFT = abs(fft(r.analysis.linearFilter));

    case {'edu.washington.riekelab.manookin.protocols.SpatialNoise',...
            'edu.washington.riekelab.manookin.protocols.TernaryNoise',...
            'edu.washington.riekelab.sara.protocols.TempSpatialNoise'}
      r.epochCount = 0;

      r.analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
      r.analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);

      % x/y axes in microns
      r.params.xaxis = linspace(-r.params.numXChecks/2, r.params.numXChecks/2, r.params.numXChecks) * r.params.stixelSize;
      r.params.yaxis = linspace(-r.params.numYChecks/2, r.params.numYChecks/2, r.params.numYChecks) * r.params.stixelSize;

      for ii = 1:r.numEpochs
        r.epochCount = r.epochCount + 1;
        if strcmp(r.params.chromaticClass, 'RGB')
          r.analysis.strf = zeros(3,r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
          r.analysis.spatialRF = zeros(3,r.params.numYChecks, r.params.numXChecks);
          if isfield(r, 'ICspikes')
            r = getSTRFOnline(r, r.ICspikes(ii,:), r.seed(ii));
          else
            r = getSTRFOnline(r, spikes(ii,:), r.seed(ii));
          end
        else
          % updated with mike's new online analysis stuff but now throws errors for RGB noise, will fix at some pt
          r = getSTRFOnline(r, spikes(ii,:), r.seed(ii));
        end
      end

      % not really sure why i'm saving these (not really a STS)
      r.analysis.sum.strf = r.analysis.strf;
      r.analysis.sum.spatialRF = r.analysis.spatialRF;
      % spike triggered average
      r.analysis.strf = r.analysis.strf/r.numEpochs;
      r.analysis.spatialRF = squeeze(mean(r.analysis.strf, 3));

      % run additional analyses on temporal RF
      r = spatialReverseCorr(r);

      % NOTE: just testing this out for now, not sure how good it is
      if ~strcmp(r.params.chromaticClass, 'RGB')
        r.analysis.peaks.on = FastPeakFind(r.analysis.spatialRF);
        r.analysis.peaks.off = FastPeakFind(-1 * r.analysis.spatialRF);
      else
        r.analysis.spatialRF = shiftdim(r.analysis.spatialRF, 1);
      end

    case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
      for ep = 1:r.numEpochs
        [r.analysis.f1amp(ep), r.analysis.f1phase(ep), r.analysis.f2amp(ep), r.analysis.f2phase(ep)] = CTRanalysis(r, spikes(ep,:));
      end

      % fit F1 amplitude
      yd = abs(r.analysis.f1amp(:)');
      r.analysis.params0 = [max(yd) 200 0.1*max(yd) 400]
      switch r.params.stimulusClass
      case 'spot'
        [r.analysis.Kc, r.analysis.sigmaC, r.analysis.Ks, r.analysis.sigmaS] = fitDoGAreaSummation(2*r.params.radii(:)', yd, r.analysis.params0);
        res = fitDoGAreaSummation([r.analysis.Kc, r.analysis.sigmaC, r.analysis.Ks, r.analysis.sigmaS], 2*r.params.radii(:)');
      case 'annulus'
        r.analysis.params = fitAnnulusAreaSum([r.params.radii(:)' 456], yd, r.analysis.params0);
        res = fitAnnulusAreaSummation(r.analysis.params, [r.params.radii(:)' 456]);
        r.analysis.sigmaC = r.analysis.params(2);
        r.analysis.sigmaS = r.analysis.params(4);
      end
        

    case 'edu.washington.riekelab.manookin.protocols.GliderStimulus'
      r.analysis.binRate = 60;
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
          if r.params.sampleRate > r.analysis.binRate
            y = BinSpikeRate(y(prePts+1:end), r.analysis.binRate, r.params.sampleRate);
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
          y = binData(y(prePts+1:end), r.analysis.binRate, r.params.sampleRate);
        end
        y = y(:)';
        if ii == 1
          r.analysis.bins = zeros(length(r.params.stimuli), ceil(r.numEpochs/length(r.params.stimuli)), size(y,2));
          r.analysis.binAvg = zeros(length(r.params.stimuli), size(y,2));
        end
        [ind1, ind2] = ind2sub([length(r.params.stimuli), size(y,2)], ii);
        r.analysis.bins(ind1, ind2, :) = y;
        % for now this will avoid counting zeros when not all stim were run equal times
        r.analysis.binAvg(ind1, :) = squeeze(mean(r.analysis.bins(ind1, 1:ind2, :),2));
      end
  end % parse epoch block


if isfield(r.log, 'analysisTime')
  r.log.analyzed = {r.log.analyzed, date};
else
  r.log.analyzed = date;
end

if neuron == 2
  r.secondary.analysis = r.analysis;
  clear r.analysis;
  r.analysis = r.primaryAnalysis;
  clear r.primaryAnalysis
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

  function [f1amp, f1phase, f2amp, f2phase] = CTRanalysis(r, data)
    switch r.params.recordingType
    case 'extracellular'
      responseTrace = data(r.params.preTime/1000 * r.params.sampleRate+1 : end);
    case 'analog'
          % Subtract the leak and clip out the pre-time.
      if r.params.preTime > 0
          data(1 : round(r.params.sampleRate*(r.params.preTime-16.7)*1e-3)) = [];
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

  function result = sMTFanalysis(r)
    result.params.binRate = 60; result.params.analysisType = 'spikes';
    result.params.allOrAvg = 'avg'; result.params.discardCycles = [];

    sfNum = length(r.params.spatialFrequencies);
    result.F1 = zeros(1, sfNum); result.F2 = zeros(1, sfNum);
    result.ph1 = zeros(1, sfNum); result.ph2 = zeros(1, sfNum);

   for ee = 1: r.numEpochs
        data = spikes(ee,:);

      % Bin the data according to type.
      switch result.params.analysisType
          case 'spikes'
              bData = BinSpikeRate(data(r.params.stimStart:r.params.stimEnd), result.params.binRate, r.params.sampleRate);
          otherwise
              bData = binData(data(r.params.stimStart:r.params.stimEnd), result.params.binRate, r.params.sampleRate);
      end

      [f1, p1] = frequencyModulation(bData, result.params.binRate, r.params.temporalFrequency, result.params.allOrAvg, 1, result.params.discardCycles);
      [f2, p2] = frequencyModulation(bData, result.params.binRate, r.params.temporalFrequency, result.params.allOrAvg, 2, result.params.discardCycles);

        result.F1(ee) = f1;
        result.F2(ee) = f2;
        result.ph1(ee) = p1;
        result.ph2(ee) = p2;
   end
    result.P1 = result.ph1 * 180/pi;
    result.P2 = result.ph2 * 180/pi;
  end

  function [localFilter, linearFilter] = MTFanalysis(r, data, seed)

    numBins = floor(r.params.stimTime/1000 * r.analysis.binRate);
    binSize = r.params.sampleRate / r.analysis.binRate;
    binData = zeros(1, numBins);

    switch r.params.recordingType
    case 'extracellular'
      data = data(r.params.preTime/1000 * r.params.sampleRate+1:end);
      % bin the data
      for k = 1:numBins
        index = round((k-1) * binSize + 1 : k*binSize);
        binData(k) = sum(data(index)) * r.analysis.binRate;
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
      frameValues = r.params.stdev * noiseStream.randn(1, numBins/r.analysis.binsPerFrame);
    end

    % Upsample if necessary.
    if r.analysis.binsPerFrame > 1
        frameValues = ones(r.analysis.binsPerFrame,1) * frameValues;
        frameValues = frameValues(:)';
    end

    % get rid of the first 0.5 sec
    frameValues(1:round(r.analysis.binRate/2)) = 0;
    binData(1:round(r.analysis.binRate/2)) = 0;

    % run reverse correlation
    if isempty(strfind(r.params.chromaticClass, 'RGB'))
      lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
      linearFilter = r.analysis.linearFilter + lf(1 : r.analysis.binRate);
      localFilter = lf(1:r.analysis.binRate);
    else
      lf = zeros(size(r.analysis.linearFilter));
      for ii = 1:3
        tmp = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([squeeze(frameValues(ii,:)), zeros(1,60)]))));
        lf(ii,:) = tmp(1:floor(r.params.frameRate));
      end
      linearFilter = r.analysis.linearFilter + lf(1:r.analysis.binRate);
      localFilter = lf(1:r.analysis.binRate);
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
      valsPerBin = floor(length(xSort) / r.analysis.nonlinearityBins);
      xBin = mean(reshape(xSort(1 : r.analysis.nonlinearityBins*valsPerBin),valsPerBin,r.analysis.nonlinearityBins));
      yBin = mean(reshape(ySort(1 : r.analysis.nonlinearityBins*valsPerBin),valsPerBin,r.analysis.nonlinearityBins));
  end

end % analyzeDataOnline
