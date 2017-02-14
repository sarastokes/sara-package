function r = routine_Grating(r, cones, varargin)
  % INPUTS: r
  % OPTIONAL: cones     default = {'liso', 'miso', 'siso'}

  if nargin < 2
    cones = {'liso', 'miso', 'siso'};
  end
  ip = inputParser();
  ip.addParameter('scaleLMS', false, @islogical);
  ip.parse(varargin{:});
  scaleLMS = ip.Results.scaleLMS;

  for ii = 1:length(cones)
    if ~isfield(r.(cones{ii}), 'stats')
      r.(cones{ii}).stats = statsOnline(r.(cones{ii}));
    end
  end

  fh = blankF1Fig;
  S = getappdata(fh, 'GUIdata');

  for ii = 1:length(cones)
    if scaleLMS
      plot(S.F1, r.(cones{ii}).params.SFs, mean(r.(cones{ii}).analysis.F1,1) / max(abs(mean(r.(cones{ii}).analysis.F1,1))),...
      '-o', 'Color', getPlotColor(cones{ii}(1)), 'LineWidth', 1);  hold on;
      ylabel('normalized f1 amplitude');
    else
      plot(S.F1, r.(cones{ii}).params.SFs, mean(r.(cones{ii}).analysis.F1,1), '-o', 'Color', getPlotColor(cones{ii}(1)), 'LineWidth', 1); hold on;
    end
    plot(S.P1, r.(cones{ii}).params.SFs, mean(r.(cones{ii}).analysis.P1,1), '-o', 'Color', getPlotColor(cones{ii}(1)), 'LineWidth', 1); hold on;
  end
  title(S.F1, [r.(cones{1}).cellName ' - average drifting grating']);
  set(findobj(gcf, 'Type', 'Axes'), 'XScale', 'log', 'XLim', [r.(cones{ii}).params.SFs(1) r.(cones{ii}).params.SFs(end)]);
  legend(S.F1, getNiceLabels(cones));
  set(legend, 'EdgeColor', 'w', 'FontSize', 10);

  fh1 = figure('Name', [r.(cones{ii}).cellName ' - band pass ratio']);
  fh1.Position(4) = fh1.Position(4) - 100;
  fh1.Position(3) = fh1.Position(4);
  for ii = 1:length(cones)
    bar(ii, mean(r.(cones{ii}).stats.BPratio, 2), 'FaceColor', getPlotColor(cones{ii}(1), 0.5), 'LineStyle', 'none'); hold on;
    plot(ii + zeros(size(r.(cones{ii}).stats.BPratio)), r.(cones{ii}).stats.BPratio, 'o', 'Color', getPlotColor(cones{ii}(1)), 'LineWidth', 1.5);
  end
  set(gca, 'XTick', 1:length(cones), 'XTickLabel', getNiceLabels(cones), 'Box', 'off', 'TickDir', 'out');
  title([r.(cones{1}).cellName ' - band pass ratio']);
