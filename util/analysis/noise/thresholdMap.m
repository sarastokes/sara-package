function newMap = thresholdMap(oldMap, threshold, plotFlag)
  % INPUTS: oldMap = 2d spatial RF
  %         threshold = threshold value/values
  %         plotFlag = if empty, no plot

  newMap = oldMap/max(max(abs(oldMap)));

  if numel(threshold) == 1
    threshold = [-1*threshold threshold];
  end

  if nargin < 3
    plotFlag = false;
  else
    plotFlag = true;
  end

  for ii = 1:size(newMap,1)
    for jj = 1:size(newMap, 2)
      if newMap(ii,jj) > threshold(1) && newMap(ii,jj) < threshold(2)
        newMap(ii,jj) = 0;
      end
    end
  end

  if plotFlag
    figure('Color', 'w');
    imagesc(newMap);
    if threshold(1) == -1*threshold(2)
      title(sprintf('Cone map with %.1f threshold', threshold(2)));
    else
      title(sprintf('Cone map with %.1f-%.1f threshold', threshold));
    end
    axis equal; axis off; set(gca, 'CLim', [-1 1]);
    tightfig(gcf);
  end
