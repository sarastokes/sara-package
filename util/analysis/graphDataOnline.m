function r = graphDataOnline(r, varargin)
  % INPUT:    r = data structure (r.data for ChromaticSpot btw)
  % OPTIONAL: neuron = which cell graph (for dual recs, default is 1)
  %           plotAll = run all plots. default = true, false for less figures
  %           bkgd = ([]) set to black for neitz lab figures
  %           smooth = how much to smooth linear filters by (0)
  %           fac = for firing rate (20)
  %           numCycles = for cycle avg (1)

  ip = inputParser();
  ip.addParameter('neuron', 1, @isvector);
  ip.addParameter('plotAll', true, @islogical);
  ip.addParameter('smooth', 0, @isnumeric);
  ip.addParameter('bkgd', [], @ischar)
  ip.addParameter('fac', 20, @isnumeric);
  ip.addParameter('numCycles', 1, @isnumeric);
  ip.addParameter('cmap', 'pmkmp', @ischar);
  ip.parse(varargin{:});
  neuron = ip.Results.neuron;
  plotAll = ip.Results.plotAll;
  nSmooth = ip.Results.smooth;
  bkgd = ip.Results.bkgd;
  fac = ip.Results.fac;
  numCycles = ip.Results.numCycles;
  cmap = ip.Results.cmap;
  if isempty(find(ismember(cmap, {'pmkmp', 'virindis', 'hsv'})));
    cmap = 'pmkmp';
  end


  if ~isempty(bkgd)
    colordef black;
    set(0, 'DefaultFigureColor', 'k');
  end

  if isfield(r, 'protocol') % not for ChromaticSpot yet
    r = makeCompatible(r);
    if neuron == 2
      analysis = r.secondary.analysis;
      r.cellName = [r.cellName '*'];
    elseif neuron == 1
      if isfield(r, 'analysis')
        analysis = r.analysis;
      end
    else
      error('neuron should be 1 or 2');
    end
  else
    neuron = 1;
  end

  set(0, 'DefaultAxesFontName', 'Roboto',...
    'DefaultAxesTitleFontWeight', 'normal',...
    'DefaultFigureColor', 'w',...
    'DefaultAxesBox', 'off',...
    'DefaultLegendEdgeColor', 'w',...
    'DefaultAxesTickDir', 'out');

if ~isfield(r, 'protocol')
    switch r(1).recordingType
    case 'extracellular'
      units = 'response (pA)';
    case 'voltage_clamp'
      units = 'current (pA)';
      if ~isfield(r(1).params, 'holding')
        answer = inputdlg('Holding potential was:', 'set holding potential', 1, {'-60'});
        r(1).params.holding = str2double(answer{1});
        fprintf('holding potential set to %u\n', r(1).params.holding);
      end
    end
    for ii = 1:length(r)
      params = r(ii).params;
      if params.outerRadius > 1000
        spotName = 'full-field';
      else
        spotName = sprintf('%u microns', params.radiusMicrons);
      end
      r(ii).stimTrace = getStimTrace(params, 'pulse');
      [n, ~] = size(r(ii).resp);
      if strcmp(r(ii).recordingType, 'extracellular')
        r(ii).binSize = 200;
        co = zeros(n,3);
        data = r(ii).resp;
      else
        data = r(ii).analog;
        if n > 1
          co = pmkmp(n, 'cubicL');
        else
          co = [0 0 0];
        end
      end
      if plotAll
        for jj = 1:n
          if jj == 1 || strcmp(r(ii).recordingType, 'extracellular')
            % extracellular figure per trace, WC all on same figure
            S = blankRespFig;
            figPos(gcf, 0.95, 0.8);
          end
          plot(S.resp, getXpts(data), data(jj,:), 'Color', co(jj,:));
          set(S.resp,'box', 'off', 'tickdir', 'out'); axis tight;
          ylabel(S.resp, units); xlabel(S.resp, '');
          title(S.resp, [r(ii).label ' - ' r(ii).chromaticClass ' spot (' num2str(r(ii).params.contrast *100) '%, ' spotName ', ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf)'])
          plot(S.stim, r(ii).stimTrace,...
          'Color', getPlotColor(r(ii).params.chromaticClass), 'LineWidth', 1);
          axis tight; ylim([0 1]);
        end
        if strcmp(r(ii).recordingType, 'voltage_clamp')
          if max(max(r(ii).analog))  > 1000 || min(min(r(ii).analog)) < 1000
            ylabel(S.resp, 'current (nA)');
            set(S.resp, 'YTickLabel', str2double(get(S.resp, 'YTickLabel'))/1000);
          end
        end
      end

      % average graphs (instft for extracellular, mean for voltage clamp)
      % 5Mar2017 - commented out ptsh, switched to instft
      if strcmp(r(ii).recordingType, 'extracellular')
        % r(ii).ptsh = getPTSH(r, r(ii).spikes, 200);
        r(ii).instFt = getInstFt(r(ii).spikes, fac);
        if n > 1
          S = blankRespFig;
          figPos(gcf, 0.95, 0.8);
          plot(S.resp, linspace(0, length(r(ii).spikes), length(r(ii).instFt))/10000, mean(r(ii).instFt, 1),...
          'Color', getPlotColor(r(ii).chromaticClass), 'LineWidth', 0.9);
          % bar(S.resp, r(ii).ptsh.binCenters/10000, r(ii).ptsh.spikeCounts,...
          %  'edgecolor', 'k', 'facecolor', c1, 'linestyle', 'none');
          title(S.resp, [r(ii).label ' - ' r(ii).chromaticClass ' spot (' spotName ', ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf, ' num2str(n) ' trials)']);
          set(S.resp,'box', 'off', 'tickdir', 'out'); axis tight;
          ylabel(S.resp, 'spikes/sec');

          plot(S.stim, r(ii).stimTrace,...
          'Color', getPlotColor(r(ii).chromaticClass), 'LineWidth', 1);
          set(S.stim, 'Box', 'off', 'TickDir', 'out', 'XColor', 'w');
          axis tight; ylim([0 1]);
        end
      elseif strcmp(r(ii).recordingType, 'voltage_clamp')
        % just do the mean resp for whole cell
        r(ii).avgResp = mean(r(ii).analog, 1);
        S = blankRespFig;
        figPos(gcf, 0.95, 0.8);
        xpts = 1:length(r(ii).avgResp); xpts = xpts/10000;
        plot(S.resp, xpts, r(ii).avgResp, 'Color', 'k', 'LineWidth', 1);
        set(S.resp, 'Box', 'off', 'TickDir', 'out'); axis tight;
        title(S.resp, [r(ii).label ' - ' r(ii).chromaticClass ' spot at ' num2str(r(1).params.holding) 'mV (' spotName ', ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf, ' num2str(n) ' trials)']);
        if max(max(r(ii).analog)) > 1000 || min(min(r(ii).analog)) < -1000
          set(S.resp, 'YTickLabel', str2double(get(S.resp, 'YTickLabel'))/1000);
          ylabel(S.resp, 'current (nA)');
        else
          ylabel(S.resp, 'current (pA)');
        end
        xlabel(S.resp, '');

        plot(S.stim, r(ii).stimTrace,...
        'Color', getPlotColor(r(ii).chromaticClass), 'LineWidth', 1);
        axis tight; set(S.stim, 'YLim', [0 1]);
      end
    end
