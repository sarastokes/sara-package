function [r, analysis] = spatialReverseCorr(r, analysis)
  % Mike's SpatialReverseCorr object with extra chromatic stuff added in
  % STRF should be in Y,X,T or Y,X,T,C format
  % Run after analyzeDataOnline.m

  if strcmp(r.params.chromaticClass, 'RGB')
    for ii = 1:3
      [r, analysis.epochFilters(r.epochCount, ii,:)] = calculateTemporalRF(r, squeeze(analysis.strf(ii,:,:,:)));
    end
  else
    % passing analysis.strf for ChromaticSpatialNoise.m
    [r, analysis.temporalRF] = calculateTemporalRF(r, analysis.strf);
    [r, analysis.normRF] = normalizeSpatialRF(r, analysis.strf);
    [r, analysis.SRF] = calculateSpatialRF(r, analysis.strf);
    r = calculateSNR(r, analysis.strf);
    r = calculateTemporalProperties(r, analysis.strf);
  end

  % calculate the temporal receptive field
  function [r, tempRF] = calculateTemporalRF(r, strf)
    analysis.stdev = std(strf(:));
    for a = 1:size(strf, 3) % size of time dimension
      pts = squeeze(strf(:,:,a));
      pts = pts(:);
      % find all the points > 2 SDs
      index = find(abs(pts) > 2*analysis.stdev);
      % only statistically significant stixels included in temporalRF
      if ~isempty(index)
        tempRF(a,:) = mean(pts(index));
      elseif isempty(index) && a == size(strf,3)
        tempRF(a,:) = 0; % to avoid matrix assignment error
        fprintf('%u zero added to tempRF %u\n', a, r.epochCount);
      end
    end
  end

  function [r, srf] = calculateSpatialRF(r, strf)
    srf = zeros(size(analysis.strf, 1), size(analysis.strf, 2));
    for ii = 1:size(analysis.strf, 1)
      for jj = 1:size(analysis.strf, 2)
        srf(ii, jj) = squeeze(analysis.strf(ii, jj, :))' * analysis.temporalRF;
      end
    end
  end

  % calculate signal to noise ratio
  function r = calculateSNR(r, strf)
    [rows, cols, ~] = size(strf)
    analysis.SNR = zeros(rows, cols);

    for ii = 1:rows
      for jj = 1:cols
        analysis.SNR(ii, jj) = max(abs(strf(ii,jj,:))) / std(strf(ii, jj, :));
      end
    end
  end

  % find the peak of the temporal filter
  function r = calculateTemporalProperties(r, strf)
    filterDuration = 1; % in seconds

    [rows, cols, ~] = size(strf);
    analysis.peakTime = zeros(rows, cols);
    analysis.zeroCross = zeros(rows, cols);
    analysis.biphasicIndex = zeros(rows, cols);
    analysis.filterSign = zeros(rows, cols);
    for ii = 1:rows
      for jj = 1:cols
        tmp = squeeze(strf(ii, jj, :));

        % OFF filter
        if -min(tmp) > max(tmp)
          analysis.filterSign(ii, jj) = -1;

          % find the filter peak
          analysis.peakTime(ii, jj) = find(tmp == min(tmp), 1) / length(tmp) * 1000 * filterDuration;

          % find the zero-cross
          t = (tmp > 0);
          t(1:find(tmp == min(tmp), 1)) = 0;
          t = find(t == 1, 1);
          if ~isempty(t)
            analysis.zeroCross(ii, jj) = t / length(tmp) * 1000 * filterDuration;
          end

          % biphasic index
          analysis.biphasicIndex(ii, jj) = abs(min(tmp)/max(tmp));

        else % on filter

          analysis.filterSign(ii, jj) = 1;

          % filter peak
          analysis.peakTime(ii, jj) = find(tmp == max(tmp), 1) / length(tmp) * 1000 * filterDuration;

          % find the zero cross
          t = (tmp < 0);
          t(1:find(tmp == max(tmp), 1)) = 0;
          t = find(t == 1, 1);
          if ~isempty(t)
            analysis.zeroCross(ii, jj) = t / length(tmp) * 1000 * filterDuration;
          end

          % biphasic index
          analysis.biphasicIndex(ii, jj) = abs(min(tmp)/max(tmp));
        end
      end
    end
  end

%% this was working and now it's not (or sdev is too high??)
  function [r, normRF] = normalizeSpatialRF(r, strf)
    stdev = std(strf(:))
    for x = 1:size(strf, 1)
      for y = 1:size(strf, 2)
        % stdev = std(squeeze(strf(x, y, :)));
        pts = squeeze(strf(x, y, :));
        pts = pts(:);
        % find all the points > 2 SDs
        index = find(abs(pts)) > 2*stdev;
        if ~isempty(index)
          normRF(x, y, :) = mean(pts(index));
        elseif isempty(index) && a == size(strf, 3)
          % this will catch + avoid potential matrix assignment error
          normRF(x, y, :) = 0;
          fprintf('at %u, %u zero added for %u\n', x, y, r.epochCount);
        end
      end
    end
  end
end
