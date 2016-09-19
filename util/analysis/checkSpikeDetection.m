function checkSpikeDetection(r, epochNum)

  [n,~] = size(r.resp);
  if isfield(r, 'protocol')
    if nargin < 2
      epochList = 1:n;
    else
      epochList = epochNum;
    end
    for ii = 1:length(epochList)
      ep = epochList(ii);
      figure; set(gcf, 'color', 'w');
      subplot(5, 1, 1:2);
      plot(r.resp(ep,:), 'k');
      title(sprintf('spike detection check - epoch %u', ep)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(513);
      plot(r.spikes(ep,:)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(5, 1, 4:5);
      plot(r.spikeData.resp(ep,:)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      set(gca, 'YGrid', 'on', 'YMinorGrid', 'on');
    end
  else % chromatic spot protocol
    if nargin < 2
      epochList = 1:length(r)
    else
      epochList = epochNum
    end
    for ii = 1:length(epochList)
      ep = epochList(ii);
      figure; set(gcf, 'color','w');
      subplot(5, 1, 1:2);
      plot(r(ep).resp, 'k');
      title(sprintf('spike detection check - epoch %u', ep)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(513);
      plot(r(ep).spikes); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(5, 1, 4:5);
      plot(r(ep).spikeData.resp); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      set(gca, 'YGrid', 'on', 'YMinorGrid', 'on');
    end
end
