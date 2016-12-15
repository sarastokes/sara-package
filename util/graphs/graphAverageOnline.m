function graphAverageOnline(r, avg, varargin)
% r is a instance of the group being averaged to provide params
% avg is the struct containing avged values (at same level as the individual instances)
% OPTIONAL:
%   error - 'off' for no error bars
%   fh - plot to existing figureHandle

ip = inputParser();
ip.addParameter('error', 'on', @(x)ischar(x));
ip.addParameter('fh', [], @(x)ishandle(x));
ip.addParameter('focus', 'f1', @(x)ischar(x));
ip.parse(varargin{:});
showError = ip.Results.error;
fh = ip.Results.fh;
focus = ip.Results.focus;

switch focus % is this case sensitive?
  % either way i should standardize all this
case {'f1', 'F1', 'f1amp', 'F1Amp', 'f1Amp'}
  focus = 'F1';
case {'f2', 'F2', 'f2amp', 'F2Amp', 'f2Amp'}
  focus = 'F2';
case {'f0', 'F0'}
  focus = 'F0';
end

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
  title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.spatialClass ' ' r.params.temporalClass ' grating (' num2str(size(avg.F1,1)) ' trials)']);

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
  co = pmkmp(size(avg.F1, 1), 'CubicL');
  for ii = 1:size(avg.F1,1)
    plot(r.params.spatialFrequencies, avg.F1(ii,:), '-o',... 
      'LineWidth', 0.8, 'Color', co(ii,:));
  end
  set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log', 'XTickLabel', []);
  axis tight;
  ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
  ylabel('f1 amplitude');
  title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.spatialClass ' ' r.params.temporalClass ' grating']);

  subplot(3,1,3); hold on;
  for ii = 1:size(avg.P1,1)
    plot(r.params.spatialFrequencies, avg.P1(ii,:), '-o',... 
      'LineWidth', 0.8, 'Color', co(ii,:));
  end
  set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log');
  axis tight; set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
  ylabel('f1 phase'); xlabel('spatial frequencies');
elseif strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.sMTFSpot')
  if isempty(fh)
    fh = figure;
  else
    gcf = fh;
  end
  
  [c, ~] = getPlotColor(r.params.chromaticClass);
  co = pmkmp(size(avg.f1amp, 1), 'CubicL');

  subplot(3, 1, 1:2);hold on;
  if strcmp(showError, 'on')
    errorbar(r.params.radii, mean(avg.f1amp, 1), sem(avg.f1amp, 1), '-o', 'Color', c, 'LineWidth', 1);
  else
    plot(r.params.radii, mean(avg.f1amp,1), '-o', 'Color', c, 'LineWidth', 1);
  end
  title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' ' r.params.stimulusClass ' ' r.params.temporalClass ' sMTF']);
  set(gca, 'XTick', [], 'XColor', 'w', 'Box', 'off', 'TickDir', 'out');
  y = get(gca, 'YLim'); set(gca, 'YLim', [0 ceil(y)]);
  ylabel('f1 amplitude'); axis tight;

  subplot(3,1,3); hold on;
  if strcmp(showError, 'on')
    errorbar(r.params.radii, mean(avg.f1amp, 1), sem(avg.f1amp, 1), '-o', 'Color', c, 'LineWidth', 1);
  else
    plot(r.params.radii, mean(avg.f1phase, 1), sem(avg.f1amp, 1), '-o', 'Color', c, 'LineWidth', 1);
  end
  set(gca, 'YLim', [-180 180], 'YTickLabel', -180:90:180, 'Box', 'off');
  xlabel('spot radii (pixels)');
end
