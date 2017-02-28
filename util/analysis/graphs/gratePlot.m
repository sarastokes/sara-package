function S = gratePlot(sf, f1, p1, S, sc)
  % figure style plot for gratings
  % INPUT:    sf    spatial frequencies (in cpd)
  %           f1    f1 amplitude
  %           p1    p1 amplitude
  % OPTIONAL
  %           S     existing blankF1Fig structure (otherwise new fig)
  %           sc    plot color (vector or cone letter 'm')
  % OUTPUT    S     blankF1Fig structure

  if nargin < 4 || isempty(S)
    S = blankF1Fig;
    S.fh.Position = [550 400 278 420];
  end

  if nargin < 5
    sc = 'k';
  elseif ischar(sc)
    sc = getPlotColor(sc);
  end

  sf = pix2deg(sf);
	plot(S.F1, sf, mean(f1, 1), '-o' , 'Color', sc,'LineWidth', 1);
  hold on;
	plot(S.P1, sf, mean(p1, 1), '-o', 'Color', sc,'LineWidth', 1);
  hold on;
  set(S.F1,'XLim', [sf(1) sf(end)], 'YScale', 'log');
  set(S.P1, 'XLim', [sf(1) sf(end)]);
  % set(S.P1, 'YLim', [-270 90]);
  set(findobj(S.fh, 'Type', 'Axes'), 'XScale', 'log', 'XLim', [0.1 10],...
    'XTickLabel', [0.1 0.5 1 5 10], 'XTick', [0.1 0.5 1 5 10]);
  xlabel(S.P1, 'spatial frequencies (cpd)');
