function r = spatialReverseCorr(r, strf)
  % Mike's SpatialReverseCorr object with extra chromatic stuff added in
  % STRF should be in Y,X,T or Y,X,T,C format

  if strcmp(r.params.chromaticClass, 'RGB')
    for ii = 1:3
      [r, r.analysis.epochFilters(r.epochCount, ii,:)] = calculateTemporalRF(r, squeeze(r.analysis.strf(ii,:,:,:)));
    end
  else
    [r, r.analysis.tempRF] = calculateTemporalRF(r, r.analysis.strf);
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
end
