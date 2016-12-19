function r = graphDataOnline(r, neuron, graphType)
  % optional 2nd input, can be anything - will run off 2nd neuron
  % for chromatic spot, input r.data
  % INPUTS: graphType = 'minimal' for onoffline so a bunch of figures don't popup, 'full' for offline

  if nargin == 2
    graphType = 'full';
    if neuron == 2 && isfield(r, 'protocol') % not for chromatic spot yet
        analysis = r.secondary.analysis;
        r.cellName = [r.cellName '*'];
    end
  elseif nargin == 1
    graphType = 'full';
    neuron = 1;
    if isfield(r, 'analysis');
      analysis = r.analysis;
    end
  end

    set(groot, 'DefaultAxesFontName', 'Roboto');
    set(groot, 'DefaultAxesTitleFontWeight', 'normal');
    set(groot, 'DefaultFigureColor', 'w');
    set(groot, 'DefaultAxesBox', 'off');
    set(groot, 'DefaultLegendEdgeColor', 'w');

    % subtightplot util ([vertical, horizontal], [lower, upper], [left right])
    tsubplot = @(m,n,p) subtightplot(m, n, p, [0.1 0.1], [0.1 0.5], [0.1 0.1]);

if ~isfield(r, 'protocol')
    for ii = 1:length(r)
      params = r(ii).params;
      r(ii).stimTrace = getStimTrace(params, 'pulse', 'offline');
      [n, ~] = size(r(ii).resp);
      r(ii).binSize = 200;
      if strcmp(r(ii).recordingType, 'extracellular')
        co = zeros(n,3);
        data = r(ii).resp;
      else
        data = r(ii).analog;
        co = pmkmp(n, 'cubicYF');
      end
      for jj = 1:n
        if jj == 1 || strcmp(r(ii).recordingType, 'extracellular')
          figure; hold on; % extracellular figure per trace, WC all on same figure
        end
        subplot(4,1,1:3); hold on;
        x = 1:length(data); x = x/10000;
        [c1, ~] = getPlotColor(r(ii).params.chromaticClass);
        plot(x, data(jj,:), 'color', co(jj,:));
        set(gca,'box', 'off', 'tickdir', 'out'); axis tight;
        if strcmp(r(ii).recordingType, 'extracellular')
          title([r(ii).label ' - ' r(ii).chromaticClass ' spot (' num2str(r(ii).params.contrast *100) '%, ' num2str(r(ii).params.radiusMicrons) 'um radius, ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf)'])
        else
          title([r(ii).label ' - ' r(ii).chromaticClass ' spot (' r(ii).analysisType(1:3) ', ' num2str(r(ii).params.contrast *100) '%, ' num2str(r(ii).params.radiusMicrons) 'um radius, ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf)'])
        end
        subplot(8,1,8); hold on;
        plot(r(ii).stimTrace, 'color', c1, 'linewidth', 2);
        set(gca,'box', 'off', 'tickdir', 'out', 'XColor', 'w', 'XTick', []);
        ylabel('contrast'); axis tight; ylim([0 1]);
      end

      if strcmp(r(ii).recordingType, 'extracellular')
        % get PTSH without bothering with analyzeDataOnline
        r(ii).ptsh = getPTSH(r, r(ii).spikes, 200);
        if n > 1
          figure; hold on;
          subplot(4,1,1:3); hold on;
          bar(r(ii).ptsh.binCenters, r(ii).ptsh.spikeCounts,...
            'edgecolor', 'k', 'facecolor', c1, 'linestyle', 'none');
          title([r(ii).label ' - ' r(ii).chromaticClass ' spot (' num2str(contrast) '%, ' num2str(r(ii).params.radiusMicrons) 'um radius, ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf, ' num2str(n) ' trials)']);
          set(gca,'box', 'off', 'tickdir', 'out'); axis tight;
          ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));

          subplot(8,1,8); hold on;
          plot(r(ii).stimTrace, 'color', c1, 'linewidth', 2);
          set(gca,'box', 'off', 'tickdir', 'out', 'XColor', 'w', 'XTick', []);
          ylabel('contrast'); axis tight; ylim([0 1]);
        end
      elseif strcmp(r(ii).recordingType, 'voltage_clamp')
        % just do the mean resp for whole cell
        r(ii).avgResp = mean(r(ii).analog, 1);
        figure; hold on;
        subplot(4, 1, 1:3);
        xpts = 1:length(r(ii).avgResp); xpts = xpts/10000;
        plot(xpts, r(ii).avgResp, 'color', 'k');
        set(gca, 'box', 'off', 'TickDir', 'out'); axis tight;
        title([r(ii).label ' - ' r(ii).chromaticClass ' spot mean (' r(ii).analysisType(1:3) ', ' num2str(r(ii).params.contrast *100) '%, ' num2str(r(ii).params.radiusMicrons) 'um radius, ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf)']);

        subplot(8, 1, 8); hold on;
        plot(r(ii).stimTrace, 'color', c1, 'LineWidth', 2);
        set(gca, 'Box', 'off', 'TickDir', 'out', 'XColor', 'w', 'XTick', []);
        ylabel('contrast'); axis tight; ylim([0 1]);
      end
    end
  else

  switch(r.protocol)
    case 'edu.washington.riekelab.sara.protocols.TempSpatialNoise'
      strfViewer(r);

    case {'edu.washington.riekelab.manookin.protocols.ChromaticGrating',...  
      'edu.washington.riekelab.sara.protocols.TempChromaticGrating'}
      figure;
      subplot(3,1,1:2); hold on;
      plot(r.params.spatialFrequencies, analysis.F1, 'o-', 'color', r.params.plotColor, 'linewidth', 1);
      if strcmp(r.params.temporalClass, 'reversing')
        [c2, ~] = getPlotColor(r.params.chromaticClass, 0.5);
        plot(r.params.spatialFrequencies, analysis.F2, 'o-', 'color', c2, 'linewidth', 1);
        legend('f1', 'f2'); set(legend, 'edgecolor', 'w');
      end
      ax = gca; ax.XScale = 'log'; ax.XTick = {}; ax.Box = 'off';
      ylabel('f1 amplitude'); axis tight; ax.YLim = [0, ceil(max(analysis.F1))];
      foo = sprintf('%u%s', r.params.orientation, char(176));
      title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.temporalClass ' ' r.params.spatialClass ' grating at ' num2str(r.params.contrast*100) '% and ' foo]);
      set(gca, 'titlefontsize', 1);

      subplot(313); hold on;
      plot(r.params.spatialFrequencies, analysis.P1, 'o-','color', r.params.plotColor, 'linewidth', 1);
      if strcmp(r.params.temporalClass, 'reversing')
        plot(r.params.spatialFrequencies, analysis.F2, 'o-', 'color', c2, 'linewidth', 1);
      end
      ax = gca; ax.XScale = 'log'; ax.Box = 'off';
      ylabel('f1 phase'); axis tight; ax.YLim = [-180 180]; ax.YTick = -180:90:180;
      xlabel('spatial frequencies');

    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      figure('Name', 'F1 Figure'); hold on;
      for ii = 1:length(r.params.stimClass)
        [c, n] = getPlotColor(r.params.stimClass(ii), [1 0.5]);
        plot(analysis.f1phase(ii,:), analysis.f1amp(ii,:), 'o',...
          'MarkerFaceColor', c(2,:), 'MarkerEdgeColor', c(2,:));
        plot(mean(analysis.f1phase(ii,:), 2), mean(analysis.f1amp(ii,:), 2), 'o',...
          'MarkerFaceColor', c(1,:), 'MarkerEdgeColor', c(1,:));
      end
      if ~isfield(r.params, 'equalQuantalCatch')
        title([r.cellName ' - ' r.params.stimClass ' cone iso '... 
          num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot']);
      else
        title([r.cellName ' - ' r.params.stimClass ' cone iso '... 
          num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot (equal qcatch)']);
      end
      xlabel('f1 phase'); ylabel('f1amp'); xlim([-180 180]);
      % ax = gca; ax.YLim(1) = 0;

      xpts = 1:(length(r.resp(1,:))); xpts = xpts / 10000;
      for jj = 1:(ceil(r.numEpochs/length(r.params.stimClass)))
        figure('Name', sprintf('Trial %u Figure', jj)); hold on;
        for ii = 1:length(r.params.stimClass)
          [c1, n] = getPlotColor(r.params.stimClass(ii));
          subplot(length(r.params.stimClass)+1, 1, ii); hold on;
          plot(xpts, squeeze(r.respBlock(ii, jj, :)), 'Color', c1);
          axis tight; set(gca, 'box', 'off', 'TickDir', 'out');
          if ii ~= length(r.params.stimClass)
            set(gca, 'XColor', 'w', 'XTick', []);
          end
          if isempty(strfind(r.params.stimClass, 'lms'))
            legend(n); set(legend, 'edgecolor', 'w');
          end
        end
        subplot(length(r.params.stimClass)+1, 1, 1);
        if r.params.equalQuantalCatch == 1
          title([r.cellName ' - ' r.params.stimClass ' cone iso ' num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot (equal qcatch)']);
        else
          title([r.cellName ' - ' r.params.stimClass ' cone iso ' num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot']);
        end
        subplot(2*(length(r.params.stimClass)+1), 1, 2*(length(r.params.stimClass)+1));
        analysis.stimTrace = getStimTrace(r.params, 'modulation', 'offline');
        plot(analysis.stimTrace, 'k', 'linewidth', 1);
        set(gca, 'box', 'off', 'XColor', 'w', 'XTick', []);
        ylabel('contrast'); axis tight; ylim([0 1]);
      end

      % graph PTSH for extracellular, mean resp for wholecell
      figure('Name', 'PTSH Figure');
      for ii = 1:length(r.params.stimClass)
        subplot(length(r.params.stimClass)+1, 1, ii);
        [c1, n] = getPlotColor(r.params.stimClass(ii));
        if strcmp(r.params.recordingType, 'extracellular')
          bar(r.ptsh.(r.params.stimClass(ii)).binCenters/10000, r.ptsh.(r.params.stimClass(ii)).spikeCounts,...
            'facecolor', c1, 'edgecolor', 'k', 'linestyle', 'none');
        else % voltage clamp
          xpts = length(r.analog, 1)/1000;
          plot(xpts, r.avgResp.(r.params.stimClass(stim)), 'Color', c1);
        end
        axis tight; set(gca, 'box', 'off', 'TickDir', 'out');
        if ii ~= length(r.params.stimClass)
          set(gca, 'XColor', 'w', 'XTick', []);
        end
        %legend(n); set(legend, 'edgecolor', 'w', 'location', 'northwest');
        %y = get(gca, 'YLim'); set(gca, 'YLim', [0 ceil(y(2))]);
        if ii == 1
          if r.params.equalQuantalCatch == 1
            title([r.cellName ' - ' r.params.stimClass ' '... 
              num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot (equal qcatch)']);
          else
            title([r.cellName ' - ' r.params.stimClass ' '... 
              num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot']);
          end
        end
      end
      subplot(2*(length(r.params.stimClass)+1), 1, 2*(length(r.params.stimClass)+1)); hold on;
      plot(analysis.stimTrace, 'k', 'LineWidth', 1);
      set(gca, 'box', 'off', 'XColor', 'w', 'XTick', []);
      ylabel('contrast'); axis tight; ylim([0 1]);

      % testing out instantaneous firing rate
      if strcmp(r.params.recordingType, 'extracellular')
        figure('Name', 'InstFt Figure');
        for ii = 1:length(r.params.stimClass)
          subplot(length(r.params.stimClass)+1, 1, ii); hold on;
          [c, n] = getPlotColor(r.params.stimClass(ii), [1 0.5]);
          for jj = 1:size(r.instFt, 2)
            plot(xpts, squeeze(r.instFt(ii,jj,:)), 'color', c(2,:), 'LineWidth', 1);
          end
          plot(xpts, mean(squeeze(r.instFt(ii,:,:))), 'color', c(1,:), 'LineWidth', 1.5);
          axis tight; set(gca, 'box', 'off', 'TickDir', 'out');
          ax = gca; ax.YLim(1) = 0;
          if ii ~= length(r.params.stimClass)
            set(gca, 'XColor', 'w', 'XTickLabel', []);
          end
          if ii == 1
          title([r.cellName ' - ' upper(r.params.stimClass) ' ' num2str(ceil(2*r.params.radiusMicrons))... 
            ' micron spot (' num2str(r.params.objectiveMag) 'x at ' num2str(100*r.params.contrast) '%)']);
          end
        end
        subplot(2*(length(r.params.stimClass)+1), 1, 2*(length(r.params.stimClass)+1)); hold on;
        plot(analysis.stimTrace, 'k', 'LineWidth', 1);
        set(gca, 'Box', 'off', 'XColor', 'w', 'XTick', []);
        ylabel('contrast'); axis tight; ylim([0 1]);

        figure('Name', 'Avg InstFt Figure');
        for ii = 1:length(r.params.stimClass)
          subplot(4,1,1:3); hold on;
          [c, n] = getPlotColor(r.params.stimClass(ii), [1 0.5]);
          plot(xpts, squeeze(r.instFt(ii,:,:)), 'Color', c(1,:));
          axis tight; set(gca, 'Box', 'off', 'TickDir', 'out');
          ax = gca; ax.YLim(1) = 0;
          title([r.cellName ' - ' upper(r.params.stimClass) ' ' num2str(ceil(2*r.params.radiusMicrons))... 
            ' micron spot (' num2str(r.params.objectiveMag) 'x at ' num2str(100*r.params.contrast) '%)']);
          subplot(8,1,8);
          plot(analysis.stimTrace, 'k', 'LineWidth', 1);
          set(gca, 'Box', 'off', 'XColor', 'w', 'XTick', []);
          ylabel('contrast'); axis tight; ylim([0 1]);
        end
      end

    case 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch'
      figure();
      subplot(1,2,1); hold on;
      r.params.plotColor(1,:) = getPlotColor('l'); r.params.plotColor(2,:) = getPlotColor('m');
      plot(r.params.searchValues, analysis.redF1, '-o', 'Color', r.params.plotColor(1,:), 'LineWidth',1);
      title(sprintf('red min = %.3f', analysis.redMin)); ylabel('f1 amplitude'); xlabel('red contrast');
      subplot(1,2,2); hold on;
      plot(r.params.searchValues, analysis.greenF1, '-o', 'Color', r.params.plotColor(2,:), 'LineWidth', 1);
      title(sprintf('green min = %.3f', analysis.greenMin)); xlabel('green contrast');

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
      indivPlot = false;
      c2 = r.params.plotColor + (0.6 * (1-r.params.plotColor));
      xpts = 1:length(analysis.linearFilter);
      xpts = xpts/r.analysis.binsPerFrame;

      % plot the linear filter
      figure; hold on;
      if r.params.radius > 1000
        stimType = 'full field';
      else
        stimType = sprintf('%u radius', ceil(r.params.radiusMicrons));
      end
      plot(xpts, analysis.linearFilter, 'color', r.params.plotColor, 'linewidth', 1); hold on;
      plot([1 xpts(end)], zeros(1,2), 'color', [0.5 0.5 0.5]);
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3) ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      else
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      end
      set(gca,'box', 'off', 'TickDir', 'out');
      xlabel('msec'); ylabel('filter units');

      % plot individual linear filters
      if indivPlot
        figure; hold on;
        for ii = 1:r.numEpochs
          plot(xpts, analysis.lf(ii,:), 'color', c2, 'linewidth', 0.8); hold on;
        end
        plot(xpts, analysis.linearFilter, 'color', r.params.plotColor, 'linewidth', 1);
        if strcmp(r.params.recordingType, 'voltage_clamp')
          title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3) ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
        else
          title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
        end
        set(gca,'box', 'off', 'TickDir', 'out');
        xlabel('msec'); ylabel('filter units');
      end

      % % plot the nonlinearity
      % figure; hold on;
      % plot(analysis.nonlinearity.xBin, analysis.nonlinearity.yBin, '.', 'color', c2);
      % plot(analysis.nonlinearity.xBin, analysis.nonlinearity.fit, 'color', r.params.plotColor, 'linewidth', 1);
      % axis square; %axis tight;
      % set(gca, 'box', 'off', 'tickdir', 'out');
      % xlabel('generator'); ylabel('spikes/sec');
      % title([r.cellName ' - nonlinearity (' r.params.chromaticClass ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);

      % plot both - mike format
      figure;
      subplot(1,2,1); hold on;
      if r.params.radius > 1000
        stimType = 'full field';
      else
        stimType = sprintf('%u radius', ceil(r.params.radiusMicrons));
      end
      plot(xpts, analysis.linearFilter, 'color', r.params.plotColor, 'linewidth', 1); hold on;
      plot([1 xpts(end)], zeros(1,2), 'color', [0.5 0.5 0.5]);
      if strcmp(r.params.recordingType, 'voltage_clamp')
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3) ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      else
        title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      end
      set(gca,'box', 'off', 'TickDir', 'out');
      xlabel('msec'); ylabel('filter units');

      subplot(1,2,2); hold on;
      plot(analysis.nonlinearity.xBin, analysis.nonlinearity.yBin, '.', 'color', c2);
      plot(analysis.nonlinearity.xBin, analysis.nonlinearity.fit, 'color', r.params.plotColor, 'linewidth', 1);
      axis tight; axis square;
      xlabel('generator'); ylabel('spikes/sec');
      set(gca,'tickdir', 'out', 'box', 'off');

      % temporal
      figure; hold on;
      plot(analysis.tempFT, 'color', r.params.plotColor, 'linewidth', 1);
      title([r.cellName ' - ' r.params.chromaticClass ' temporal tuning (' stimType ', ' num2str(r.params.objectiveMag) 'x)']);

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
      xlabel('frequency (hz)'); xlim([0 100]);
      set(gca, 'Box', 'off', 'TickDir', 'out');

    case 'edu.washington.riekelab.sara.protocols.IsoSTC'
      switch r.params.paradigmClass
        case 'STA'
          x = 0:r.params.frameRate - 1;
          if r.params.radius > 1000
            stimType = sprintf('%ux full field', r.params.objectiveMag);
          else
            stimType = sprintf('spot (%u micron radius)', ceil(r.params.radiusMicrons));
          end
          if ~isempty(strfind(r.params.chromaticClass, 'RGB'))
            r.params.plotColor = [0.82, 0, 0; 0, 0.53, 0.22; 0.14, 0.21, 0.84];
            figure; hold on;
            plot(x, analysis.linearFilter(1,:), 'color', r.params.plotColor(1,:), 'linewidth', 1);
            plot(x, analysis.linearFilter(2,:), 'color', r.params.plotColor(2,:), 'linewidth', 1);
            plot(x, analysis.linearFilter(3,:), 'color', r.params.plotColor(3,:), 'linewidth', 1);
            xlabel('msec'); ylabel('filter units'); ax = gca;
            ax.Box = 'off'; ax.TickDir = 'out'; ax.YLim(1) = 0;
            title([r.cellName ' - RGB binary noise ' stimType]);

            figure; hold on;
            for ii = 1:length(analysis.linearFilter)
              rectangle('Position', [ii-1, 0, 1, 1], 'FaceColor', analysis.linearFilter(:,ii), 'EdgeColor', analysis.linearFilter(:,ii));
            end
            ax=gca; ax.Box = 'off'; xlabel('msec'); ax.YColor = 'w'; ax.YTickLabel = [];
            if r.params.radius > 1000
      	      stimType = sprintf('full-field, %ux', r.params.objectiveMag);
            else
      	      stimType = sprintf('%u micron spot', ceil(r.params.radiusMicrons));
            end

            title([r.cellName ' - chromatic temporal receptive field (' stimType ')']);
            set(gca, 'TitleFontSize', 1);
          else
            figure('Name', 'Filter + Nonlinearity');
            [c,~] = getPlotColor(r.params.chromaticClass, [1 0.5]);
            subplot(1,2,1); hold on;
            plot(x, analysis.linearFilter, 'Color', c(1,:), 'LineWidth', 1); hold on;
            plot([0 x(end)], zeros(1,2), 'Color', [0.5 0.5 0.5]);
            if strcmp(r.params.recordingType, 'voltage_clamp')
              titlestr = [r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' r.params.analysisType(1:3)... 
                ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)'];
            else
              titlestr = [r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev)... 
                ' sd, ' stimType ')'];
            end
            title(titlestr);
            set(gca,'Box', 'off', 'TickDir', 'out');
            xlabel('msec'); ylabel('filter units');

            subplot(1,2,2); hold on;
            plot(analysis.nonlinearity.xBin, analysis.nonlinearity.yBin, '.', 'color', c(2,:));
            plot(analysis.nonlinearity.xBin, analysis.nonlinearity.fit, 'color', c(1,:), 'linewidth', 1);
            axis tight; axis square;
            xlabel('generator'); ylabel('spikes/sec');
            set(gca,'tickdir', 'out', 'box', 'off');

            figure('Name', 'Linear Filter');
            plot(x, analysis.linearFilter, 'Color', c(1,:), 'LineWidth', 1); hold on;
            plot([0 x(end)], zeros(1,2), 'Color', [0.5 0.5 0.5]);
            set(gca, 'Box', 'off', 'TickDir', 'out');
            xlabel('msec'); ylabel('filter units');
            title(titlestr);
          end
        case 'ID'
         if r.numEpochs > 1
           figure; hold on;
           c2 = r.params.plotColor + (0.5 * (1-r.params.plotColor));
           for ii = 1:r.numEpochs
             plot(abs(analysis.f1phase(ii)), abs(analysis.f1amp(ii)), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
           end
           plot(mean(abs(analysis.f1phase),2), mean(abs(analysis.f1amp), 2), 'o', 'MarkerFaceColor', r.params.plotColor, 'MarkerEdgeColor', r.params.plotColor);
           title([r.cellName ' - ' r.params.chromaticClass ' spot - ' num2str(r.params.radiusMicrons) ' microns, ' r.params.temporalClass ' at ' num2str(r.params.temporalFrequency) ' hz']);
           xlabel('f1 phase'); ylabel('f1amp'); xlim([0 180]);
           ax = gca; ax.YLim(1) = 0;
         else
           fprintf('F1amp is %.3f and F1phase is %.3f\n', analysis.meanAmp, analysis.meanPhase);
         end

         r.params.stimTrace = getStimTrace(r.params, 'modulation', 'offline');

         % plot PTSH
         figure; set(gcf, 'color', 'w');
         subplot(3,1,1:2); hold on;
         bar(analysis.ptsh.binCenters, analysis.ptsh.spikeCounts,...
          'facecolor', r.params.plotColor, 'edgecolor', 'k', 'linestyle', 'none');
         set(gca, 'box', 'off', 'tickdir', 'out');

         subplot(3,1,3); hold on;
         plot(r.params.stimTrace, 'color', r.params.plotColor, 'linewidth', 1);
         set(gca, 'box', 'off', 'tickdir', 'out');

         % plot response
         if r.numEpochs == 1
           figure; set(gcf,'color', 'w');
           subplot(3,1,1:2); hold on;
           plot(r.resp); axis tight;
           set(gca, 'box', 'off', 'tickdir', 'out');
           subplot(3,1,3); hold on;
           plot(r.params.stimTrace, 'color', r.params.plotColor);
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

    case 'edu.washington.riekelab.manookin.protocols.BarCentering'
      figure;
      c2 = r.params.plotColor + (0.6 * (1-r.params.plotColor));
      posMicron = r.params.positions * r.params.micronsPerPixel;
      subplot(3,1,1:2); hold on;
      plot(posMicron, analysis.f1amp, '-o', 'LineWidth', 1, 'Color', r.params.plotColor);
      title([r.cellName ' - ' r.params.searchAxis ' ' r.params.chromaticClass ' bar centering (' num2str(ceil(r.params.barSizeMicrons(1))) ' x ' num2str(ceil(r.params.barSizeMicrons(2))) ' um)']);
      xlabel('bar position (microns)'); ylabel('f1 amplitude');
      ax = gca; axis tight; ax.YLim(1) = 0;
      set(gca, 'Box', 'off', 'TickDir', 'out');

      subplot(9,1,8:9); hold on;
      plot(posMicron, analysis.f1phase, '-o', 'Linewidth', 1, 'Color', r.params.plotColor);
      axis tight; ylim([-180 180]); ylabel('f1 phase');
      set(gca,'box', 'off','YTick', -180:90:180, 'TickDir', 'out', 'XColor', 'w');

      if strcmp(r.params.temporalClass, 'squarewave')
        fh = gcf; fh2 = figure();
        % is it possible to use copyobj for a whole figure??
        ax1 = copyobj(fh.Children(2), fh2); hold on;
        plot(ax1, posMicron, analysis.f2amp, '-o', 'Linewidth', 1, 'Color', c2);
        legend('f1', 'f2'); set(legend, 'EdgeColor', 'w'); axis tight;
        
        ax2=copyobj(fh.Children(1), fh2); hold on;
        plot(ax2, posMicron, analysis.f2phase, '-o', 'LineWidth', 1, 'Color', c2);
      end

    case 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot'
      c2 = r.params.plotColor + (0.6 * (1-r.params.plotColor));
      figure;
      subplot(3, 1, 1:2); hold on;
      for ii = 1:r.numEpochs
        plot(r.params.contrasts(ii), analysis.f1amp(ii), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
      end
      plot(analysis.xaxis, analysis.mean_f1amp, '-o', 'color', r.params.plotColor, 'linewidth', 1);
      ax = gca; axis tight; ax.YLim(1) = 0;
      set(gca, 'Box', 'off', 'TickDir', 'out');
      ylabel('f1 amplitude');
      title([r.cellName ' - ' r.params.chromaticClass ' contrast response spot (' num2str(round(r.params.radiusMicrons)) ' radius)']);

      subplot(9, 1, 8:9); hold on;
      for ii = 1:r.numEpochs
        plot(r.params.contrasts(ii), analysis.f1phase(ii), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
      end
      plot(analysis.xaxis, analysis.mean_f1phase, '-o', 'color', r.params.plotColor, 'linewidth', 1);
      set(gca, 'box', 'off', 'ytick', -180:90:180);
      ylabel('f1 phase'); ylim([-180 180]);

    case 'edu.washington.riekelab.manookin.protocols.sMTFspot'
      fh1 = figure('Name', 'F1 plot');
      subplot(3,1,1:2); hold on;
      [c, ~] = getPlotColor(r.params.chromaticClass, [1 0.5]);
      semilogx(r.params.radii, analysis.f1amp, 'o-','color', c(1,:), 'linewidth', 1);
      title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' ' r.params.stimulusClass ' ' r.params.temporalClass ' sMTF']);
      set(gca,'box', 'off'); ylabel('f1 amplitude'); axis tight;
      ax=gca; ax.YLim(1) = 0;

      subplot(3,1,3); hold on;
      semilogx(r.params.radii, analysis.f1phase, 'o-', 'color', c(1,:), 'linewidth', 1);
      set(gca,'box', 'off'); ylabel('f1 phase'); axis tight; ylim([-180 180]);
      set(gca, 'YTick', -180:90:180);

      if strcmp(r.params.temporalClass, 'squarewave')
        fh2 = figure('Name', 'F1F2 plot');
        ax1 = copyobj(fh1.Children(2), fh2);
        semilogx(ax1, r.params.radii, analysis.f2amp, 'o-', 'color', c(2,:), 'linewidth', 1);
        title([r.cellName ' - ' num2str(100*r.params.contrast) '% ' r.params.chromaticClass ' squarewave ' r.params.stimulusClass ' sMTF']);
        legend('onset', 'offset');
        set(legend, 'EdgeColor', 'w', 'FontSize', 10);
        set(gca,'box', 'off'); ylabel('response amplitude'); axis tight;
        ax1b.YLim(1) = 0;
        
        ax2 = copyobj(fh1.Children(1), fh2);        
        semilogx(ax2, r.params.radii, analysis.f2phase, 'o-', 'color', c(2,:), 'linewidth', 1);
      end

      % add in the fit
      if isfield(analysis, 'f1Fit')
        if strcmp(r.params.chromaticClass, 'achromatic') 
          c2 = 'b';
        else
          c2 = 'k';
        end      
          semilogx(fh1.Children(2), r.params.radii, analysis.f1Fit.fit,... 
            'Color', c2, 'LineWidth', 1);
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
      set(legend, 'edgecolor', 'w');
      set(gca, 'Box', 'off', 'TickDir', 'out');
      if r.params.innerRadius ~= 0
        r.params.stimFocus = sprintf('surround - %u annulus', round(r.params.innerRadiusMicrons));
      else % no inner radius
        if r.params.outerRadius >= 1500
          r.analysis.stimFocus = 'full-field';
        else
          r.analysis.stimFocus = sprintf('center - %u radius', round(r.params.outerRadiusMicrons));
        end
      end
      title([r.cellName ' - glider stimulus (' num2str(r.params.objectiveMag) 'x, ' r.analysis.stimFocus ')']);

      figure(); fig = gcf;
      % fig.Position(2) = fig.Position(2) - 300; fig.Position(4) = fig.Position(4) + 300;
      % fig.Units = 'normalized';
      for ii = 1:size(r.analysis.binAvg, 1)
        % tsubplot(size(r.analysis.binAvg,1), 1, ii); hold on;
        subtightplot (size(r.analysis.binAvg,1), 1, ii, [0.1 0.01], [0.1 0.01], [0.1 0.01]);
        plot(r.analysis.binAvg(ii,:), 'Color', co(ii,:));
        legend(r.params.stimuli{ii});
        set(legend, 'edgecolor', 'w');
        set(gca, 'Box', 'off')
        if ii < size(r.analysis.binAvg)
          set(gca, 'XColor', 'w', 'XLabel', [], 'XTickLabel', {});
        end
        if ii == 1
          title([r.cellName ' - glider stimulus (' num2str(r.params.objectiveMag) 'x, ' r.analysis.stimFocus ')']);
        end        
        axis tight;  % round YLim to nearest 10s
        set(gca, 'YLim', [0 round(max(max(r.analysis.binAvg)), -1)]);
      end

    case 'edu.washington.riekelab.manookin.protocols.MovingBar'
      co = pmkmp(length(r.params.orientations), 'cubicL');
      cp = co - (0.4*(1-co)); cp(cp < 0) = 0;
      xpts = (1:size(r.respBlock, 3)) / r.params.sampleRate;

      figure('Name', 'moving bar raster plot')
      for ii = 1:size(r.respBlock, 1)
        for jj = 1:size(r.respBlock, 2)
          ind = sub2ind([size(r.respBlock, 1) size(r.respBlock, 2)], ii, jj);
          subplot(size(r.respBlock, 1), 1, ii); hold on;
          switch r.params.recordingType
          case 'extracellular'
            plot(xpts, r.spikes(ind, :), 'Color', co(jj*2, :)); axis tight;
          case 'voltage_clamp'
            plot(xpts, r.analog(ind,:), 'Color', co(jj*2,:)); axis tight;
          end
          set(gca, 'Box', 'off', 'TickDir', 'out', 'YTick', []);
          ylabel(sprintf('%u%s     ', (30*ii)-30, char(176)),... 
            'Rotation', 0, 'VerticalAlignment', 'middle');
          if ii ~= size(r.respBlock, 1)
            set(gca, 'XColor', 'w', 'XTickLabel', {}, 'XTick', []);
          else
            xlabel('time (sec)');
          end
          if ii == 1
            title(sprintf('%s - moving bar stimulus %u% contrast at %.1f mean',... 
              r.cellName, 100*r.params.intensity, r.params.backgroundIntensity));
          end
        end
      end

      % instft or analog plot
      figure(); hold on;
      for ii = 1:size(r.respBlock,1)
        plot(xpts, squeeze(mean(r.instFt(ii, :, :), 2)), 'Color', co(ii,:), 'LineWidth', 1);
        legendstr{ii} = sprintf('%u%s', (30*ii)-30, char(176));
      end
      legend(legendstr);
      set(legend, 'EdgeColor', 'w', 'FontSize', 10);
      title([r.cellName sprintf(' moving bar avg firing rate (%u % at %.1f mean)',... 
        100*r.params.intensity, r.params.backgroundIntensity)]);

      figure;
      for jj = 1:size(r.respBlock, 1)
        subplot(size(r.respBlock,1), 1, jj); hold on;
        for ii = 1:size(r.respBlock,2)
          plot(xpts, squeeze(r.instFt(jj,ii,:)),... 
            'Color', cp(jj,:), 'LineWidth', 1);
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
      subplot(size(r.respBlock, 1), 1, 1);
      title(sprintf('%s - moving bar (%u% on %.1f mean)', r.cellName, 100*r.params.intensity, r.params.backgroundIntensity))


      for jj = 1:size(r.respBlock, 2)
        figure('Color', 'w', 'Name', sprintf('moving bar trial %u (%u% at %.1f mean)',... 
          jj, r.params.intensity, r.params.backgroundIntensity));
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
      end
  end % protocol switch

  r.log{end+1} = ['graphDataOnline at ' datestr(now)];

  if neuron == 2
    r.cellName = r.cellName(1:end-1);
  end
end
