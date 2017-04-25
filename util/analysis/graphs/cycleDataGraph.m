function fh = cycleDataGraph(r, stimFlag)
  % graph output of cycleData
  % INPUT: r    data structure or output from cycleData
  % OPTIONAL:   stimFlag (false)
  % OUTPUT:     fh    figure handle
  %
  %

  if isfield(r,'protocol')
    cdata = cycleData(r);
  elseif isfield(r, 'ypts')
    cdata = r;
  else
    error('input data structure or cycleData output structure');
  end

  if isfield(r, 'protocol') && ~isempty(strfind(r.protocol, 'ConeSweep'))
    co = [0 0 0; getPlotColor('l'); getPlotColor('m'); getPlotColor('s')];
    if size(cdata.ypts, 1) == 3
      co(1,:) = [];
    end
  else
    co = pmkmp(size(cdata.ypts,1), 'cubicl');
  end

  fh = figure('Color', 'w'); hold on;

  if length(size(cdata.ypts)) == 3
    cdata.ypts = squeeze(mean(cdata.ypts,2));
  end

  for ii = 1:size(cdata.ypts,1)
    plot(cdata.xpts*1000, cdata.ypts(ii,:), 'LineWidth', 1, 'Color', co(ii,:));
  end
  set(gca, 'Box', 'off', 'TickDir', 'out');
  ylabel('spikes/sec'); xlabel('time (ms)')

  if isfield(r, 'protocol')
    title([r.cellName ' cycle average']);
    if strcmp(r.params, 'voltage_clamp')
      ylabel('amplitude (pA)');
    end
  end
