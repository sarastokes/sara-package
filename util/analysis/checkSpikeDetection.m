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

      % create figure and menubar option
      fh = figure('color', 'w');
      plotMenu = uimenu(fh, 'label', 'Plots');
      uimenu(plotMenu, 'Label', 'differential', 'Callback', @onPlotDiff);

      subplot(5, 1, 1:2);
      plot(r.resp(ep,:), 'k');
      title(sprintf('spike detection check - epoch %u', ep)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(513);
      plot(r.spikes(ep,:)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(5, 1, 4:5); respAxes = gca;
      if any(r.spikes(ep,:)) == 0
        plot([0 diff(r.resp(ep,:))]);
      else
        plot(r.spikeData.resp(ep,:));
      end
      axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      set(gca, 'YGrid', 'on', 'YMinorGrid', 'on');

    end
  else % chromatic spot protocol
    if nargin < 2
      epochList = 1:length(r);
    else
      epochList = epochNum;
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

  function onPlotDiff(r, epochNum)
    hold(respAxes);
    plot([0 diff(r.resp(epochNum,:))], 'parent', respAxes);
  end

end % checkSpikeDetection
