function r = getSTRFOnline(r, spikes, seed)
  % 24Sept - replaced parts with mike's new code which isn't working for RGB so use older version for those analyses.

  r.params.preF = floor(r.params.preTime/1000 * r.params.frameRate);
  r.params.stimF = floor(r.params.stimTime/1000 * r.params.frameRate);
  prePts = r.params.preTime * 1e-3 * r.params.sampleRate;

% if r.params.useRandomSeed
%   if strcmp(r.params.chromaticClass, 'achromatic')
%     r.analysis.strf = zeros(r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate * 0.5/r.params.frameDwell));
%     r.analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);
%     r.analysis.epochSTRF = zeros(r.numEpochs, r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
%   elseif strcmp(r.params.chromaticClass, 'RGB')
%     r.analysis.strf = zeros(3, r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
%     r.analysis.spatialRF = zeros(r.params.numYChecks, r.params.numXChecks, 3);
%     r.analysis.epochSTRF = zeros(r.numEpochs, 3, r.params.numYChecks, r.params.numXChecks, floor(r.params.frameRate*0.5/r.params.frameDwell));
%   end
% end

  % from getFrameValues in SpatialNoise protocol
  r.params.numFrames = floor(r.params.stimTime/1000 * r.params.frameRate) / r.params.frameDwell;

  noiseStream = RandStream('mt19937ar', 'Seed', seed);

  if strcmpi(r.params.noiseClass, 'binary') && strcmpi(r.params.chromaticClass, 'RGB')
    % if strcmpi(r.params.chromaticClass, 'RGB')
        M = noiseStream.rand(r.params.numFrames, r.params.numYChecks, r.params.numXChecks,3) > 0.5;
  %   else
  %     M = noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks) > 0.5;
    frameValues = uint8(r.params.intensity * 255 * M);
  else
  % else
  %   if strcmpi(r.params.chromaticClass, 'RGB')
  %     M = uint8((0.3 * r.params.intensity * noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks, 3) * 0.5 + 0.5)*255);
  %   else
  %     M = uint8((0.3 * r.params.intensity * noiseStream.rand(numFrames, r.params.numYChecks, r.params.numXChecks) * 0.5 + 0.5) * 255);
  %   end
  %   frameValues = M;
      frameValues = getSpatialNoiseFrames(r.params.numXChecks, r.params.numYChecks, r.params.numFrames, r.params.noiseClass, r.params.chromaticClass, seed);
  end


  responseTrace = BinSpikeRate(spikes(prePts+1:end), r.params.frameRate, r.params.sampleRate);

  % make response trace same size as stim frames
  responseTrace = responseTrace(1:r.params.numFrames);

  % Columate
  responseTrace = responseTrace(:);

  % zero out the first second while cell is adapting
  responseTrace(1:floor(r.params.frameRate)) = 0;
  if strcmpi(r.params.chromaticClass, 'RGB')
    frameValues(1:floor(r.params.frameRate), :, :,:) = 0;
  else
    frameValues(1: floor(r.params.frameRate), :, :) = 0;
  end

  filterFrames = floor(r.params.frameRate * 0.5);
  lobePts = round(0.05 * r.params.frameRate) : round(0.15 * r.params.frameRate);

  %% bin the data (old)
  % responseTrace = spikes(r.params.preTime/1000 * r.params.sampleRate + 1 : end);
  % binWidth = r.params.sampleRate/r.params.frameRate * r.params.frameDwell;
  % numBins = floor(r.params.stimTime/1000 * r.params.frameRate / r.params.frameDwell);
  % binData = zeros(1, numBins);
  % for k = 1:numBins
  %   index = round((k-1) * binWidth+1 : k*binWidth);
  %   binData(k) = mean(responseTrace(index));
  % end

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
            tmp = ifft(fft(responseTrace') .* conj(fft(squeeze(stimulus(:,m,n,l)))));
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
%          tmp = ifft(fft(binData') .* conj(fft(squeeze(stimulus(:,m,n)))));
          tmp = ifft(fft([responseTrace; zeros(60,1)]) .* conj(fft([squeeze(frameValues(:,m,n)); zeros(60,1);])));
          filterTmp(m,n,:) = tmp(1 : filterFrames);
        end
      end
      r.analysis.strf = r.analysis.strf + filterTmp;
      r.analysis.spatialRF = squeeze(mean(r.analysis.strf(:,:,lobePts),3));
%       r.epochCount = r.epochCount +1; NOTE: make sure this was okay
    end
end
