function graphAverageOnline(r, avg)
% r is a instance of the group being averaged to provide params
% avg is the struct containing avged values (at same level as the individual instances)

set(groot, 'DefaultAxesFontName', 'Roboto');
set(groot, 'DefaultAxesTitleFontWeight', 'normal');
set(groot, 'DefaultFigureColor', 'w');
set(groot, 'DefaultAxesBox', 'off');

if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.TempChromaticGrating') || strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticGrating')
  figure;
  subplot(3,1,1:2); hold on;
  for ii = 1:size(avg.F1,1)
    plot(r.params.spatialFrequencies, avg.F1(ii,:), '-o', 'linewidth', 0.8);
  end
  set(gca, 'box', 'off', 'tickdir', 'out', 'xscale', 'log', 'xticklabel', []);
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');

  subplot(3,1,3); hold on;
  for ii = 1:size(avg.P1,1)
    plot(r.params.spatialFrequencies, avg.P1(ii,:), '-o', 'linewidth', 0.8);
  end
  set(gca, 'box', 'off', 'tickdir', 'out', 'xscale', 'log');
  axis tight; set(gca, 'ylim', [-180 180], 'ytick', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');


  %% show average
  figure;
  subplot(3,1,1:2); hold on;
  errorbar(r.params.spatialFrequencies, mean(avg.F1), sem(avg.F1), '-o', 'linewidth', 1, 'color', r.params.plotColor);
  set(gca, 'box', 'off', 'tickdir', 'out', 'xscale', 'log', 'xticklabel', []);
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');

  subplot(3,1,3); hold on;
  errorbar(r.params.spatialFrequencies, mean(avg.P1), sem(avg.P1), '-o', 'linewidth', 1, 'color', r.params.plotColor);
  set(gca, 'box', 'off', 'tickdir', 'out', 'xscale', 'log');
  axis tight; set(gca, 'ylim', [-180 180], 'ytick', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');
end
