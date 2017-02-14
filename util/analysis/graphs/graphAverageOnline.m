function graphAverageOnline(r, varargin)
% r is a instance of the group being averaged to provide params
% avg is the struct containing avged values (at same level as the individual instances)
% OPTIONAL:
%   avg - needed for sMTF and gratings
%   error - 'off' for no error bars
%   fh - plot to existing figureHandle
%   cones - names of subfields (default: {'liso', 'miso', 'siso'})
%   protocol - protocol name

ip = inputParser();
ip.addParameter('avg', [], @(x)isstruct(x));
ip.addParameter('error', 'on', @(x)ischar(x));
ip.addParameter('fh', [], @(x)ishandle(x));
ip.addParameter('cones', {'liso', 'miso', 'siso'}, @(x)iscellstr(x));
ip.addParameter('protocol', [], @(x)ischar(x));
ip.parse(varargin{:});
avg = ip.Results.avg;
showError = ip.Results.error;
fh = ip.Results.fh;
cones = ip.Results.cones
protocol = ip.Results.protocol;

set(groot, 'DefaultAxesFontName', 'Roboto');
set(groot, 'DefaultAxesTitleFontWeight', 'normal');
set(groot, 'DefaultFigureColor', 'w');
set(groot, 'DefaultAxesBox', 'off',...
  'DefaultLegendEdgeColor', 'w',...
  'DefaultLegendFontSize', 10);

if isempty(protocol)
  if isfield(r, 'protocol')
    protocol = r.protocol;
  else
    r.(cones{1})
    protocol = r.(cones{1}).protocol;
  end
end

switch protocol
case {'edu.washington.riekelab.sara.protocols.TempChromaticGrating',... 
  'edu.washington.riekelab.manookin.protocols.ChromaticGrating'}
  
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
  title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.spatialClass ' '... 
    r.params.temporalClass ' grating (' num2str(size(avg.F1,1)) ' trials)']);

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
  if isempty(fh)
    figure;
    subplot(3,1,1:2); hold on;
    co = pmkmp(size(avg.F1, 1), 'CubicL');
    for ii = 1:size(avg.F1,1)
      plot(r.params.spatialFrequencies, avg.F1(ii,:), '-o',... 
        'LineWidth', 0.8, 'Color', co(ii,:));
      if isfield(avg, 'orientations')
        legendstr{ii} = sprintf('%u%s', avg.orientations(ii), char(176));
      end
    end
    set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log', 'XTickLabel', []);
    axis tight;
    ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
    ylabel('f1 amplitude');
    title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.spatialClass... 
      ' ' r.params.temporalClass ' grating']);
    if ~isempty(legendstr)
      legend(legendstr);
      set(legend, 'EdgeColor', 'w', 'FontSize', 10);
    end
    subplot(3,1,3); hold on;
    for ii = 1:size(avg.P1,1)
      plot(r.params.spatialFrequencies, avg.P1(ii,:), '-o',... 
        'LineWidth', 0.8, 'Color', co(ii,:));
    end
    set(gca, 'Box', 'off', 'TickDir', 'out', 'XScale', 'log');
    axis tight; set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
    ylabel('f1 phase'); xlabel('spatial frequencies');
  end
case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
  if isempty(fh)
    fh = figure;
  else
    gcf = fh;
  end
  
  [c, ~] = getPlotColor(r.params.chromaticClass, [1 0.5]);
  co = pmkmp(size(avg.f1amp, 1), 'CubicL');

  subplot(3, 1, 1:2);hold on;
  if strcmp(showError, 'on')
    errorbar(r.params.radii, mean(avg.f1amp, 1), sem(avg.f1amp), '-o',... 
      'Color', c(1,:), 'LineWidth', 1);
    if isfield(avg, 'f2amp')
      errorbar(r.params.radii, mean(avg.f2amp, 1), sem(avg.f2amp), '-o',... 
        'Color', c(2,:), 'LineWidth', 1);
    end
  else
    plot(r.params.radii, mean(avg.f1amp,1), '-o',... 
      'Color', c(1,:), 'LineWidth', 1);
    if isfield(avg, 'f2amp')
      plot(r.params.radii, mean(avg.f2amp, 1), '-o',...
        'Color', c(2,:), 'LineWidth', 1);
    end
  end
  title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' ' r.params.stimulusClass ' ' r.params.temporalClass ' sMTF (' num2str(size(avg.f1amp, 1)) ' trials)']);
  set(gca, 'XTick', [], 'XColor', 'w', 'Box', 'off', 'TickDir', 'out', 'XScale', 'log');
  ylabel('f1 amplitude'); axis tight;
  ax = gca; ax.YLim(1) = 0;

  subplot(3,1,3); hold on;
  if strcmp(showError, 'on')
    errorbar(r.params.radii, mean(avg.f1phase, 1), sem(avg.f1phase), '-o',... 
      'Color', c(1,:), 'LineWidth', 1);
    if isfield(avg, 'f2amp')
      errorbar(r.params.radii, mean(avg.f2phase, 1), sem(avg.f2phase), '-o',...
        'Color', c(2,:), 'LineWidth', 1);
    end
  else
    plot(r.params.radii, mean(avg.f1phase, 1), sem(avg.f1phase), '-o',... 
      'Color', c(1,:), 'LineWidth', 1);
    if isfield(avg, 'f2phase')
      plot(r.params.radii, mean(avg.f2phase,1), sem(avg.f2phase), '-o',...
        'Color', c(2,:), 'LineWidth', 1);
    end
  end
  axis tight;
  set(gca, 'YLim', [-180 180], 'YTickLabel', -180:90:180,... 
    'Box', 'off', 'XScale', 'log', 'TickDir', 'out');
  xlabel('spot radii (pixels)');
otherwise 
% {'edu.washington.riekelab.manookin.protocols.GaussianNoise', 'edu.washington.riekelab.sara.protocols.IsoSTC'}
  figure('Color', 'w', 'Name', 'Linear Filter Figure');
  hold on;
  legendstr = [];
  for ii = 1:length(cones)
    cone = cones{ii};
    xpts = linspace(1, 1000, r.(cone).analysis.binRate);
    if isfield(r, 'NLfit') && ii == 1
      fac = [1 r.NLfit.params(4) r.NLfit.params(5)];
      fprintf('Scaled by NLfit --> %u, %.2f, %.2f\n', fac);
    else
      fac = [1 1 1];
    end
    plot(xpts, fac(ii)*r.(cone).analysis.linearFilter,... 
      'Color', getPlotColor(cone(1)), 'LineWidth', 1);
    legendstr{ii} = sprintf('%s-iso (n = %u, pk = %.2f)', cone(1),... 
      r.(cone).numEpochs, r.(cone).analysis.peakTime);
  end
  legend(legendstr)
  xlabel('time (msec)');
  title([r.(cone).cellName ' - Gaussian noise linear filters']);

  figure('Color', 'w', 'Name', 'Temporal Tuning Figure'); hold on;
  legendstr = [];
  for ii = 1:length(cones)
    cone = cones{ii};
    plot(r.(cone).analysis.tempFT, 'Color', getPlotColor(cone(1)),...
      'LineWidth', 1);
    legendstr{ii} = sprintf('%s-iso (n = %u)', cone(1), r.(cone).numEpochs);
  end
  legend(legendstr);
  xlabel('time (msec)');
  title([r.(cone).cellName ' - Temporal tuning from linear filters']);
  set(gca, 'XLim', [0 40]);

end


