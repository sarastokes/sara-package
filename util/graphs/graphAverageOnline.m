function graphAverageOnline(r, avg, varargin)
% r is a instance of the group being averaged to provide params
% avg is the struct containing avged values (at same level as the individual instances)
% OPTIONAL:
%   error - 'off' for no error bars
%   fh - plot to existing figureHandle

ip = inputParser();
ip.addParameter('error', 'on', @(x)ischar(x));
ip.addParameter('fh', [], @(x)ishandle(x));
ip.parse(varargin{:});
showError = ip.Results.error;
fh = ip.Results.fh;

set(groot, 'DefaultAxesFontName', 'Roboto');
set(groot, 'DefaultAxesTitleFontWeight', 'normal');
set(groot, 'DefaultFigureColor', 'w');
set(groot, 'DefaultAxesBox', 'off');

if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.TempChromaticGrating') || strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticGrating')
  
  % plot to existing figure or create a new one
  if isempty(fh)
    figure;
  else
    gcf = fh;
  end
  % plot the average traces
  subplot(3,1,1:2); hold on;
  if strcmp(showError, 'on')
    errorbar(r.params.spatialFrequencies, mean(avg.F1), sem(avg.F1), '-o',... 
      'LineWidth', 1, 'Color', r.params.plotColor);
  else
    plot(r.params.spatialFrequencies, mean(avg.F1), '-o',...
      'LineWidth', 1, 'Color', r.params.plotColor);
  end
  set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log', 'XTickLabel', {});
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');
  title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.spatialClass ' ' r.params.temporalClass ' grating']);

  subplot(3,1,3); hold on;
  if strcmp(showError, 'on')
    errorbar(r.params.spatialFrequencies, mean(avg.P1), sem(avg.P1), '-o',... 
      'LineWidth', 1, 'Color', r.params.plotColor);
  else
    plot(r.params.spatialFrequencies, mean(avg.P1), '-o',... 
      'LineWidth', 1, 'Color', r.params.plotColor);
  end
  set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log');
  axis tight; set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');

  % plot the individual traces
  figure;
  subplot(3,1,1:2); hold on;
  for ii = 1:size(avg.F1,1)
    plot(r.params.spatialFrequencies, avg.F1(ii,:), '-o', 'linewidth', 0.8);
  end
  set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log', 'XTickLabel', []);
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');
  title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.spatialClass ' ' r.params.temporalClass ' grating']);

  subplot(3,1,3); hold on;
  for ii = 1:size(avg.P1,1)
    plot(r.params.spatialFrequencies, avg.P1(ii,:), '-o', 'LineWidth', 0.8);
  end
  set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log');
  axis tight; set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');
end
