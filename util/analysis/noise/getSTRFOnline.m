function [r, analysis, filterTmp] = getSTRFOnline(r, analysis, spikes, seed)
  % 24Sept - replaced parts with mike's new code which isn't working for RGB so use older version for those analyses.
  % 21Jan2017 - passing intensity to slightly modified version of
  % getSpatialNoiseFrames for gaussian noise analysis

  if ~isfield(analysis, 'binsPerFrame')
    analysis.binsPerFrame = 1;
    fprintf('binsPerFrame set to 1\n');
  end

  if ~isfield(r.params, 'preF')
    r.params.numFrames = floor(r.params.stimTime/1000 * r.params.frameRate) / r.params.frameDwell;
    r.params.preF = floor(r.params.preTime/1000 * r.params.frameRate * analysis.binsPerFrame);
    r.params.stimF = floor(r.params.stimTime/1000 * r.params.frameRate * analysis.binsPerFrame);
  end
  prePts = r.params.preTime * 1e-3 * r.params.sampleRate;

  noiseStream = RandStream('mt19937ar', 'Seed', seed);

  if strcmpi(r.params.noiseClass, 'binary') && strcmpi(r.params.chromaticClass, 'RGB')
    frameValues = noiseStream.rand(r.params.numFrames, r.params.numYChecks, r.params.numXChecks,3) > 0.5;
    stimulus = 2*frameValues-1;
  else
    stimulus = getSpatialNoiseFramesSara(r.params.numXChecks, r.params.numYChecks,...
      r.params.numFrames, r.params.noiseClass, r.params.chromaticClass, seed, r.params.intensity);
  end

  if analysis.binsPerFrame > 1
    stimulus = upsampleFrames(shiftdim(stimulus,1), analysis.binsPerFrame);
    stimulus = shiftdim(stimulus,2);
  end

  % just for extracellular right now
  responseTrace = BinSpikeRate(spikes(prePts+1:end), r.params.frameRate * analysis.binsPerFrame, r.params.sampleRate);

  % make response trace same size as stim frames
  responseTrace = responseTrace(1:r.params.numFrames * analysis.binsPerFrame);
  % Columate
  responseTrace = responseTrace(:);

  % zero out the first second while cell is adapting
  responseTrace(1:floor(r.params.frameRate*analysis.binsPerFrame)) = 0;
  if strcmpi(r.params.chromaticClass, 'RGB')
    stimulus(1:floor(r.params.frameRate*analysis.binsPerFrame), :, :,:) = 0;
  else
    stimulus(1: floor(r.params.frameRate*analysis.binsPerFrame), :, :) = 0;
  end

  filterFrames = floor(r.params.frameRate * analysis.binsPerFrame * 0.5);
  lobePts = round(0.05*r.params.frameRate*analysis.binsPerFrame) : round(0.15*r.params.frameRate*analysis.binsPerFrame);

  % Do the reverse correlation.
%  if isempty(strfind(r.protocol, 'Chromatic'))
    if ~isempty(strfind(r.params.chromaticClass, 'RGB'))
      filterTmpC = zeros(3, r.params.numYChecks, r.params.numXChecks, filterFrames);
      for l = 1:3
        filterTmp = zeros(r.params.numYChecks, r.params.numXChecks, filterFrames);
        for m = 1:r.params.numYChecks
          for n = 1:r.params.numXChecks
            tmp = ifft(fft([responseTrace; zeros(60,1)]) .* conj(fft([squeeze(stimulus(:,m,n,l)); zeros(60,1);])));
            filterTmp(m,n,:) = tmp(1:filterFrames);
            filterTmpC(l,m,n,:) = tmp(1:filterFrames);
          end
        end
      end
      analysis.strf = analysis.strf + filterTmpC;
      analysis.spatialRF = squeeze(mean(analysis.strf(l,:,:,lobePts), 4));
    else
      filterTmp = zeros(r.params.numYChecks, r.params.numXChecks, filterFrames);
      for m = 1 : r.params.numYChecks
        for n = 1 : r.params.numXChecks
          tmp = real(ifft(fft([responseTrace; zeros(60, 1)]) .* conj(fft([squeeze(stimulus(:, m, n)); zeros(60, 1);]))));
          filterTmp(m,n,:) = tmp(1:filterFrames);
        end
      end
      analysis.strf = analysis.strf + filterTmp;
      analysis.spatialRF = squeeze(mean(analysis.strf(:,:,lobePts),3));
    end
end
