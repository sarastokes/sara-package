function fh = cycleDataGraph(rdata, stimFlag)
  % graph output of cycleData
  % INPUT: r    data structure or output from cycleData
  % OPTIONAL:   stimFlag (false)
  % OUTPUT:     fh    figure handle
  %
  %

  if isfield(r,'protocol')
    cdata = cycleData(r);
    cw = r.params.coneWeights;
  elseif isfield(r, 'ypts')
    cdata = r;
  else
    error('input data structure or cycleData output structure');
  end


  fh = figure('Color', 'w'); hold on;
  co = pmkmp(size(cdata.ypts,1), 'cubicl');

  for ii = 1:size(cdata.ypts,1)
    plot(cdata.xpts, cdata.ypts(ii,:), 'LineWidth', 1, 'Color', cw(ii,:));
  end
  set(gca, 'Box', 'off', 'TickDir', 'out');

  if isfield(r, 'protocol')
    title([r.cellName ' cycle average']);
  end
