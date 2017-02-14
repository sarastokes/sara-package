function r = routine_GaussNoise(r, varargin)
  % make gaussian noise lms figures
  % INPUT     r  (c#.gauss) data struct above liso etc
  % OPTIONAL  bpf (6)     binsPerFrame
  %           scaleLMS(true)    scale for LMS gain
  %           cones('liso', 'miso', 'siso')   structure fields
  %           groupPlot (false)     put all stats graphs in one figure

  ip = inputParser();
  ip.addRequired('r', @isstruct);
  ip.addParameter('cones', {'liso', 'miso', 'siso'}, @iscellstr);
  ip.addParameter('bpf', 6, @isnumeric);
  ip.addParameter('scaleLMS', true, @islogical);
  ip.addParameter('groupPlot', false, @islogical);
  ip.parse(r, varargin{:});
  cones = ip.Results.cones;
  bpf = ip.Results.bpf;
  scaleLMS = ip.Results.scaleLMS;

  if nnz(isfield(r, cones)) ~= length(cones)
    error('did not find all cone fields');
  end

  if ~isfield(r, 'NLfit')
    fprintf('running simultaneousNLFit\n');
    for ii = 1:length(cones)
      if ~isfield(r.(cones{ii}).analysis, 'NL') || bpf ~= r.(cones{ii}).analysis.binRate
        r.(cones{ii}) = analyzeOnline(r.(cones{ii}), 'bpf', bpf);
        fprintf('running analyzeOnline at %u bpf\n', bpf);
      end
      x.(cones{ii}(1)) = r.(cones{ii}).analysis.NL.xBin;
      y.(cones{ii}(1)) = r.(cones{ii}).analysis.NL.yBin;
    end
    p = nlinfit([x.l;x.m;x.s], [y.l,y.m,y.s], @simultaneousNLFit, [173 21 8 1 1]);
    yfit = simultaneousNLFit(p, [x.l; x.m; x.s]);
    fac = [1 p(4) p(5)];
  else
    fac = [1 r.NLfit.params(4) r.NLfit.params(5)];
    yfit = r.NLfit.y;
  end

  if ~scaleLMS
    fac = [1 1 1];
  end

  xpts = linspace(0, 1000, r.(cones{1}).analysis.binRate)
  figure('Name', [r.(cones{1}).cellName ' - LMS gaussian noise']); hold on;
  legendstr = [];
  for ii = 1:length(cones)
    lf = smooth(r.(cones{ii}).analysis.linearFilter, 3);
    % normalize filter and multiply by NL scaling factor
    plot(xpts, lf/max(abs(lf)) * fac(ii),...
    'Color', getPlotColor(cones{ii}(1)), 'LineWidth', 1);
    legendstr{ii} = sprintf('%s-iso (n=%u, peak = %.2f)', cones{ii}(1),...
    r.(cones{ii}).numEpochs, r.(cones{ii}).analysis.peakTime);
  end
  title(r.(cones{1}).cellName);
  legend(legendstr);
  set(legend, 'EdgeColor', 'w', 'FontSize', 10);
  xlabel('time (msec)');

  figure('Name', [r.(cones{1}).cellName ' - temporal tuning']); hold on;
  for ii = 1:length(cones)
    tft = smooth(r.(cones{ii}).analysis.tempFT);
    plot(xpts, tft, 'LineWidth', 1, 'Color', getPlotColor(cones{ii}(1)));
  end
  title(r.(cones{1}).cellName);
  legend(legendstr);
  set(legend, 'EdgeColor', 'w', 'FontSize', 10);
  xlabel('temporal frequency (hz)');
  xlim([0 60]);


  for ii = 1:length(cones)
    t2p(ii) = r.(cones{ii}).analysis.peakTime;
    zc(ii) = r.(cones{ii}).analysis.zeroCross;
    bi(ii) = r.(cones{ii}).analysis.biphasicIndex;
  end
  if ~groupPlot
    figure('Name', [r.cellName ' - time to peak']);
    bar(1:length(cones), t2p,...
      'LineStyle', 'none');
    figure('Name', [r.cellName ' - biphasic index']);
    bar(1:length(cones), bi,...
      'LineStyle', 'none');
    figure('Name', [r.cellName ' - zero cross']);
    bar(1:length(cones), zc,...
      'LineStyle', 'none');
  else
    figure('Name', [r.cellName ' - gaussian noise stats']);
    subplot(131); hold on;
    
