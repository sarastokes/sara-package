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

  if ~isfield(r, 'data')
    n = size(r.resp,1);
    if epochNum == 0
      epochList = 1:n;
    else
      epochList = epochNum;
    end
    for ii = 1:length(epochList)
      ep = epochList(ii);
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
    for ep = 1:size(r.data(epochNum).resp)
      figure; set(gcf, 'color','w');
      subplot(5, 1, 1:2);
      plot(r.data(epochNum).resp(ep,:), 'k'); axis tight;
      title(sprintf('spike detection check - epoch %u', ep)); 
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(513);
      plot(r.data(epochNum).spikes(ep,:)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      subplot(5, 1, 4:5);
      plot(r.data(epochNum).spikeData.resp(ep,:)); axis tight;
      set(gca, 'XColor', 'w', 'XTick', {}, 'Box', 'off');
      set(gca, 'YGrid', 'on', 'YMinorGrid', 'on');
    end
  end
end % checkSpikeDetection
