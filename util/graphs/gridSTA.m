function gridSTA(r)
  h = figure;

  numXChecks = r.params.numXChecks;
  numYChecks = r.params.numYChecks;

  xSize = 1/(numXChecks+3); ySize = 1/(numYChecks+3);
  xPos = 1/(numXChecks+1); yPos = 1/(numYChecks+1);
  xMid = xPos/2; yMid = yPos/2;

  if strcmp(r.params.chromaticClass, 'RGB')
    ymin = min(min(min(min(r.analysis.strf))));
    ymax = max(max(max(max(r.analysis.strf))));
  else
    ymin = min(min(min(r.analysis.strf)));
    ymax = max(max(max(r.analysis.strf)));
  end

  for x = 1:numXChecks
    fprintf('Progress report - row %u', x);
    for y = 1:numYChecks
      yy = numYChecks - y + 1; xx = x;%xx = numXChecks - x + 1;
      axHandle = sprintf('ax_%u_%u', xx, yy);
      axHandle = axes('parent', h, 'position', [xMid + ((xx-1) * xPos), yMid + 0.05 + ((yy-1)*yPos), xSize, ySize]);
      pixelSTA(r, y, x, axHandle);
      axis tight; ylim([ymin ymax]);
      set(axHandle, 'XColor', 'w', 'XTick', []); xlabel('');
      set(axHandle, 'YColor', 'w', 'YTick', []); ylabel('');
      title('');
      axHandle.YLim = [ymin ymax];
    end
  end
end
