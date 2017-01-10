function nl = nonlinearity(r, resp)
  % for now, run thru spike detection protocols before function
  % 19Dec2016 - works with 2nd neuron analysis

  if nargin < 2
    switch r.params.recordingType
    case 'extracellular'
      resp = r.spikes;
    case 'analog'
      resp = r.analog;
    case 'current_clamp'
      warndlg('nonlinearity.m not ready for current clamp yet');
    end
  end

  nonlinearityBins = 250;

  binsPerFrame = 6;
  binRate = 60 * binsPerFrame;

  % needed params
  preTime = r.params.preTime; stimTime = r.params.stimTime;
  sampleRate = r.params.sampleRate;
  stdev = r.params.stdev;

  numBins = floor(stimTime/1000 * binRate);
  binSize = sampleRate/binRate;

  allData = zeros(r.numEpochs, numBins);
  allFrames = zeros(r.numEpochs, numBins);
  linearFilter = zeros(r.numEpochs, binRate);

  for ii = 1:r.numEpochs

    if strcmp(r.params.recordingType, 'extracellular')
      data = resp(ii,:);
      % subtract the leak and clip the preTime
      if r.params.preTime > 0
        data(1:round(sampleRate * (preTime - 16.7) * 1e-3)) = [];
      end
      binData = zeros(1, numBins);
      for m = 1:numBins
        index = round((m-1)*binSize+1 : round(m*binSize));
        binData(m) = sum(data(index)) * binRate;
      end
    else
      data = resp(ii,:);
      % subtract the leak and clip the preTime
      if r.params.preTime > 0
        data(1:round(sampleRate * (preTime - 16.7) * 1e-3)) = [];
      end
      data = data - median(data);
      for m = 1:numBins
        index = round((m-1)*binSize+1 : round(m*binSize));
        binData(m) = mean(data(index)); %#ok<AGROW>
      end

      % convert to conductance
      if strcmp(r.params.analysisType, 'excitation')
        binData = binData/-70/1000; % in nS
      else
        binData = binData / 70 / 1000;
      end
    end

    if iscell(r.params.seed)
        seed = r.params.seed{ii};
    else
        seed = r.params.seed(ii);
    end
    
    noiseStream = RandStream('mt19937ar', 'Seed', seed);
    frameValues = stdev * noiseStream.randn(1, numBins/binsPerFrame);

    % upsample if necessary
    if binsPerFrame > 1
      frameValues = ones(binsPerFrame, 1) * frameValues;
      frameValues = frameValues(:)';
    end

    % get rid of first 0.5 sec - transient responses
    frameValues(1:round(binRate/2)) = 0;
    binData(1:round(binRate/2)) = 0;

    % run reverse correlation
    lf = real (ifft (fft([binData, zeros(1,binRate)]) .* conj(fft([frameValues, zeros(1, binRate)])) ) );
    linearFilter(ii, :) = linearFilter(ii,:) + lf(1:binRate);

    allData(ii,:) = binData;
    allFrames(ii,:) = frameValues;
  end

  % take the mean of the linear filters
  f = mean(linearFilter, 1);
  if ~strcmp(r.params.recordingType, 'extracellular')
    f = f - f(3);
    f(1:3) = 0;
  end

  % normalize the filter by the stdev
  f = f/std(f);

  % now convolve the filter with the frames to get the prediction
  pred = zeros(size(allData));
  lf = zeros(1, size(allFrames, 2));
  lf(1:binRate) = f;
  for ii = 1:size(allFrames,1)
    p = ifft(fft([lf, zeros(1, 60)]) .* fft([allFrames(ii,:), zeros(1,60)]));
    pred(ii,:) = p(1:length(lf));
  end

  prediction = pred(:, round(binRate/2)+1:end);
  response = allData(:, round(binRate/2)+1:end);
  response = response(:);

  % sort and bin
  [a, b] = sort(prediction(:));
  xSort = a;
  ySort = response(b);

  valsPerBin = floor(length(xSort) / nonlinearityBins);
  xBin = mean(reshape(xSort(end-nonlinearityBins * valsPerBin+1:end), valsPerBin, nonlinearityBins));
  yBin = mean(reshape(ySort(end - nonlinearityBins * valsPerBin+1:end), valsPerBin, nonlinearityBins));

  % there is something weird going on, make sure the negative xbins translate to negative ybins
  % yBin(xBin<0) = -abs(yBin(xBin < 0));

  % fit the output nonlinearity
  if strcmp(r.params.recordingType, 'extracellular')
    % don't need a(4) for spikes because you can't have a negative spike count
    modelfun = @(a,x) (a(1) * normcdf(x, a(2), a(3)));
    p = nlinfit(xBin, yBin, modelfun, [173 21 8]);
  else % a(4) is essentially the baseline activity of a synapse
    modelfun = @(a,x) (a(1) * normcdf(x, a(2), a(3) + a(4)));
    p = nlinfit(xBin, yBin, modelfun, [173 21 8 -0.1]);
  end


  % save to data structure
  nl.fit = modelfun(p, xBin);
  nl.xBin = xBin;
  nl.yBin = yBin;
  nl.bins = nonlinearityBins;
end
