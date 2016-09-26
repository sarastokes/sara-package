function graphAverageOnline(r, avg)
% r is a instance of the group being averaged to provide params
% avg is the struct containing avged values (at same level as the individual instances)

if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.TempChromaticGrating') || strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticGrating')
  figure;
  subplot(3,1,1:2); hold on;
  for ii = 1:size(avg.F1amp,1)
    plot(r.params.spatialFrequencies, avg.F1amp(ii,:), '-o', 'linewidth', 1);
  end
  set(gca, 'box', 'off', 'tickdir', 'out', 'xcolor', 'w', 'xscale', 'log', 'xticklabel', []);
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');

  subplot(3,1,3); hold on;
  for ii = 1:size(avg.F1ph,1)
    plot(r.params.spatialFrequencies, avg.F1ph(ii,:), '-o', 'linewidth', 1);
  end
  set(gca, 'box', 'off', 'tickdir', 'out', 'xscale', 'log');
  axis tight; set(gca, 'ylim', [-180 180], 'yticklabel', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');

  %% show average
  figure;
  subplot(3,1,1:2); hold on;
  errorbar(r.params.spatialFrequencies, mean(avg.F1amp), sem(avg.F1amp), '-o', 'linewidth', 1);
  set(gca, 'box', 'off', 'tickdir', 'out', 'xcolor', 'w', 'xscale', 'log', 'xticklabel', []);
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');

  subplot(3,1,3); hold on;
  errorbar(r.params.spatialFrequencies, mean(avg.F1ph), sem(avg.F1ph), '-o', 'linewidth', 1);
  set(gca, 'box', 'off', 'tickdir', 'out', 'xscale', 'log');
  axis tight; set(gca, 'ylim', [-180 180], 'yticklabel', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');
end
