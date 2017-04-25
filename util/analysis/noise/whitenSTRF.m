function allFilters = whitenSTRF(r)
  binsPerFrame = 1;
  filterLen = 800;
  freqCutoffFraction = 0.8;
  stimFrames = round(r.params.frameRate * (r.params.stimTime/1e3));
  updateRate = r.params.frameRate/r.params.frameDwell;
  filterPts = (filterLen/1000)*updateRate;
  prePts = r.params.preTime * 1e-3 * r.params.sampleRate;

  allFilters = zeros(r.numEpochs, r.params.numYChecks, r.params.numXChecks, filterPts);


  for ep = 1:r.numEpochs
    response = zeros(1, floor(stimFrames/r.params.frameDwell));
    noiseStream = RandStream('mt19937ar', 'Seed', r.seed(ep));
    newResponse = r.spikes(ep,prePts+1:end);
    chunkLen = r.params.frameDwell * mean(diff(r.stim.frameTimes{ep}));
    noiseMatrix = zeros(r.params.numYChecks, r.params.numXChecks, floor(stimFrames/r.params.frameDwell));
      for ii = 1:floor(stimFrames/r.params.frameDwell)
        noiseMatrix(:,:,ii) = noiseStream.rand(r.params.numYChecks, r.params.numXChecks) > 0.5;
        response(ii) = mean(newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen)));
      end
  end
  getLinearFilterOnline(allStimuli, allResponses);
  filterTmp = zeros(r.params.numYChecks, r.params.numXChecks, filterPts);
  for ii = 1:size(noiseMatrix,1)
    for jj = 1:size(noiseMatrix,2)
      tmp = getLinearFilterOnline(squeeze(noiseMatrix(ii,jj,:))', response, updateRate, freqCutoffFraction*updateRate);
      filterTmp(ii,jj,:) = tmp(1:filterPts);
    end
  end
  % normalize within each epoch
  allFilters(ep,:,:,:) = filterTmp ./ max(filterTmp(:));
