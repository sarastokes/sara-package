function r = analyzeDataOnline(r)

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticGrating') || strcmp(r.protocol,'edu.washington.riekelab.sara.protocols.TempChromaticGrating')
    r.analysis = sMTFanalysis(r);
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ConeSweep')
    r.analysis.f1amp = zeros(length(r.params.stimClass), r.numEpochs/length(r.params.stimClass));
    r.analysis.f1phase = zeros(length(r.params.stimClass), r.numEpochs/length(r.params.stimClass));
    r.params.plotColors = zeros(length(r.params.stimClass), 3);

    respBlock = zeros(length(r.params.stimClass), (r.numEpochs/length(r.params.stimClass)), length(r.resp));

    for ep = 1:r.numEpochs
      stim = rem(ep, length(r.params.stimClass));
      if stim == 0
        stim = length(r.params.stimClass);
      end
      trial = ceil(ep / length(r.params.stimClass));
      respBlock(stim, trial, :) = r.spikes(ep,:);

      [r.analysis.f1amp(stim,trial), r.analysis.f1phase(stim,trial), ~, ~] = CTRanalysis(r, r.spikes(ep,:));
    end
    r.ptsh.binSize = 200;
      for stim = 1:length(r.params.stimClass)
        r.ptsh.(r.params.stimClass(stim)) = getPTSH(r, squeeze(respBlock(stim,:,:)), 200);
      end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.IsoSTC')
    if strcmp(r.params.paradigmClass, 'STA')
      if isempty(strfind(r.params.chromaticClass, 'RGB'))
        c = 1;
      else
        c = 3;
      end
      r.analysis.lf = zeros(r.numEpochs, c, 60);
      r.analysis.linearFilter = zeros(c, 60);
      for ep = 1:r.numEpochs
        if isempty(strfind(r.params.chromaticClass,'RGB'))
          [r.analysis.lf(ep,:), r.analysis.linearFilter] = MTFanalysis(r, r.spikes(ep,:), r.params.seed{ep});
        else
          [r.analysis.lf(ep,:,:), r.analysis.linearFilter] = MTFanalysis(r, r.spikes(ep,:), r.params.seed{ep});
        end
      end
    elseif strcmp(r.params.paradigmClass, 'STA')
      for ep = 1:r.numEpochs
        [r.analysis.f1amp(ep), r.analysis.f1phase(ep), ~, ~] = CTRanalysis(r, r.spikes(ep,:));
      end
      if r.numEpochs > 1
        r.analysis.meanAmp = mean(r.analysis.f1amp(ep));
        r.analysis.meanPhase = mean(r.analysis.f1phase(ep));
      else
        r.analysis.meanAmp = r.analysis.f1amp;
        r.analysis.meanPhase = r.analysis.f1phase;
      end
      r.analysis.ptshBin = 200;
      r.analysis.ptsh = getPTSH(r, r.spikes, 200);
    end
  end


  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.BarCentering')
    for ep = 1:r.numEpochs
      [r.analysis.f1amp(ep), r.analysis.f1phase(ep), r.analysis.f2amp(ep), r.analysis.f2phase(ep)] = CTRanalysis(r, r.spikes(ep,:));
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot')

    r.analysis.f1amp = zeros(1, length(r.numEpochs));
    r.analysis.f1phase = zeros(size(r.analysis.f1amp));
    r.analysis.f2amp = zeros(size(r.analysis.f1amp));
    r.analysis.f2phase = zeros(size(r.analysis.f1phase));
    r.analysis.xaxis = unique(r.params.contrasts);
    r.analysis.mean_f1amp = zeros(size(r.analysis.xaxis));

    for ep = 1:r.numEpochs
      [r.analysis.f1amp(ep), r.analysis.f1phase(ep), r.analysis.f2amp(ep), r.analysis.f2phase(ep)] = CTRanalysis(r, r.spikes(ep,:));
    end

    for xpt = 1:length(r.analysis.xaxis)
	     numReps = find(r.params.contrasts == r.analysis.xaxis(xpt));
	     r.analysis.mean_f1amp(xpt) = mean(r.analysis.f1amp(numReps));
       r.analysis.mean_f1phase(xpt) = mean(r.analysis.f1phase(numReps));
       r.analysis.mean_f2amp(xpt) = mean(r.analysis.f2amp(numReps));
       r.analysis.mean_f2phase(xpt) = mean(r.analysis.f2phase(numReps));
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.GaussianNoise')
    r.analysis.linearFilter = zeros(1, floor(r.params.frameRate));
    r.analysis.lf = zeros(r.numEpochs, floor(r.params.frameRate));
    for ep = 1:r.numEpochs
  %    [r.analysis.lf(ep,:), r.analysis.linearFilter] = MTFanalysis(r, r.spikes(ep,:), r.params.seed(1,ep));
      spikes = r.spikes(ep,:); seed = r.params.seed(1,ep);
      responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate+1:end);

      % bin data at 60 hz
      binWidth = r.params.sampleRate / r.params.frameRate;
      numBins = floor(r.params.stimTime/1000 * r.params.frameRate);
      for k = 1:numBins
        index = round((k-1) * binWidth + 1 : k*binWidth);
        binData(k) = mean(responseTrace(index));
      end

      % seed random number generator
      noiseStream = RandStream('mt19937ar', 'Seed', seed);

      % get the frame values
      if strcmp(r.params.chromaticClass, 'RGB-gaussian')
        frameValues = r.params.stdev * obj.noiseStream.randn(3, numBins);
      elseif strcmp(r.params.chromaticClass, 'RGB-binary')
        frameValues = noiseStream.randn(3, numBins) > 0.5;
      else
        frameValues = r.params.stdev * noiseStream.randn(1, numBins);
      end

      % get rid of the first 0.5 sec
      frameValues(:, 1:30) = 0;
      binData(:, 1:30) = 0;

      % run reverse correlation
      if isempty(strfind(r.params.chromaticClass, 'RGB'))
        lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
        r.analysis.linearFilter = r.analysis.linearFilter + lf(1:floor(r.params.frameRate));
      else
        lf = zeros(size(r.analysis.linearFilter));
        for ii = 1:3
          tmp = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([squeeze(frameValues(ii,:)), zeros(1,60)]))));
          lf(ii,:) = tmp(1:floor(r.params.frameRate));
        end
        r.analysis.linearFilter = r.analysis.linearFilter + lf;
        r.analysis.lf(ep,:) = lf;
      end
    end

    % get the nonlinearity
    r = nonlinearity(r);
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ChromaticSpatialNoise')
    r.epochCount = 1;
    % r.liso.temporalRF = zeros(size(r.liso.analysis.strf, 3), 1);
    % r.liso.epochSTA = zeros(r.numEpochs, size(r.liso.analysis.strf,4));
    % r.miso.temporalRF = zeros(size(r.liso.temporalRF));
    % r.miso.epochSTA = zeros(size(r.liso.epochSTA));
    % r.siso.temporalRF = zeros(size(r.liso.temporalRF));
    % r.siso.epochSTA = zeros(size(r.liso.epochSTA));

    cones = {'liso' 'miso' 'siso'};
    indCount = 1;
    r.seed = r.liso.seed(1);


    r.liso.analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
    r.liso.analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);
    r.miso.analysis = r.liso.analysis;
    r.siso.analysis = r.liso.analysis;

    r.liso.analysis.epochSTRF = zeros(length(r.liso.seed), r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
    r.miso.analysis.epochSTRF = zeros(length(r.miso.seed), r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
    r.siso.analysis.epochSTRF = zeros(length(r.siso.seed), r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));


    for ii = 1:3:length(r.liso.seed)
      r.epochCount = r.epochCount + 1;
      if indCount <= length(r.liso.seed)
        r.liso = getSTRFOnline(r.liso, r.liso.spikes(indCount,:), r.liso.seed(indCount));
      end
      if indCount <= length(r.miso.seed)
        r.miso = getSTRFOnline(r.miso, r.miso.spikes(indCount,:), r.miso.seed(indCount));
      end
      if indCount <= length(r.siso.seed)
        r.siso = getSTRFOnline(r.miso, r.siso.spikes(indCount,:), r.siso.seed(indCount));
      end
      indCount = indCount + 1;
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.SpatialNoise')
    r.epochCount = 0;
    % init spatialReverseCorr params
    % if strcmp(r.params.chromaticClass, 'RGB')
    %   r.analysis.temporalRF = zeros(3, size(r.analysis.strf, 4));
    %   r.analysis.epochSTA = zeros(r.numEpochs, 3, size(r.analysis.strf,4));
    % else % achromatic and cone iso
    %   r.analysis.temporalRF = zeros(size(r.analysis.strf, 3), 1);
    %   r.analysis.epochSTA = zeros(r.numEpochs, size(r.analysis.strf,4));
    % end

    r.analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));

    for ii = 1:r.numEpochs
      r.epochCount = r.epochCount + 1;
      r = getSTRFOnline(r, r.spikes(ii,:), r.seed(ii));
      % extra analyses for temporal receptive field
  %    r = spatialReverseCorr(r, r.analysis.epochSTRF(ii));
  %    r.analysis.epochFilters(r.numEpochs, 1:length(r.analysis.tempRF)) = r.analysis.tempRF;
    end
  end



  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.sMTFspot')
    for ep = 1:r.numEpochs
      [r.analysis.f1amp(ep), r.analysis.f1phase(ep), r.analysis.f2amp(ep), r.analysis.f2phase(ep)] = CTRanalysis(r, r.spikes(ep,:));
    end
  end



  function [f1amp, f1phase, f2amp, f2phase] = CTRanalysis(r, spikes)
    responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate+1 : end);
    binRate = 60;
    binWidth = r.params.sampleRate/binRate;
    numBins = floor(r.params.stimTime/1000 * binRate);
    binnedData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binnedData(k) = mean(responseTrace(index));
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
        data = r.spikes(ee,:);

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

  function [localFilter, linearFilter] = MTFanalysis(r, spikes, seed)
    responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate+1:end);

    % bin data at 60 hz
    binWidth = r.params.sampleRate / r.params.frameRate;
    numBins = floor(r.params.stimTime/1000 * r.params.frameRate);
    for k = 1:numBins
      index = round((k-1) * binWidth + 1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end

    % seed random number generator
    noiseStream = RandStream('mt19937ar', 'Seed', seed);

    % get the frame values
    if strcmp(r.params.chromaticClass, 'RGB-gaussian')
      frameValues = r.params.stdev * obj.noiseStream.randn(3, numBins);
    elseif strcmp(r.params.chromaticClass, 'RGB-binary')
      frameValues = noiseStream.randn(3, numBins) > 0.5;
    else
      frameValues = r.params.stdev * noiseStream.randn(1, numBins);
    end

    % get rid of the first 0.5 sec
    frameValues(:, 1:30) = 0;
    binData(:, 1:30) = 0;

    % run reverse correlation
    if isempty(strfind(r.params.chromaticClass, 'RGB'))
      lf = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
      r.analysis.linearFilter = r.analysis.linearFilter + lf(1:floor(r.params.frameRate));
    else
      lf = zeros(size(r.analysis.linearFilter));
      for ii = 1:3
        tmp = real(ifft(fft([binData, zeros(1,60)]) .* conj(fft([squeeze(frameValues(ii,:)), zeros(1,60)]))));
        lf(ii,:) = tmp(1:floor(r.params.frameRate));
      end
      linearFilter = r.analysis.linearFilter + lf;
      localFilter = lf;
    end
  end

  function [STA, numSpikes] = STAanalysis(r, spikes, seed)
    binRate = 60;
    if strcmp(r.params.chromaticClass, 'RGB')
	    STA = zeros(3, binRate);
    else
	    STA = zeros(1, binRate);
    end

    numSpikes = 0;
    stimCov = zeros(size(STA));
    stimMean = zeros(size(STA));
    numStim = 0;

    for ii = 1:r.numEpochs
      frameTTLs = r.frame(ii,:);
	    [frameTimes, frameRate] = getFrameTimingTTLs(frameTTLs, r.params.sampleRate);
	    frameRate = 60;

      stimStart = r.params.preTime / 1000 * r.params.sampleRate + 1;
      stimEnd = r.params.preTime + r.params.stimTime / 1000 * sampleRate;

	    % get frame times during the stimulus
	    frameTimes = frameTimes(frameTimes >= stimStart & frameTimes <= stimEnd)

	    % make sure you sync with the actual presentation of first non-gray frame
	    stimStart = frameTimes(1);
	    stimEnd = max(frameTimes(end) + ceil(r.params.sampleRate/frameRate), stimEnd);

	    % calculate the number of frames
	    numFrames = length(frameTimes);

	    % regenerate the noise
	     noiseStream = RandStream('my19937ar', 'Seed', r.seed(ii));
       if strcmp(r.params.noiseClass, 'gaussian') && strcmp(r.params.chromaticClass, 'achromatic')
         noise = r.params.stdev * noiseStream.randn(1, numFrames);
       elseif strcmp(r.params.noiseClass, 'binary') && strcmp(r.params.chromaticClass, 'RGB')
         noise = noiseStream.randn(3, numFrames) > 0.5;
       end

       % get the spike times
       spikeTimes = find(r.resp(ii, stimStart:end) == 1);
       % convert to bin rate
       spikeTimes = ceil(spikeTimes / r.params.sampleRate * binRate);
       spikeTimes(spikeTimes > length(stimulus)) = [];
       response = spikeTimes;

       sr = makeStimRows(stimulus(:), binRate, response);
       STA = STA + sum(sr, 1);
       numSpikes = numSpikes + size(sr, 1);
     end
     STA = STA/numSpikes;
   end

   function [lf, linearFilter] = STRFanalysis(r, spikes, seed)
    % lf is individual epoch
    % linearFilter is mean of epochs analyzed so far, pulled from struct

    responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate+1 : end);
    binWidth = r.params.sampleRate / r.params.frameRate;
    numBins = floor(r.params.stimTime/1000 * r.params.frameRate);
    binnedData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binnedData(k) = mean(responseTrace(index));
    end

    % seed random number generator
    noiseStream = RandStream('mt19937ar', 'seed', seed);

    % get the frame values
    if ~isempty(strfind(r.protocol, 'SpatialNoise'))
      if strcmp(r.params.chromaticClass, 'RGB')
        frameValues = noiseStream.randn(3, r.params.numYChecks, r.params.numXChecks, numBins) > 0.5;
        frameValues(:, :, :, 1:30) = 0;
      else
        frameValues = noiseStream.randn(r.params.numYChecks, r.params.numXChecks, numBins) > 0.5;
        frameValues(:, :, 1:30) = 0;
      end
    else
      % temporal noise
      if ~isempty(strfind(r.params.chromaticClass, 'RGB'))
        frameValues = noiseStream.randn(3, numBins) > 0.5;
      else
        frameValues = r.params.stdev * noiseStream.randn(1, numBins);
      end
      frameValues(:, 1:30) = 0;
    end

    % get rid of the first 0.5s
    binnedData(:, 1:30) = 0;
    size(binnedData)

    units = floor(r.params.frameRate);

    % run reverse correlation
    if ~isempty(strfind(r.protocol, 'SpatialNoise'))
      if isempty(strfind(r.params.chromaticClass, 'RGB'))
        localSTRF = zeros(r.params.numYChecks, r.params.numXChecks, units);
        for yy = 1:r.params.numYChecks
          for xx = 1:r.params.numXChecks
            localFrameValues = squeeze(frameValues(yy, xx, :));
            size(localFrameValues)
            lf = real(ifft(fft([binnedData, zeros(1,60)]) .* conj(fft([localFrameValues, zeros(1,60)]))));
            localSTRF(yy, xx, :) = lf(yy, xx, units);
          end
        end
        strf = r.analysis.strf + localSTRF;
      else % chromatic
        localSTRF = zeros(3, r.params.numYChecks, r.params.numXChecks, units);
        for cc = 1:3
          for yy = 1:r.params.numYChecks
            for xx = 1:r.params.numXChecks
              localFrameValues = squeeze(frameValues(cc, yy, xx, :));
              lf = real(ifft(fft([binnedData, zeros(1, 60)]) .* conj(fft([localFrameValues, zeros(1,60)]))));
              localSTRF(cc, yy, xx, :) = lf(cc, yy, xx, units);
            end
          end
        end
        r.analysis.strf = r.analysis.strf + localSTRF;
      end
      % match function output variables
      linearFilter = strf; lf = localSTRF;
    end

    % gaussian noise
    if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.GaussianNoise') || strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.IsoSTC')
      if isempty(strfind(r.params.chromaticClass, 'RGB'))
        lf = real(ifft(fft([binnedData, zeros(1,60)]) .* conj(fft([frameValues, zeros(1,60)]))));
        lf = lf(units);
        linearFilter = r.analysis.linearFilter + lf;
      else
        for ii = 1:3
          tmp = real(ifft(fft([binnedData, zeros(1,60)]) .* conj(fft([(squeeze(frameValues(ii,:))), zeros(1,60)]))));
          lf(ii,:) = tmp(units);
        end
        linearFilter = r.analysis.linearFilter + lf;
      end
    end
  end


end
