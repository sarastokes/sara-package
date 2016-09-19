function r = getSTRFOnline(r, spikes, seed)

  r.params.preF = floor(r.params.preTime/1000 * r.params.frameRate);
  r.params.stimF = floor(r.params.stimTime/1000 * r.params.frameRate);

if r.params.useRandomSeed
    if strcmp(r.params.chromaticClass, 'achromatic')
      r.analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
      r.analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);
      r.analysis.epochSTRF = zeros(r.numEpochs, r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
    elseif strcmp(r.params.chromaticClass, 'RGB')
      r.analysis.strf = zeros(3, r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
      r.analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks, 3);
      r.analysis.epochSTRF = zeros(r.numEpochs, 3, r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
    end
end

  % from getFrameValues
  numFrames = floor(r.params.stimTime/1000 * r.params.frameRate) / r.params.frameDwell;

  noiseStream = RandStream('mt19937ar', 'Seed', seed);

  if strcmpi(r.params.noiseClass, 'binary')
%    if isempty(strfind(r.protocol,'Chromatic'))
    if strcmpi(r.params.chromaticClass, 'RGB')
        M = noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks,3) > 0.5;
       % backgroundFrame = uint8(r.params.backgroundIntensity * ones(r.params.numYChecks, r.params.numXChecks,3));
      %end
    else
      M = noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks) > 0.5;
      %backgroundFrame = uint8(r.params.backgroundIntensity * ones(r.params.numYChecks, r.params.numXChecks));
    end
    frameValues = uint8(r.params.intensity * 255 * M);
  else
    if strcmpi(r.params.chromaticClass, 'RGB')
      M = uint8((0.3 * r.params.intensity * noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks, 3) * 0.5 + 0.5)*255);
     % backgroundFrame = uint8(r.params.backgroundIntensity * ones(r.params.numYChecks, r.params.numXChecks,3));
    else
      M = uint8((0.3 * r.params.intensity * noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks) * 0.5 + 0.5) * 255);
    %  backgroundFrame = uint8(r.params.backgroundIntensity * ones(r.params.numYChecks, r.params.numXChecks));
    end
    frameValues = M;
  end

  % bin the data
  responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate + 1 : end);
  binWidth = r.params.sampleRate/r.params.frameRate * r.params.frameDwell;
  numBins = floor(r.params.stimTime/1000 * r.params.frameRate / r.params.frameDwell);
  binData = zeros(1, numBins);
  for k = 1:numBins
    index = round((k-1) * binWidth+1 : k*binWidth);
    binData(k) = mean(responseTrace(index));
  end


  % Regenerate the stimulus based on the type.
  stimulus = 2*(double(frameValues)/255)-1;

  filterFrames = floor(r.params.frameRate*0.5/r.params.frameDwell);
  lobePts = round(0.05*filterFrames/0.5) : round(0.15*filterFrames/0.5);

  % Do the reverse correlation.
%  if isempty(strfind(r.protocol, 'Chromatic'))
    if ~isempty(strfind(r.params.chromaticClass, 'RGB'))
      for l = 1 : 3
        filterTmp = zeros(r.params.numYChecks,r.params.numXChecks,filterFrames);
        for m = 1 : r.params.numYChecks
          for n = 1 : r.params.numXChecks
            tmp = ifft(fft(binData') .* conj(fft(squeeze(stimulus(:,m,n,l)))));
            filterTmp(m,n,:) = tmp(1 : filterFrames);
          end
        end
        r.analysis.strf(l,:,:,:) = squeeze(r.analysis.strf(l,:,:,:)) + filterTmp;
        r.analysis.spatialRF(:,:,l) = squeeze(mean(r.analysis.strf(l,:,:,lobePts),4));
        r.analysis.epochSTRF(r.epochCount, l,:,:,:) = filterTmp;
      end
    else
      filterTmp = zeros(r.params.numYChecks,r.params.numXChecks,filterFrames);
      for m = 1 : r.params.numYChecks
        for n = 1 : r.params.numXChecks
          tmp = ifft(fft(binData') .* conj(fft(squeeze(stimulus(:,m,n)))));
          filterTmp(m,n,:) = tmp(1 : filterFrames);
        end
      end
      % if strcmp(r.params.chromaticClass, 'achromatic')
        r.analysis.strf = r.analysis.strf + filterTmp;
        r.analysis.spatialRF = squeeze(mean(r.analysis.strf(:,:,lobePts),3));
%       r.epochCount = r.epochCount +1; NOTE: make sure this was okay
      % else
      %   r.(r.params.chromaticClass).analysis.strf = r.(r.params.chromaticClass).analysis.strf + filterTmp;
      %   r.(r.params.chromaticClass).analysis.spatialRF = squeeze(mean(r.(r.params.chromaticClass).analysis.strf(:,:,lobePts), 3));
      %   r.epochCount = r.epochCount + 1;
      % end
    end

    % get the temporal RF - just achromatic right now
  %  if ~strcmpi(r.params.chromaticClass, 'RGB')
  if strcmp(r.params.chromaticClass, 'achromatic')
    stdev = std(filterTmp); % get SD
    tempSTA = zeros(size(filterTmp, 3), 1);
    for a = 1:size(filterTmp,3)
      pts = squeeze(filterTmp(:,:,a));
      pts =pts(:);
      index = find(abs(pts) > 2*stdev);
      if ~isempty(index)
        tempSTA(a,:) = mean(pts(index));
      elseif isempty(index) && a == size(strf,3)
        tempSTA(a,:) = 0; % to avoid matrix assignment error
        fprintf('%u zero added to tempRF %u\n', a, r.epochCount);
      end
    end
    r.analysis.epochSTA(r.epochCount, :) = tempSTA;
    r.analysis.stdev{r.epochCount} = stdev;
  end
end