else
  switch(r.protocol)
    case 'edu.washington.riekelab.sara.protocols.TempSpatialNoise'
      % strfViewer(r);

    case {'edu.washington.riekelab.sara.protocols.CompareCones', 'edu.washington.riekelab.sara.protocols.ColorExchange'}
      S = blankF1Fig;
      plot(S.F1, 1:r.numEpochs, r.analysis.F1, '-ok', 'LineWidth', 1);
      if strcmp(r.params.temporalClass, 'squarewave')
        plot(S.F1, 1:r.numEpochs, r.analysis.F2, '-o', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
      end
      legend('F1', 'F2');
      title(S.F1, [r.cellName ' - ' r.params.coneOne ' vs ' r.params.coneTwo ' color exchange (' num2str(r.params.temporalFrequency) ' hz ' r.params.temporalClass ')']);

      plot(S.P1, 1:r.numEpochs, r.analysis.P1, '-ok', 'LineWidth', 1);
      if strcmp(r.params.temporalClass, 'squarewave')
        plot(S.P1, 1:r.numEpochs, r.analysis.P2, '-o', 'LineWidth', 1, 'Color', [0.5 0.5 0.5]);
      end
      set(S.P1, 'YLim', [-180 180], 'YTick', -180:90:180);

      % plot F1 amp with model neurons
      figure(); hold on;
      % pos = get(gcf, 'Position');
      % pos(4) = pos(4)+100; pos(2) = pos(2)-100;
      % set(gcf, 'Position', pos);
      if strcmp(r.params.stimSpace, 'cone')
        stim1 = r.params.(sprintf('%sWeights', r.params.stimSpace))(:, strfind('LMS', r.params.coneOne));
        stim2 = r.params.(sprintf('%sWeights', r.params.stimSpace))(:, strfind('LMS', r.params.coneTwo));
      else
        stim1 = r.params.(sprintf('%sWeights', r.params.stimSpace))(:, strfind('RGB', r.params.coneOne));
        stim2 = r.params.(sprintf('%sWeights', r.params.stimSpace))(:, strfind('RGB', r.params.coneTwo));
      end

      subtightplot(5,1,[1 3], 0.05, [0.05 0.05], [0.1 0.06]); hold on;
      plot(1:r.numEpochs, (-1 * sign(r.analysis.P1)) .* r.analysis.F1, '-ok', 'LineWidth', 1);
      plot([1 r.numEpochs], [0 0], 'Color', [0.5 0.5 0.5]);
      xlim([1 r.numEpochs]);
      ylabel('f1 amplitude');
      title([r.cellName ' - ' r.params.coneOne ' vs ' r.params.coneTwo ' color exchange (' num2str(r.params.temporalFrequency) ' hz ' r.params.temporalClass ')']);
      % subtightplot(5,1,3, 0.05, [0.05 0.05], [0.1 0.06]); hold on;
      % plot(1:r.numEpochs, r.analysis.P1, '-ok', 'LineWidth', 1);
      % set(gca, 'YLim', [-180 180], 'YTick', -180:180:180, 'XLim', [1 r.numEpochs]);
      % ylabel('f1 phase');
      subtightplot(5,1,[4 5],0.05, [0.05 0.05], [0.1 0.1]); hold on;
      plot(1:r.numEpochs, stim1', 'Color', getPlotColor(lower(r.params.coneOne)), 'LineWidth', 1);
      plot(1:r.numEpochs, stim2', 'Color', getPlotColor(lower(r.params.coneTwo)), 'LineWidth', 1);
      plot(1:r.numEpochs, (stim1-stim2)', '--', 'Color', getPlotColor(lower(r.params.coneOne), 0.5), 'LineWidth', 1);
      plot(1:r.numEpochs, (stim2-stim1)', '--', 'Color', getPlotColor(lower(r.params.coneTwo), 0.5), 'LineWidth', 1);
      plot(1:r.numEpochs, (stim1+stim2)', '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1);
      plot([1 r.numEpochs], [0 0], 'Color', [0.5 0.5 0.5]);
      legend(sprintf('%s only', r.params.coneOne), sprintf('%s', r.params.coneTwo), sprintf('%s - %s', r.params.coneOne, r.params.coneTwo), sprintf('%s - %s', r.params.coneTwo, r.params.coneOne));
      set(legend, 'Location', 'southoutside', 'FontSize', 10, 'Orientation', 'horizontal');
      xlim([1 r.numEpochs]);ylim([-1.5 1.5]);
      if strcmp(r.params.stimSpace, 'cone')
        ylabel('cone contrasts');
      else
        ylabel('led contrasts');
      end


    case 'edu.washington.riekelab.sara.protocols.FullChromaticGrating'
      f = fieldnames(r);
      ind = find(not(cellfun('isempty', strfind(f, 'deg'))));
      legendstr = cell(1, length(ind));
      for ii = 1:length(ind)
        legendstr{ii} = sprintf('%u%s', r.params.orientations(ii), char(176));
      end

      % group figure
      blankF1Fig;
      if length(r.params.orientations) > 1
        co = pmkmp(length(ind), 'cubicL'); coAvg = 'k';
        for ii = 1:length(ind)
          subplot(3,1,1:2); hold on;
          plot(r.params.SFs, r.analysis.F1(ii,:), '-o',...
            'Color', co(ii,:), 'LineWidth', 1);
          subplot(3,1,3); hold on;
          plot(r.params.SFs, r.analysis.P1(ii,:), '-o',...
            'Color', co(ii,:), 'LineWidth', 1);
        end
      else
        coAvg = getPlotColor(r.params.chromaticClass);
      end
      % add in the average
      subplot(3,1,1:2);
      plot(r.params.SFs, mean(r.analysis.F1,1), '-o',...
        'Color', coAvg, 'LineWidth', 1);
      set(gca, 'XScale', 'log', 'XColor', 'w', 'XTick', []); axis tight;
      ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));
      if length(r.params.orientations) > 1
        legend(legendstr, 'EdgeColor', 'w', 'FontSize', 8);
        title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' ' r.params.temporalClass ' grating series']);
      else
        title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' ' r.params.temporalClass ' grating at ' num2str(r.params.orientations) char(176)]);
      end
      subplot(3,1,3);
      plot(r.params.SFs, mean(r.analysis.P1, 1), '-o',...
        'Color', coAvg, 'LineWidth', 1);
      axis tight;
      set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
      set(findobj(gcf, 'Type', 'axes'), 'XScale', 'log', 'TickDir', 'out');

      %% graph the average alone
      if length(r.params.orientations) > 1
        blankF1Fig;
        subplot(3,1,1:2);
        errorbar(r.params.SFs, mean(r.analysis.F1,1), edu.washington.riekelab.sara.utils.sem(r.analysis.F1), '-o', 'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
        title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' ' r.params.temporalClass ' grating (average of ' num2str(length(r.params.orientations)) ' orientations)']);
        axis tight; ax = gca; ax.YLim(1) = 0;
        set(gca, 'XColor', 'w', 'XTickLabel', {});

        subplot(3,1,3);
        errorbar(r.params.SFs, mean(r.analysis.P1, 1), edu.washington.riekelab.sara.utils.sem(r.analysis.P1), '-o', 'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
        axis tight;
        set(gca, 'XScale', 'log', 'YLim', [-180 180], 'YTick', -180:90:180);
        set(findobj(gcf, 'Type', 'axes'), 'XScale', 'log');
      end


    case {'edu.washington.riekelab.manookin.protocols.ChromaticGrating',...
      'edu.washington.riekelab.sara.protocols.TempChromaticGrating'}
      figure;
      subplot(3,1,1:2); hold on;
      plot(r.params.spatialFrequencies, analysis.F1, 'o-', 'color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
      if strcmp(r.params.temporalClass, 'reversing')
        [c2, ~] = getPlotColor(r.params.chromaticClass, 0.5);
        plot(r.params.spatialFrequencies, analysis.F2, 'o-', 'color', c2, 'linewidth', 1);
        legend('f1', 'f2'); set(legend, 'edgecolor', 'w');
      end
      ax = gca; ax.XScale = 'log'; ax.XTick = {}; ax.Box = 'off';
      ylabel('f1 amplitude'); axis tight; ax.YLim = [0, ceil(max(analysis.F1))];
      foo = sprintf('%u%s', r.params.orientation, char(176));
      title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.temporalClass ' '...
        r.params.spatialClass ' grating at ' num2str(r.params.contrast*100) '% and ' foo]);
      set(gca, 'titlefontsize', 1);

      subplot(313); hold on;
      plot(r.params.spatialFrequencies, analysis.P1, 'o-','color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
      if strcmp(r.params.temporalClass, 'reversing')
        plot(r.params.spatialFrequencies, analysis.F2, 'o-', 'color', c2, 'linewidth', 1);
      end
      ax = gca; ax.XScale = 'log'; ax.Box = 'off';
      ylabel('f1 phase'); axis tight; ax.YLim = [-180 180]; ax.YTick = -180:90:180;
      xlabel('spatial frequencies');

    case 'edu.washington.riekelab.sara.protocols.ColorCircle'
      figure('Name', [r.cellName ' Color Circle Figure']);
      figPos(gcf, 0.8, 0.8)
      tmpF1 = r.analysis.F1;
      tmpF1([1 end]) = (r.analysis.F1(1) + r.analysis.F1(end))/2;

      try
        ax1 = polar(ax, deg2rad([r.params.orientations(1:end-1) 0]), tmpF1, '-o', 'Color', 'k', 'LineWidth', 1); hold on;
        if strcmp(r.params.temporalClass, 'squarewave')
          polar(deg2rad([r.params.orientations(1:end-1) 0]), r.analysis.F2, 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
      catch
        ax1 = polar(deg2rad([r.params.orientations(1:end-1) 0]), tmpF1);
        set(ax1, 'Color', 'k', 'LineWidth', 1); hold on;
        if strcmp(r.params.temporalClass, 'squarewave')
          ax2 = polar(deg2rad([r.params.orientations(1:end-1) 0]), r.analysis.F2);
          set(ax2, 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
      end
      view([90 -90]);
      switch r.params.recordingType
      case 'voltage_clamp'
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' at ' num2str(r.holding) r.holdingUnit ')']);
      otherwise
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' ' r.params.stimulusClass ')']);
      end
      tightfig(gcf);

      S = blankF1Fig;
      set(S.fh, 'Name', [r.cellName ' Color Circle F1P1 Figure']); hold on;
      figPos(gcf, 0.8, 0.8);
      plot(S.F1, r.params.orientations, r.analysis.F1, '-ok', 'LineWidth', 1);
      plot(S.P1, r.params.orientations, r.analysis.P1, '-ok', 'LineWidth', 1);
      if strcmp(r.params.temporalClass, 'squarewave')
        plot(S.F1, r.params.orientations, r.analysis.F2, '-o', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
        plot(S.P1, r.params.orientations, r.analysis.P2, '-o', 'LineWidth', 1, 'Color', [0.6 0.6 0.6]);
      end
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title(S.F1, [r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' at ' num2str(r.holding) r.holdingUnit ')']);
      else
        title(S.F1, [r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' ' r.params.stimulusClass ')']);
      end
      set(findobj(gcf, 'type', 'axes'), 'XLim', [0 360], 'XTick', 0:90:360);
      if r.params.coneWeights(1,1) > r.params.coneWeights(1,2)
        set(S.F1, 'XTickLabel', {'L-M', 'LM-S', 'M-L', 'LM-S'}, 'YLim', [0 S.F1.YLim(2)]);
      else
        set(S.F1, 'XTickLabel', {'M-L', 'S-LM', 'L-M', 'LM-S'}, 'YLim', [0 S.F1.YLim(2)]);
      end
      xlabel('Azimuth (degrees)');


      figure('Name', [r.cellName ' Color Circle F1 Figure']); hold on;
      figPos(gcf, 0.8, 0.8);
      plot(r.params.orientations, -1*sign(r.analysis.P1).*r.analysis.F1, '-ok', 'LineWidth', 1);
      if strcmp(r.params.temporalClass, 'squarewave')
        plot(r.params.orientations, -1*sign(r.analysis.P2).*r.analysis.F2, '-o', 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
      end
      plot([r.params.orientations(1) r.params.orientations(end)], [0 0], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8);
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' at ' num2str(r.holding) r.holdingUnit ')']);
      else
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' ' r.params.stimulusClass ')']);
      end
      % NOTE: this is for old color circle setup!
      set(gca, 'XLim', [0 360], 'XTick', 0:90:360, 'XTickLabel', {'L-M', 'S-LM', 'M-L', 'LM-S'});
      xlabel('Azimuth (degrees)');
      ylabel('F1 amplitude (spikes/sec)');
      tightfig(gcf);

      if strcmp(r.params.temporalClass, 'squarewave')
        figure('Name', [r.cellName ' Color Circle F1F2 Ratio Figure']); hold on;
        figPos(gcf, 0.6, 0.75);
        plot(r.params.orientations, r.analysis.F2 ./ r.analysis.F1, '-ok', 'LineWidth', 1);
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' ' r.params.stimulusClass ')']);
        set(gca, 'XLim', [0 360], 'XTick', 0:90:360, 'XTickLabel', {'L-M', 'S-LM', 'M-L', 'LM-S'});
        xlabel('Azimuth (degrees)');
        ylabel('F2/F1 ratio');
      end

      %% trace fig
      cdata = cycleData(r, 'numCycles', numCycles);
      figure('Name', [r.cellName ' - cycle average figure']); hold on;
      co = pmkmp(r.numEpochs, 'cubicL');
      for ii = 1:r.numEpochs
        plot(cdata.xpts, cdata.ypts(ii,:), 'LineWidth', 1, 'Color', co(ii,:));
      end
      set(gca, 'Box', 'off');
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' at ' num2str(r.holding) r.holdingUnit ')']);
      else
        title([r.cellName ' - color circle (' num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' ' r.params.stimulusClass ')']);
      end



    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      if r.params.radius < 1000
        titlestr = [r.cellName ' - ' num2str(r.params.contrast*100) '% '...
          num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' '...
          num2str(r.params.radiusMicrons*2) 'um spot'];
      else
        titlestr = [r.cellName ' - ' num2str(r.params.objectiveMag) 'x full-field ' num2str(r.params.contrast*100) '% ',...
          num2str(r.params.temporalFrequency) 'hz ' r.params.temporalClass ' spot'];
      end

      xpts = 1:(length(r.resp(1,:))); xpts = xpts / 10000;
      analysis.stimTrace = getStimTrace(r.params, 'modulation');
      if plotAll % plot each trial
        for jj = 1:(ceil(r.numEpochs/length(r.params.stimClass)))
          fig = figure('Name', sprintf('Trial %u Figure', jj)); hold on;
          figPos(gcf, 0.85,1.15);
          for ii = 1:length(r.params.stimClass)
            [c1, n] = getPlotColor(r.params.stimClass(ii));
            subtightplot((2*length(r.params.stimClass))+1, 1, [1+(2*(ii-1)):2+(2*(ii-1))], 0.05, [0.05 0.05], [0.1 0.06]);
            plot(xpts, squeeze(r.respBlock(ii, jj, :)), 'Color', c1);
            set(gca, 'box', 'off', 'TickDir', 'out'); axis tight;
            if ii ~= length(r.params.stimClass)
              set(gca, 'XColor', 'w', 'XTick', []);
            end
            if isempty(strfind(r.params.stimClass, 'lms'))
              legend(n); set(legend, 'EdgeColor', 'w');
            end
          end
          subtightplot((2*length(r.params.stimClass))+1, 1, [1 2], 0.05,[0.05 0.05], [0.1 0.06]);
          title(titlestr);
          subtightplot((2*length(r.params.stimClass))+3, 1, (2*length(r.params.stimClass)+3), 0.05, [0.05 0.05], [0.1 0.06]);
          plot(analysis.stimTrace, 'k', 'LineWidth', 1);
          set(gca, 'box', 'off', 'XColor', 'w', 'XTick', []);
          ylabel('contrast'); axis tight; ylim([0 1]);
        end
      end

      % graph PTSH for extracellular, mean resp for wholecell
      fig = figure();
      for ii = 1:length(r.params.stimClass)
        subtightplot((2*length(r.params.stimClass))+1, 1, [1+(2*(ii-1)):2+(2*(ii-1))], 0.05, [0.05 0.05], [0.1 0.06]);
        c1 = getPlotColor(r.params.stimClass(ii));
        if strcmp(r.params.recordingType, 'extracellular')
          bar(r.ptsh.(r.params.stimClass(ii)).binCenters/10e3,...
            r.ptsh.(r.params.stimClass(ii)).spikeCounts,...
            'FaceColor', c1, 'EdgeColor', 'k', 'LineStyle', 'none');
        else % voltage clamp
          xpts = 1:length(r.avgResp.(r.params.stimClass(ii))); xpts = xpts*10e-3;
          plot(xpts, r.avgResp.(r.params.stimClass(ii)), 'Color', c1, 'LineWidth', 0.8);
        end
        axis tight; set(gca, 'box', 'off', 'TickDir', 'out');
        if ii ~= length(r.params.stimClass)
          set(gca, 'XColor', 'w', 'XTick', []);
        end
        if ii == 1 % removed equal qcatch code as it hasn't been necessary in months
          switch r.params.recordingType
          case 'extracellular'
            set(gcf, 'Name', 'PTSH Figure');
            title(titlestr);
          case 'voltage_clamp'
            set(gcf, 'Name', 'Mean Response Figure');
            title([titlestr ' (' num2str(r.numEpochs) ' trials at ' num2str(r.holding) 'mV)']);
          end
        end
      end
      subtightplot((2*length(r.params.stimClass))+1, 1, (2*length(r.params.stimClass)+1), 0.05, [0.05 0.05], [0.1 0.06]);
      plot(analysis.stimTrace, 'k', 'LineWidth', 1); hold on;
      set(gca, 'box', 'off', 'XColor', 'w', 'XTick', []);
      ylabel('contrast'); axis tight; ylim([0 1]);
      figPos(gcf, 0.85,1); tightfig(gcf);

    switch r.params.recordingType
    case {'extracellular', 'current_clamp'}
      S = blankRespFig; figPos(S.fh, 0.85, 0.95);
      set(gcf, 'Name', 'Avg InstFt Figure');
      for ii = 1:length(r.params.stimClass)
        c = getPlotColor(r.params.stimClass(ii), [1 0.5]);
        % plot(xpts, squeeze(r.instFt(ii,:,:)), 'Color', c(2,:));
        plot(S.resp, xpts, mean(squeeze(r.instFt(ii,:,:))), 'Color', c(1,:), 'LineWidth', 1.5);
      end
      ylabel(S.resp, 'spikes/sec');
      title(S.resp, titlestr);
      plot(S.stim, analysis.stimTrace, 'k', 'LineWidth', 1);
      tightfig(gcf);
    case {'voltage_clamp'}
      S = blankRespFig;
      set(gcf, 'Name', 'Average Response Figure');
      for ii = 1:length(r.params.stimClass);
        plot(S.resp, xpts, r.avgResp.(r.params.stimClass(ii)),...
        'Color', getPlotColor(r.params.stimClass(ii)), 'LineWidth', 1);
      end
      set(S.resp, 'XLim', [xpts(1) xpts(end)]);
      title(S.resp, [titlestr ' (' num2str(ceil(size(r.resp,1)/length(r.params.stimClass)))...
        ' trials at ' num2str(r.holding) 'mV)']);
      plot(S.stim, analysis.stimTrace, 'k', 'LineWidth', 1);
    end

    case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
      figure('DefaultAxesLineWidth', 1, 'DefaultLineMarkerSize', 5);
      subplot(4,2,[1 3 5]); hold on;
      r.params.plotColor(1,:) = getPlotColor('l'); r.params.plotColor(2,:) = getPlotColor('m');
      plot(r.params.searchValues, analysis.redF1, '-o', 'Color', r.params.plotColor(1,:));
      if strcmp(r.params.temporalFrequency,'squarewave')
        subplot(4,2,[1 3 5]); hold on;
        plot(r.params.searchValues, analysis.redF2, '-o', 'Color', getPlotColor('l', 0.5));
        subplot(4,2,[2 4 6]); hold on;
        plot(r.params.searchValues, analysis.greenF2, '-o', 'Color', r.params.plotColor(2,:));
      end
      title(sprintf('red min = %.3f', analysis.redMin)); ylabel('f1 amplitude'); xlabel('red contrast');
      subplot(4,2,[2 4 6]); hold on;
      plot(r.params.searchValues, analysis.greenF1, '-o', 'Color', r.params.plotColor(2,:));
      title(sprintf('green min = %.3f', analysis.greenMin)); xlabel('green contrast');
      subplot(4,2,7); hold on;
      plot(r.params.searchValues, analysis.redP1, '-o', 'Color', getPlotColor('l'));
      if strcmp(r.params.temporalClass, 'squarewave')
        subplot(4,2,7); hold on;
        plot(r.params.searchValues, analysis.redP2, '-o', 'Color', r.params.plotColor(2,:));
        subplot(4,2,8); hold on;
        plot(r.params.searchValues, analysis.greenP2, '-o', 'Color', getPlotColor('m'));
      end
      ylabel('f1 phase');
      set(gca, 'YTick', -180:90:180, 'YLim', [-180 180], 'XColor', 'w', 'XTick', []);
      subplot(4,2,8); hold on;
      plot(r.params.searchValues, analysis.greenP1, '-o', 'Color', r.params.plotColor(2,:));
      set(gca, 'YTick', -180:90:180, 'YLim', [-180 180], 'XColor', 'w', 'XTick', []);

      figure();hold on;
      plot3(r.params.searchValues, zeros(size(r.params.searchValues)), analysis.greenF1,...
        '-o', 'Color', [0.1333 0.5451 0.1333]);
      plot3(analysis.greenMin*ones(size(r.params.searchValues)), r.params.searchValues, analysis.redF1,...
        '-o', 'Color', r.params.plotColor(1,:));
      grid on;
      xlabel('green contrast'); ylabel('red contrast'); zlabel('spikes/sec');
      set(gca, 'XTick', -1:0.2:1); set(gca, 'YTick', -1:0.2:1);

    case 'edu.washington.riekelab.protocols.PulseFamily'
      co = pmkmp(length(r.params.pulses), 'cubicL');
      figure(); subplot(3,1,1:2); hold on;
      xpts = (1:length(r.resp)) / r.params.sampleRate;
      for ii = 1:r.params.pulsesInFamily
        plot(xpts, (squeeze(mean(r.respBlock(ii,:,:),2))), 'color', co(ii,:));
      end
      set(gca, 'Box', 'off', 'TickDir', 'out', 'XTickLabel', {}, 'XColor', 'w');
      ylabel('mean response (mV)'); axis tight;
      xbound = get(gca, 'XLim');
      title([r.cellName ' - ' num2str(r.params.stimTime) 'ms pulse family (' num2str(size(r.respBlock,2)) ' trials)']);

      subplot(3,1,3); hold on;
      for ii = 1:r.params.pulsesInFamily
        plot(xpts, r.stim(ii,:), 'color', co(ii,:));
      end
      set(gca, 'Box', 'off', 'TickDir', 'out', 'XLim', xbound, 'YTick', [r.params.pulses(1) 0 r.params.pulses(end)]);
      ylabel('pulse (pA)'); xlabel('Time (s)');
      ylim([(r.params.pulses(1) - r.params.incrementPerPulse) (r.params.pulses(end) + r.params.incrementPerPulse)]);

      % make a stacked graph
      co = rgbmap('dark red', 'grey','dark green', r.params.pulsesInFamily);
      figure; fig = gcf;
      fig.Position(2) = fig.Position(2) - 300;
      fig.Position(4) = fig.Position(4) + 300;
      subplot(5,1,1:4); hold on;
      inc = -1 * min(squeeze(mean(r.respBlock(1,:,:), 2)));
      spacer =0.1 * (max(squeeze(mean(r.respBlock(ii-1,:,:), 2))) - min(squeeze(mean(r.respBlock(ii-1,:,:), 2))));
      plot(xpts, inc + squeeze(mean(r.respBlock(1,:,:),2)), 'Color', co(1,:));
      for ii = 2:r.params.pulsesInFamily
        yrange = max(squeeze(mean(r.respBlock(ii-1,:,:), 2))) - min(squeeze(mean(r.respBlock(ii-1,:,:), 2)));
        if r.params.pulses(ii-1) == 0
          inc = inc + yrange + 2 * spacer;
        else
          inc = inc + yrange + spacer;
        end
        plot(xpts, inc + squeeze(mean(r.respBlock(ii,:,:), 2)), 'color', co(ii,:));
      end
      set(gca, 'Box', 'off', 'TickDir', 'out', 'XTickLabel', {}, 'XColor', 'w');
      ylabel('mean response (mV)'); axis tight;
      ax = gca; ax.YLim(1) = 0;
      title([r.cellName ' - ' num2str(r.params.stimTime) 'ms pulse family (avg of ' num2str(size(r.respBlock,2)) ')']);

      subplot(5,1,5); hold on;
      for ii = 1:r.params.pulsesInFamily
        plot(xpts, r.stim(ii,:), 'color', co(ii,:));
      end
      set(gca, 'Box', 'off', 'TickDir', 'out', 'XLim', xbound, 'YTick', [r.params.pulses(1) 0 r.params.pulses(end)]);
      ylabel('pulse (pA)'); xlabel('Time (s)');
      ylim([(r.params.pulses(1) - r.params.incrementPerPulse) (r.params.pulses(end) + r.params.incrementPerPulse)]);

    case 'edu.washington.riekelab.manookin.protocols.GaussianNoise'
      sc = getPlotColor(r.params.chromaticClass, [1 0.5]);
      xpts = linspace(0, 1000, analysis.binRate);
      if ~isfield(r.analysis, 'NL')
        r.analysis.NL = r.analysis.nonlinearity;
      end
      if r.params.radius > 1000
        stimType = 'full field';
      else
        stimType = sprintf('%u radius', ceil(pix2micron(r.params.radius,r)));
      end

      % plot the linear filter
      figure('Name', [r.cellName ' - Linear Filter Figure']); hold on;
      figPos(gcf, 0.9, 0.8);
      plot(xpts, analysis.linearFilter/max(max(abs(analysis.linearFilter))), 'Color', sc(1,:), 'LineWidth', 1);
      plot([1 xpts(end)], zeros(1,2), 'Color', [0.5 0.5 0.5]);
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3) ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      else
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      end
      set(gca,'Box', 'off', 'TickDir', 'out');
      xlabel('time (msec)'); tightfig(gcf);

      % plot individual linear filters - removed 9Mar2017
      % plot both - mike format
      figure('Name', [r.cellName ' - LN model figure']);
      subplot(1,2,1); hold on;
      plot(xpts, analysis.linearFilter, 'Color', sc(1,:), 'LineWidth', 1);
      plot([1 xpts(end)], zeros(1,2), 'Color', [0.5 0.5 0.5]);
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3) ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      else
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      end
      xlabel('time (msec)'); ylabel('filter units'); xlim([1 500]);

      subplot(1,2,2); hold on;
      plot(analysis.NL.xBin, analysis.NL.yBin, '.', 'Color', sc(2,:));
      plot(analysis.NL.xBin, analysis.NL.fit, 'Color', sc(1,:), 'LineWidth', 1);
      axis tight; axis square;
      xlabel('generator'); ylabel('spikes/sec');
      set(findobj(gcf, 'Type', 'axes'), 'TickDir', 'out', 'Box', 'off');

      % temporal
      figure('Name', [r.cellName ' - temporal tuning curve']); hold on;
      figPos(gcf, 0.8, 0.8);
      plot(analysis.tempFT, 'color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
      title([r.cellName ' - ' r.params.chromaticClass ' temporal tuning (' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      set(gca, 'XLim', [0 r.params.frameRate]);
      ylabel('spikes/sec'); xlabel('frequency (hz)');
      tightfig(gcf);

    case 'edu.washington.riekelab.manookin.protocols.InjectNoise'
      % Plot the linear filter and nonlinearity
      figure();
      subplot(1,2,1);
      plot((1:r.analysis.plotLngth)/r.analysis.binRate, r.analysis.linearFilter(1:r.analysis.plotLngth), 'Color', 'k');
      axis tight; set(gca, 'Box', 'off', 'TickDir', 'out');
      title([r.cellName ' - max/min output: ', num2str(max(abs(r.analysis.yaxis(:))))]);

      subplot(1,2,2); axis tight; axis square;
      plot(r.analysis.xBin, r.analysis.yBin, 'Color', 'k', 'Marker', '.');
      set(gca, 'Box', 'off', 'TickDir', 'out');

      % 2nd plot
      figure();
      plot(r.analysis.tempFT, 'Color', 'k', 'LineWidth', 1);
      title([r.cellName]);
      xlabel('frequency (hz)');
      set(gca, 'Box', 'off', 'TickDir', 'out', 'XLim', [0 40]);

    case {'edu.washington.riekelab.protocols.Pulse',...
      'edu.washington.riekelab.manookin.protocols.ResistanceAndCapacitance'}

      S = blankRespFig(r.params.recordingType, 'inj');
      xpts = 1:size(r.resp,2); xpts = xpts*1e-4;
      plot(xpts, mean(r.resp,1), 'Color', 'k', 'LineWidth', 0.9, 'Parent', S.resp);
      title(S.resp, [r.cellName ' - ' num2str(r.stim.amplitude) ' ' r.stim.units ' pulse test at '...
        num2str(r.stim.mean) ' ' r.stim.units ' (average of' num2str(size(r.resp,1)) ' trials)']);
      plot(r.stim.trace, 'k', 'LineWidth', 1, 'Parent', S.stim); axis tight;
      ylabel(S.stim, sprintf('stim (%s)', r.stim.units)); xlabel(S.resp, '');


      S = blankRespFig(r.params.recordingType, 'inj');
      co = pmkmp(size(r.resp,1), 'cubicL');
      for ii = 1:size(r.resp,1)
        plot(xpts, r.resp(ii,:), 'Color', co(ii,:), 'Parent', S.resp);
      end
      title(S.resp, [r.cellName ' - ' num2str(r.stim.amplitude) ' ' r.stim.units ' pulse test at '...
        num2str(r.stim.mean) ' ' r.stim.units ' (' num2str(size(r.resp,1)) ' trials)']);
      plot(r.stim.trace, 'k', 'LineWidth', 1, 'Parent', S.stim); axis tight;
      ylabel(S.stim, sprintf('stim (%s)', r.stim.units)); xlabel(S.resp, '')
      if max(max(r.analog))  > 1000 || min(min(r.analog)) < 1000
        ylabel(S.resp, 'current (nA)');
        set(S.resp, 'YTickLabel', str2double(get(S.resp, 'YTickLabel'))/1000);
      end

      % plot(xpts, r.resp(ii,:), 'Color', 'k');

    case {'edu.washington.riekelab.sara.protocols.IsoSTC', 'edu.washington.riekelab.sara.protocols.IsoSTA'}
      switch r.params.paradigmClass
        case 'STA'
          if isempty(strfind(r.params.chromaticClass, 'RGB'))
            if isfield(analysis, 'nonlinearity')
              NL = analysis.nonlinearity;
            else
              NL = analysis.NL;
            end
          end
          xpts = linspace(0, 1000, analysis.binRate);
          if r.params.radius > 1000
            stimType = sprintf('%ux full field', r.params.objectiveMag);
          else
            stimType = sprintf('%u micron radius spot', ceil(pix2micron(r.params.radius, r)));
          end
          if ~isempty(strfind(r.params.chromaticClass, 'RGB'))
            r.params.plotColor = [0.82, 0, 0; 0, 0.53, 0.22; 0.14, 0.21, 0.84];
            figure; hold on;
            plot(xpts, analysis.linearFilter(1,:), 'color', r.params.plotColor(1,:), 'linewidth', 1);
            plot(xpts, analysis.linearFilter(2,:), 'color', r.params.plotColor(2,:), 'linewidth', 1);
            plot(xpts, analysis.linearFilter(3,:), 'color', r.params.plotColor(3,:), 'linewidth', 1);
            xlabel('msec'); ylabel('filter units'); ax = gca;
            ax.Box = 'off'; ax.TickDir = 'out'; ax.YLim(1) = 0;
            title([r.cellName ' - RGB binary noise ' stimType]);

            figure; hold on;
            foo = max(max(analysis.linearFilter));
            for ii = 1:3
              newLF(ii,:) = (analysis.linearFilter(ii,:) - min(analysis.linearFilter(ii,:)))/(max(analysis.linearFilter(ii,:))- min(analysis.linearFilter(ii,:)));
              newLF(ii,:) = newLF(ii,:) * max(analysis.linearFilter(ii,:))/max(foo);
            end

            for ii = 1:length(analysis.linearFilter)
              rectangle('Position', [ii-1, 0, 1, 1],... 
                'FaceColor', newLF(:,ii), 'EdgeColor', newLF(:,ii));
            end
            ax=gca; ax.Box = 'off'; xlabel('msec'); ax.YColor = 'w'; ax.YTickLabel = [];
            if r.params.radius > 1000
      	      stimType = sprintf('full-field, %ux', r.params.objectiveMag);
            else
      	      stimType = sprintf('%u micron spot', ceil(pix2micron(r.params.radius, r)));
            end

            title([r.cellName ' - chromatic temporal receptive field (' stimType ')']);
            set(gca, 'TitleFontSize', 1);
          else
            figure('Name', 'Filter + Nonlinearity');
            [c,~] = getPlotColor(r.params.chromaticClass, [1 0.5]);
            subplot(1,2,1); hold on;
            plot(xpts, analysis.linearFilter, 'Color', c(1,:), 'LineWidth', 1); hold on;
            plot([0 xpts(end)], zeros(1,2), 'Color', [0.5 0.5 0.5]);
            if strcmp(r.params.recordingType, 'voltage_clamp')
              titlestr = [r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3)...
                ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)'];
            else
              titlestr = [r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev)...
                ' sd, ' stimType ')'];
            end
            title(titlestr);
            set(gca,'Box', 'off', 'TickDir', 'out');
            xlabel('msec'); ylabel('filter units'); xlim([0 500]);

            subplot(1,2,2); hold on;
            plot(NL.xBin, NL.yBin, '.', 'color', c(2,:));
            plot(NL.xBin, NL.fit, 'color', c(1,:), 'linewidth', 1);
            axis tight; axis square;
            xlabel('generator'); ylabel('spikes/sec');
            set(gca,'tickdir', 'out', 'box', 'off');

            figure('Name', 'Linear Filter');
            figPos(gcf, 0.9,0.8); hold on;
            plot(xpts, analysis.linearFilter/max(abs(analysis.linearFilter)), 'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
            plot([0 xpts(end)], zeros(1,2), 'Color', [0.5 0.5 0.5]);
            set(gca, 'Box', 'off', 'TickDir', 'out');
            xlabel('msec'); title(titlestr); tightfig(gcf);

            % temporal
            figure ('Name', 'FFT of Linear Filter'); hold on;
            figPos(gcf, 0.8,0.8);
            plot(analysis.tempFT, 'color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
            title([r.cellName ' - ' r.params.chromaticClass ' temporal tuning (' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
            set(gca, 'XLim', [0 60]);
            ylabel('spikes/sec'); xlabel('time (ms)');
          end
        case 'ID'
         if r.numEpochs > 1
           figure; hold on;
           c2 = getPlotColor(r.params.chromaticClass,0.6);
           for ii = 1:r.numEpochs
             plot(abs(analysis.f1phase(ii)), abs(analysis.f1amp(ii)), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
           end
           plot(mean(abs(analysis.f1phase),2), mean(abs(analysis.f1amp), 2), 'o', 'MarkerFaceColor', getPlotColor(r.params.chromaticClass), 'MarkerEdgeColor', getPlotColor(r.params.chromaticClass));
           title([r.cellName ' - ' r.params.chromaticClass ' spot - ' num2str(ceil(r.params.radiusMicrons)) 'um, '...
              r.params.temporalClass ' at ' num2str(r.params.temporalFrequency) ' hz']);
           xlabel('f1 phase'); ylabel('f1amp'); xlim([0 180]);
           ax = gca; ax.YLim(1) = 0;
         else
           fprintf('F1amp is %.3f and F1phase is %.3f\n', analysis.meanAmp, analysis.meanPhase);
         end

         r.params.stimTrace = getStimTrace(r.params, 'modulation');

         % plot PTSH
        S = blankRespFig('ptsh');
        bar(analysis.ptsh.binCenters*10e-3, analysis.ptsh.spikeCounts,...
          'Parent', S.resp,...
          'FaceColor', getPlotColor(r.params.chromaticClass), 'EdgeColor', 'k', 'LineStyle', 'none');
        title(S.resp, [r.cellName ' - ' r.params.chromaticClass ' spot - ' num2str(ceil(r.params.radiusMicrons)) ' um, '...
          r.params.temporalClass ' at ' num2str(r.params.temporalFrequency) ' hz']);

        plot(r.params.stimTrace, 'Parent', S.stim, 'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);

         % plot response
         if r.numEpochs == 1
           figure; set(gcf,'color', 'w');
           subplot(3,1,1:2); hold on;
           plot(r.resp); axis tight;
           set(gca, 'box', 'off', 'tickdir', 'out');
           subplot(3,1,3); hold on;
           plot(r.params.stimTrace, 'color', getPlotColor(r.params.chromaticClass));
           set(gca,'box','off', 'tickdir', 'out', 'xcolor', 'w', 'xticklabel', []);
         end
       end

    case 'edu.washington.riekelab.manookin.protocols.SpatialNoise'
      figure;
      imagesc('XData', r.params.xaxis, 'YData', r.params.yaxis, 'CData', analysis.spatialRF);
      if strcmp(r.params.chromaticClass, 'achromatic')
        colormap(bone);
      end
      axis tight; axis equal;
      title([r.cellName ' ' r.params.chromaticClass ' spatial receptive field']);

      % also plot in pixels... makes it easier for pixelSTA stuff
      figure;
      imagesc(analysis.spatialRF);
      axis tight; axis equal;
      if strcmp(r.params.chromaticClass, 'achromatic')
        colormap(bone);
      end
      title([r.cellName ' ' r.params.chromaticClass ' spatial receptive field']);

    case 'edu.washington.riekelab.sara.protocols.ConeTestGrating'
      % plot by orientation
      titlestr = [r.cellName ' - drifting gratings at ' num2str(r.params.spatialFrequency) 'hz'];
      S = blankF1Fig;
      tmpF1 = reshape(r.analysis.F1, 4, length(r.params.orientations));
      tmpP1 = reshape(r.analysis.P1, 4, length(r.params.orientations));

      for ii = 1:4
        plot(S.F1, r.params.orientations, r.analysis.F1(ii:4:end), '-o',...
          'Color', getPlotColor(r.params.chromInd(ii)), 'LineWidth', 1);
        plot(S.P1, r.params.orientations, r.analysis.P1(ii:4:end), '-o',...
          'Color', getPlotColor(r.params.chromInd(ii)), 'LineWidth', 1);
      end
      xlabel(S.P1, 'grating orientation');
      title(S.F1, titlestr);
      figPos(S.fh, 0.7,0.7); tightfig(gcf);

      fh = figure; hold on; 
      for ii = 1:4
        plot(r.params.orientations, sign(r.analysis.P1(ii:4:end)).*r.analysis.F1(ii:4:end),... 
          '-o', 'Color', getPlotColor(r.params.chromInd(ii)), 'LineWidth', 1);
      end
      plot(r.params.orientations, zeros(size(r.params.orientations)), '--', 'Color', [0.5 0.5 0.5]);
      title(titlestr);
      xlabel('grating orientation'); ylabel('f1 amplitude');
      tightfig(fh); figPos(fh, 0.85, 0.9);

      theta = deg2rad(r.params.orientations);
      fH = figure('Color', 'w');
      lh = mmpolar(theta, tmpF1);

      mmpolar('TLim', [theta(1) theta(end)]);
      mmpolar('RGridLineWidth', 0.2, 'TGridLineWidth', 0.2, 'FontSize', 11);
      set(lh, 'LineWidth', 1.2, 'Marker', 'o');
      for ii = 1:4
        set(lh(ii), 'Color', getPlotColor(r.params.chromInd(ii)));
      end

      tmpF1 = repmat(tmpF1, [1 2]); tmpF1(:,end + 1) = tmpF1(:, 1);
      theta = [theta theta+pi 0];

      lh2 = mmpolar(theta, tmpF1); 
      mmpolar('RTickOffset', 0.08, 'TTickOffset', 0.12,...
        'RGridLineWidth', 0.2, 'TGridLineWidth', 0.2, 'FontSize', 11);
      set(lh2, 'LineWidth', 1.2, 'Marker', 'o');
      for ii = 1:4
        set(lh2(ii), 'Color', getPlotColor(r.params.chromInd(ii)));
      end

    case 'edu.washington.riekelab.manookin.protocols.LMIsoSearch'
      titlestr = [r.cellName ' - ' r.params.chromaticClass ' search test'];
      if isfield(r.params, 'temporalFrequency')
        cdata = cycleData(r);


        if strcmp(lower(r.params.chromaticClass), 'l-iso')
          co = rgbmap('grey', 'greenish', 'dark green', size(cdata.ypts,1));
          xaxis = 'green led contrast'; led = 'm';
          staticLED = 1; searchLED = 2; % TODO: clean this all up
        else
          co = rgbmap('grey', 'light red', 'dark red', size(cdata.ypts,1));
          xaxis = 'red led contrast'; led = 'l';
          staticLED = 2; searchLED = 1;
        end
        for ii = 1:40
          r.analysis.phaseOne(ii) = sum(cdata.ypts(ii,1:length(cdata.ypts)/2));
          r.analysis.phaseTwo(ii) = sum(cdata.ypts(ii,length(cdata.ypts)/2 + 1:end));
        end
        led = 'k';

        fh = figure('Name', [r.cellName ' - firing rate area']); hold on;
        plot(r.params.searchValues, r.analysis.phaseTwo, '-o',...
          'Color', getPlotColor(led), 'LineWidth', 1);
        plot(r.params.searchValues, r.analysis.phaseOne, '-o',...
          'Color', getPlotColor(led, 0.5), 'LineWidth', 1);
        legend('phase one', 'phase two');
        set(legend, 'FontSize', 10, 'Location', 'northwest');
        title(titlestr); xlabel(xaxis); ylabel('firing rate sum');
        figPos(gcf, 0.81, 0.8); tightfig(gcf);

        S = blankF1Fig;
        plot(S.F1, r.params.searchValues, r.analysis.F1, '-o',...
          'Color', getPlotColor(led), 'LineWidth', 1);
        plot(S.F1, r.params.searchValues, r.analysis.F2, '-o',...
          'Color', getPlotColor(led, 0.5), 'LineWidth', 1);
        plot(S.P1, r.params.searchValues, r.analysis.P1, '-o',...
          'Color', getPlotColor(led), 'LineWidth', 1);
        plot(S.P1, r.params.searchValues, r.analysis.P2, '-o',...
          'Color', getPlotColor(led, 0.5), 'LineWidth', 1);
        title(S.F1, titlestr); xlabel(S.P1, xaxis);
        leg = legend(S.F1, 'f1', 'f2'); 
        set(leg, 'FontSize', 10, 'Location', 'northwest');
        figPos(S.fh, 0.9, 0.95); tightfig(gcf);


        S = blankRespFig;
        for ii = 1:size(cdata.ypts,1)
          plot(S.resp, cdata.xpts, cdata.ypts(ii,:),... 
            'Color', co(ii,:), 'LineWidth', 1);
        end

        r.stim.searchLED = zeros(size(cdata.ypts));
        r.stim.staticLED = zeros(1, size(cdata.ypts, 2));
        r.stim.staticLED(1, floor(length(cdata.ypts)/2+1:end)) = -1 * r.params.ledWeights(1,staticLED);
        r.stim.staticLED(1, 1:floor(length(cdata.ypts))/2) = r.params.ledWeights(1,staticLED);

        for ii = 1:size(cdata.ypts, 1)
          r.stim.searchLED(ii, 1:floor(length(cdata.ypts))/2) = r.params.ledWeights(ii,searchLED);
          r.stim.searchLED(ii, floor(length(cdata.ypts)/2)+1:end) = -1 * r.params.ledWeights(ii,searchLED);
          plot(S.stim, r.stim.searchLED(ii,:), 'Color', co(ii,:), 'LineWidth', 0.9);
        end
       
        plot(S.stim, r.stim.staticLED,... 
          'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);

        set(S.stim, 'XLim', [0 length(r.stim.staticLED)], 'YLim', [-1 1]);
        xlabel(S.resp, 'time (sec)'); ylabel(S.resp, 'spikes/sec');
        xlabel(S.stim, ''); ylabel(S.stim, sprintf('%s\n%s', 'led', 'contrast'));
        title(S.resp, titlestr);
        figPos(S.fh, 0.85, 0.95); tightfig(S.fh);


      else


        figure('Name', [r.cellName ' - Spike Count Figure'] ,'Color', 'w'); hold on;
        plot(r.params.searchValues, r.analysis.spikeNum(:,1), '-o', 'Color', [0.5 0.5 0.5]);
        plot(r.params.searchValues, r.analysis.spikeNum(:,2), '-o', 'Color',  getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
        plot(r.params.searchValues, r.analysis.spikeNum(:,3), '-o', 'Color', getPlotColor(r.params.chromaticClass, 0.5), 'LineWidth', 1);

        title(titlestr);
        ylabel('spike count');
        legend('baseline', 'onset', 'offset');
        set(legend, 'FontSize', 10, 'EdgeColor', 'w');

        if strcmp(r.params.chromaticClass, 'l-iso')
          xlabel('red led values');
        else
          xlabel('green led values');
        end
        figPos(gcf, 0.95, 0.95); tightfig(gcf);

        instBlock = squeeze(mean(getInstFt(r.spikeBlock), 2));
        % co = pmkmp(size(instBlock,1), 'CubicL');
        co = rgbmap('grey', 'green', 'dark red');

        S = blankRespFig;
        for ii = 1:size(instBlock,1)
          plot(S.resp, linspace(0, length(r.resp), length(instBlock))/10000, instBlock(ii,:),... 
            'Color', co(ii,:), 'LineWidth', 0.9);
        end
        r.params.contrast = 1;
        plot(S.stim, getStimTrace(r.params, 'pulse'), 'k', 'LineWidth', 1);
        r.params = rmfield(r.params, 'contrast'); % hack fix later
        ylabel(S.resp, 'spikes/sec'); xlabel(S.resp, 'time (sec)'); xlabel(S.stim, '');
        title(S.resp, titlestr);
        figPos(S.fh, 0.85, 0.95); tightfig(S.fh);
      end

    case {'edu.washington.riekelab.manookin.protocols.BarCentering',...
            'edu.washington.riekelab.sara.protocols.BarCentering'}
      if ~isfield(analysis, 'F1')
        analysis = makeCompatible(analysis, 'f1');
      end

      figure('Name', [r.cellName ' - Bar Centering F1F2 Figure']);
      figPos(gcf, 0.8, 0.8);
      c2 = getPlotColor(r.params.chromaticClass, 0.6);
      posMicron = r.params.positions * r.params.micronsPerPixel;
      posMicron = posMicron(1:r.numEpochs);
      if ~strcmp(r.params.chromaticClass, 'achromatic')
        tmp = [r.params.chromaticClass ' '];
      else
        tmp = [];
      end
      titlestr = [r.cellName ' - ' tmp r.params.searchAxis(1) '-axis',...
        ' bar (' num2str(r.params.temporalFrequency) 'hz '];
      subplot(3,1,1:2); hold on;
      if ~strcmp(r.params.temporalClass, 'squarewave')
        plot(posMicron, analysis.F1, '-o', 'LineWidth', 1, 'Color', getPlotColor(r.params.chromaticClass));
        titlestr = [titlestr 'sqrwave']; ylabel('F1 amplitude');
      else
        titlestr = [titlestr r.params.temporalClass]; ylabel('F2/F1 ratio');
        plot(posMicron, analysis.F2./analysis.F1, '-o', 'LineWidth', 1, 'Color', getPlotColor(r.params.chromaticClass));
      end
      if strcmp(r.params.recordingType, 'voltage_clamp') && isfield(r, 'holding')
        titlestr = [titlestr ' at ' num2str(r.holding) 'mV)'];
      else
        titlestr = [titlestr ' ' num2str(ceil(pix2micron(r.params.barSize(1),r))) ' x '...
        num2str(ceil(pix2micron(r.params.barSize(2),r))) 'um)'];
      end
      title(titlestr);
      tmp = xlabel('bar position (microns)'); set(tmp, 'FontSize', 10);
      ax = gca; axis tight; ax.YLim(1) = 0;
      set(gca, 'Box', 'off', 'TickDir', 'out');

      subplot(9,1,8:9); hold on;
      plot(posMicron, analysis.P1, '-o', 'Linewidth', 1, 'Color', getPlotColor(r.params.chromaticClass));
      axis tight; ylim([-180 180]); ylabel('f1 phase');
      set(gca,'box', 'off','YTick', -180:90:180, 'TickDir', 'out', 'XColor', 'w', 'XTick', [], 'XTickLabel', {});

      if strcmp(r.params.temporalClass, 'squarewave')
        S2 = blankF1Fig;
        set(S2.fh, 'Name',[r.cellName ' - Bar Centering Figure']);
        plot(S2.F1, posMicron, analysis.F1, '-o',... 
          'LineWidth', 1, 'Color', getPlotColor(r.params.chromaticClass));
        plot(S2.F1, posMicron, analysis.F2, '-o',... 
          'Linewidth', 1, 'Color', getPlotColor(r.params.chromaticClass, 0.5));
        legend(S2.F1, 'f1', 'f2'); set(legend, 'EdgeColor', 'w');
        tmp = xlabel('bar position (microns)'); set(tmp, 'FontSize', 10);
        title(S2.F1, titlestr);

        plot(S2.P1, posMicron, analysis.P1, '-o',... 
          'LineWidth', 1, 'Color', getPlotColor(r.params.chromaticClass));
        plot(S2.P1, posMicron, analysis.P2, '-o',... 
          'LineWidth', 1, 'Color', getPlotColor(r.params.chromaticClass, 0.5));
        figPos(gcf, 0.85, 0.85);
      end

      S = blankF1Fig;
      plot(S.F1, posMicron, r.analysis.F1 ./ r.analysis.F2, '-o',... 
        'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
      plot(S.P1, posMicron, r.analysis.P1, '-o',...
        'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
      title(S.F1, titlestr);
      ylabel(S.F1, 'F1/F2 amplitude'); 
      tmp = xlabel(S.F1, 'bar position (microns)');
      set(tmp, 'FontSize', 10);
      figPos(gcf, 0.85, 0.85); tightfig(gcf);

    case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'
      xaxis = unique(r.params.contrasts);
      S = blankF1Fig;
      set(S.fh, 'Name', [r.cellName ' - contrast response spot']);
      for ii = 1:r.numEpochs
        plot(S.F1, r.params.contrasts(ii), analysis.F1(ii), 'o',... 
          'MarkerFaceColor', getPlotColor(r.params.chromaticClass, 0.5),... 
          'MarkerEdgeColor', getPlotColor(r.params.chromaticClass, 0.5));
      end
      plot(S.F1, xaxis, analysis.avgF1, '-o',... 
        'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
      S.F1.YLim(1) = 0; 
      S.F1.XLim = [0 max(xaxis)];

      if strcmp(r.params.chromaticClass, 'achromatic')
        cone = [];
      else
        cone = [r.params.chromaticClass ' '];
      end
      titlestr = [r.cellName ' - ' cone 'contrast response spot ('];
      if r.params.radius >= 1000
        title(S.F1, [titlestr num2str(r.params.objectiveMag) 'x full-field)']);
      else
        title(S.F1, [titlestr num2str(round(pix2micron(r.params.radius,r))) ' radius)']);
      end

      for ii = 1:r.numEpochs
        plot(S.P1, r.params.contrasts(ii), analysis.P1(ii), 'o',... 
          'MarkerFaceColor', getPlotColor(r.params.chromaticClass, 0.5),... 
          'MarkerEdgeColor', getPlotColor(r.params.chromaticClass, 0.5));
      end
      plot(S.P1, xaxis, analysis.avgP1, '-o',... 
        'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
      S.P1.XLim =S.F1.XLim;
      figPos(S.fh, 0.85, 0.85);

    case {'edu.washington.riekelab.manookin.protocols.sMTFspot',...
            'edu.washington.riekelab.sara.protocols.sMTFspot'}
      S = blankF1Fig;

      semilogx(S.F1, pix2micron(r.params.radii,r), analysis.F1, 'o-',...
        'color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
      title(S.F1, [r.cellName ' - ' num2str(100*r.params.contrast) '% ',... 
        r.params.chromaticClass ' ' r.params.stimulusClass ' ' r.params.temporalClass ' sMTF']);
      semilogx(S.P1, pix2micron(r.params.radii,r), analysis.P1, 'o-',... 
        'color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
      figPos(gcf, 0.85, 0.85);

      % if strcmp(r.params.temporalClass, 'squarewave')
        S2 = blankF1Fig;
        semilogx(S2.F1, pix2micron(r.params.radii,r), analysis.F1, 'o-',... 
          'Color', getPlotColor(r.params.chromaticClass), 'LineWidth', 1);
        semilogx(S2.F1, pix2micron(r.params.radii,r), analysis.F2, 'o-',... 
          'Color', getPlotColor(r.params.chromaticClass,0.5), 'LineWidth', 1);
        title(S2.F1, [r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass,... 
          'squarewave ' r.params.stimulusClass ' sMTF']);
        leg2 = legend(S2.F1, 'f1', 'f2');
        set(leg2, 'EdgeColor', 'w', 'FontSize', 10);
        semilogx(S2.P1, pix2micron(r.params.radii,r), analysis.P1, 'o-',... 
          'color', getPlotColor(r.params.chromaticClass), 'linewidth', 1);
        semilogx(S2.P1, pix2micron(r.params.radii,r), analysis.P2, 'o-',... 
          'color', getPlotColor(r.params.chromaticClass, 0.5), 'linewidth', 1);     
        figPos(gcf, 0.85, 0.85);
      % end

      % add in the fit
      if isfield(analysis, 'f1Fit')
        if strcmp(r.params.chromaticClass, 'achromatic')
          c2 = 'b';
        else
          c2 = 'k';
        end
        semilogx(S.F1, pix2micron(r.params.radii,r), analysis.f1Fit.fit, '--',...
            'Color', c2, 'LineWidth', 1);
        if strcmp(r.params.stimulusClass, 'spot')
          semilogx(S.F1, pix2micron(r.params.radii,r), analysis.f1Fit.offset.fit,... 
              '.-', 'Color', c2, 'LineWidth', 1);
        end
      end


    case 'edu.washington.riekelab.manookin.protocols.GliderStimulus'
      figure(); hold on;
      co = pmkmp(length(r.params.stimuli), 'cubicL');
      xpts = linspace(1, (r.params.stimTime + r.params.tailTime)*10, r.analysis.binRate);
      xpts = xpts/r.params.sampleRate;
      for ii = 1:size(r.analysis.binAvg,1)
        plot(r.analysis.binAvg(ii,:), 'Color', co(ii,:));
      end
      assignin('base', 'xpts', xpts);
      legend(r.params.stimuli);
      set(legend, 'EdgeColor', 'w', 'FontSize', 9);
      set(gca, 'Box', 'off', 'TickDir', 'out');
      if r.params.innerRadius ~= 0
        r.params.stimFocus = sprintf('surround - %u micron annulus', round(r.params.innerRadiusMicrons));
      else % no inner radius
        if r.params.outerRadius >= 1500
          r.analysis.stimFocus = 'full-field';
        else
          r.analysis.stimFocus = sprintf('center - %u micron radius', round(r.params.outerRadiusMicrons));
        end
      end
      title([r.cellName ' - glider stimulus (' num2str(r.params.objectiveMag) 'x, ' r.analysis.stimFocus ')']);

      figure(); fig = gcf;
      fig.Position(2) = fig.Position(2) - 300; fig.Position(4) = fig.Position(4) + 300;
      fig.Units = 'normalized';
      for ii = 1:size(r.analysis.binAvg, 1)
        subtightplot(size(r.analysis.binAvg, 1), 1, ii, 0.03, [0.05 0.05], [0.1 0.06]);
        plot(r.analysis.binAvg(ii,:), 'Color', co(ii,:), 'LineWidth', 1);
        legend(r.params.stimuli{ii});
        set(legend, 'EdgeColor', 'w', 'FontSize', 10);
        if ii < size(r.analysis.binAvg)
          set(gca, 'XColor', 'w', 'XLabel', [], 'XTickLabel', {});
        end
        if ii == 1
          title([r.cellName ' - glider stimulus (' num2str(r.params.objectiveMag) 'x, ' r.analysis.stimFocus ')']);
        end
        axis tight;  % round YLim to nearest 10s
        set(gca, 'YLim', [0 round(max(max(r.analysis.binAvg)), -1)], 'Box', 'off', 'TickDir', 'out');
      end

    case 'edu.washington.riekelab.manookin.protocols.MovingBar'
      switch cmap
        case 'pmkmp'
          co = pmkmp(length(r.params.orientations)/2, 'cubicL');
        case 'virindis'
          co = virindis(length(r.params.orientations)/2);
        case 'hsv'
          co = hsv(length(r.params.orientations)/2);
      end
        
      co = [co; flipud(co)];
      cp = co - (0.4*(1-co)); cp(cp < 0) = 0;
      xpts = (1:size(r.respBlock, 3)) / r.params.sampleRate;

      % instft or analog plot
      figure('Name', [r.cellName ' - Moving bar firing rate']); hold on;
      switch r.params.recordingType
      case 'extracellular'
        for ii = 1:size(r.respBlock,1)
          plot(xpts, smooth(squeeze(mean(r.instFt(ii, :, :), 2)), 4),... 
            'Color', co(ii,:), 'LineWidth', 1.5);
          legendstr{ii} = sprintf('%u%s', (30*ii)-30, char(176));
        end
      case 'voltage_clamp'
        for ii = 1:size(r.respBlock, 1)
          plot(xpts, squeeze(mean(r.analogBlock(ii,:,:), 2)),... 
            'Color', co(ii,:), 'LineWidth', 1);
          legendstr{ii} = sprintf('%u%s', (30*ii)-30, char(176));
        end
      end
      legend(legendstr);
      set(legend, 'EdgeColor', 'w', 'FontSize', 10);
      title([r.cellName sprintf(' moving bar avg firing rate (%u% at %.1f mean)',...
        round(100*r.params.intensity), r.params.backgroundIntensity)]);

      figure;
      for jj = 1:size(r.respBlock, 1)
        subplot(size(r.respBlock,1), 1, jj); hold on;
        if plotAll
          for ii = 1:size(r.respBlock,2)
            plot(xpts, squeeze(r.instFt(jj,ii,:)),...
              'Color', cp(jj,:), 'LineWidth', 1);
          end
        end
        plot(xpts, squeeze(mean(r.instFt(jj,:,:))),...
          'Color', co(jj,:), 'LineWidth', 1);
        ylabel(sprintf('%u%s     ', (30*jj) - 30, char(176)),...
          'Rotation', 0, 'VerticalAlignment', 'middle');
        ylim([0 max(max(max(r.instFt)))]);
        if jj ~= size(r.respBlock, 1)
          set(gca, 'XColor', 'w', 'XTick', []);
        end
      end
      set(findobj(gcf, 'Type', 'axes'), 'YTickLabel', [],... 
        'XLim', [0 length(r.resp)/r.params.sampleRate]);
      subplot(size(r.respBlock, 1), 1, 1);
      title(sprintf('%s - moving bar (%u%s on %.1f mean)',... 
        r.cellName, round(100*r.params.intensity), '%', r.params.backgroundIntensity));
      figPos(gcf, 0.8, 1); tightfig(gcf);

      % NOTE temporary
      prePts = r.params.preTime*1e-3*r.params.sampleRate;
      stimPts = r.params.stimTime*1e-3*r.params.sampleRate;
      r.analysis.DI = zeros(1,size(r.spikeBlock,1));
      for ii = 1:size(r.spikeBlock, 1)
        r.analysis.DI(ii) = mean(squeeze(sum(r.spikeBlock(ii, :, prePts : prePts+stimPts))));
      end
      polarloop(r.params.orientations, r.analysis.DI, '-ok');
      title(sprintf('%s - moving bar (%u%s on %.1f mean)', r.cellName, round(100*r.params.intensity), '%', r.params.backgroundIntensity));
      set(gcf,'Name', [r.cellName ' Direction Figure']);
      figPos(gcf,0.8,0.8); tightfig(gcf);

      figure('Color', 'w', 'Name', sprintf('%s - moving bar firing rate', r.cellName));
      imagesc(squeeze(mean(r.instFt, 2)));
      title([r.cellName ' - moving bar firing rate']);
      set(gca, 'XTickLabel', get(gca, 'XTick')/r.params.sampleRate,...
        'YTick', 1:2:length(r.params.orientations),... 
        'YTickLabel', 0:length(r.params.orientations)/2:max(r.params.orientations));
      axis off; tightfig(gcf);

      figure('Color', 'w', 'Name', [r.cellName ' - firing rate polar plot']);
      polarplot3d(squeeze(mean(r.instFt, 2))', 'AxisLocation', 'off');
      title([r.cellName ' - moving bar firing rate']);
      tightfig(gcf);

      if plotAll
        for jj = 1:size(r.respBlock, 2)
          figure('Color', 'w', 'Name', sprintf('moving bar trial %u (%u% at %.1f mean)',...
          jj, round(100*r.params.intensity), r.params.backgroundIntensity));
          for ii = 1:size(r.respBlock, 1)
            subplot(size(r.respBlock, 1), 1, ii); hold on;
            plot(xpts, squeeze(r.respBlock(ii, jj, :)), 'Color', co(jj*2, :));
            set(gca, 'Box', 'off', 'TickDir', 'out', 'YTick', []); axis tight;
            ylabel(sprintf('%u%s     ', (30*ii) - 30, char(176)),...
              'Rotation', 0, 'VerticalAlignment', 'middle');
            if ii ~= size(r.respBlock, 1)
              set(gca, 'XColor', 'w', 'XTickLabel', {}, 'XTick', []);
            else
              xlabel('time (sec)');
            end
            if ii == 1
              title([r.cellName ' - moving bar stimulus (trial ' num2str(jj) ')']);
            end
          end
          figPos(gcf, 0.8, 1);
          set(findall(gcf, 'Type', 'axes'), 'XLim', [0 length(r.resp)/r.params.sampleRate]);
        end
      end

    case 'edu.washington.riekelab.manookin.protocols.OrthographicAnnulus'
      co = pmkmp(r.numEpochs, 'cubicL');
      figure; hold on;
      for ii = 1:r.numEpochs
        plot(r.analysis.binnedData(ii,:), 'Color', co(ii,:), 'LineWidth', 1);
      end
      % plot(r.analysis.binAvg, 'Color', 'k', 'LineWidth', 1);
      title([r.cellName ' - ' num2str(r.params.intensity(1)) '% ' r.params.direction{1} ' orthographic annulus']);
      ylabel('current (pA)'); xlabel('time (msec)');
      set(gca, 'XLim', [1 length(r.analysis.binAvg)]);

end % protocol switch

  if ~isempty(bkgd)
    colordef white;
    set(0, 'DefaultFigureColor', 'w');
  end

  if nargout == 1
    r.log{end+1} = ['graphDataOnline at ' datestr(now)];
  end

  if neuron == 2
    r.cellName = r.cellName(1:end-1);
  end
end
