function r = spatialReverseCorr(r)
  % Mike's SpatialReverseCorr object with extra chromatic stuff added in
  % STRF should be in Y,X,T or Y,X,T,C format
  % Run after analyzeDataOnline.m

  if strcmp(r.params.chromaticClass, 'RGB')
    for ii = 1:3
      [r, r.analysis.epochFilters(r.epochCount, ii,:)] = calculateTemporalRF(r, squeeze(r.analysis.strf(ii,:,:,:)));
    end
  else
    % passing r.analysis.strf for ChromaticSpatialNoise.m
    [r, r.analysis.temporalRF] = calculateTemporalRF(r, r.analysis.strf);
    [r, r.analysis.normRF] = normalizeSpatialRF(r, r.analysis.strf);
    [r, r.analysis.SRF] = calculateSpatialRF(r, r.analysis.strf);
    r = calculateSNR(r, r.analysis.strf);
    r = calculateTemporalProperties(r, r.analysis.strf);
  end

  % calculate the temporal receptive field
  function [r, tempRF] = calculateTemporalRF(r, strf)
    r.analysis.stdev = std(strf(:));
    for a = 1:size(strf, 3) % size of time dimension
      pts = squeeze(strf(:,:,a));
      pts = pts(:);
      % find all the points > 2 SDs
      index = find(abs(pts) > 2*r.analysis.stdev);
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
    srf = zeros(size(r.analysis.strf, 1), size(r.analysis.strf, 2));
    for ii = 1:size(r.analysis.strf, 1)
      for jj = 1:size(r.analysis.strf, 2)
        srf(ii, jj) = squeeze(r.analysis.strf(ii, jj, :))' * r.analysis.temporalRF;
      end
    end
  end

  % calculate signal to noise ratio
  function r = calculateSNR(r, strf)
    [rows, cols, ~] = size(strf)
    r.analysis.SNR = zeros(rows, cols);

    for ii = 1:rows
      for jj = 1:cols
        r.analysis.SNR(ii, jj) = max(abs(strf(ii,jj,:))) / std(strf(ii, jj, :));
      end
    end
  end

  % find the peak of the temporal filter
  function r = calculateTemporalProperties(r, strf)
    filterDuration = 1; % in seconds

    [rows, cols, ~] = size(strf);
    r.analysis.peakTime = zeros(rows, cols);
    r.analysis.zeroCross = zeros(rows, cols);
    r.analysis.biphasicIndex = zeros(rows, cols);
    r.analysis.filterSign = zeros(rows, cols);
    for ii = 1:rows
      for jj = 1:cols
        tmp = squeeze(strf(ii, jj, :));

        % OFF filter
        if -min(tmp) > max(tmp)
          r.analysis.filterSign(ii, jj) = -1

          % find the filter peak
          r.analysis.peakTime(ii, jj) = find(tmp == min(tmp), 1) / length(tmp) * 1000 * filterDuration;

          % find the zero-cross
          t = (tmp > 0);
          t(1:find(tmp == min(tmp), 1)) = 0;
          t = find(t == 1, 1);
          if ~isempty(t)
            r.analysis.zeroCross(ii, jj) = t / length(tmp) * 1000 * filterDuration;
          end

          % biphasic index
          r.analysis.biphasicIndex(ii, jj) = abs(min(tmp)/max(tmp));

        else % on filter

          r.analysis.filterSign(ii, jj) = 1;

          % filter peak
          r.analysis.peakTime(ii, jj) = find(tmp == max(tmp), 1) / length(tmp) * 1000 * filterDuration;

          % find the zero cross
          t = (tmp < 0);
          t(1:find(tmp == max(tmp), 1)) = 0;
          t = find(t == 1, 1);
          if ~isempty(t)
            r.analysis.zeroCross(ii, jj) = t / length(tmp) * 1000 * filterDuration;
          end

          % biphasic index
          r.analysis.biphasicIndex(ii, jj) = abs(min(tmp)/max(tmp));
        end
      end
    end
  end

%% this was working and now it's not (or sdev is too high??)
  function [r, normRF] = normalizeSpatialRF(r, strf)
    for x = 1:size(strf, 1)
      for y = 1:size(strf, 2)
        stdev = std(squeeze(strf(x, y, :))); 
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
