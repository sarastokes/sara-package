function checkSpikeDetection(r, epochNum, method)
  % INPUTS: r=data structure, 
  % epochNum = which epoch (0 for all epochs)
  % method = 'diff' = show differential, 'amps' = show amplitudes
  if nargin < 2
    epochNum = 0;
    method = 'amps';
  elseif nargin < 3
    method = 'amps';
  end

  n = size(r.resp,1);
  if isfield(r, 'protocol')
    if epochNum == 0
      epochList = 1:n;
    else
      epochList = epochNum;
    end
    for ii = 1:length(epochList)
      ep = epochList(ii);

      % create figure and menubar option
      % fh = figure('color', 'w');
      % plotMenu = uimenu(fh, 'label', 'Plots');
      % uimenu(plotMenu, 'Label', 'differential', 'Callback', checkSpikeDetection(r, epochNum, 'diff'));
      figure('color', 'w');
      subplot(5, 1, 1:2);
      plot(r.resp(ep,:), 'k');
      title(sprintf('spike detection check - epoch %u', ep)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(513);
      plot(r.spikes(ep,:)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(5, 1, 4:5); respAxes = gca;
      if strcmp(method, 'amps') && any(r.spikes(ep,:))
        plot(r.spikeData.resp(ep,:));
        ylabel('detected spike amplitudes')
      else
        plot([0 diff(r.resp(ep,:))]);
        ylabel('differential of response');
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
end % checkSpikeDetection
