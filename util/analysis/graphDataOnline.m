function r = graphDataOnline(r)

    set(groot, 'DefaultAxesFontName', 'Roboto');
    set(groot, 'DefaultAxesTitleFontWeight', 'normal');
    set(groot, 'DefaultFigureColor', 'w');
    set(groot, 'DefaultAxesBox', 'off');

if ~isfield(r, 'protocol')
%    if strcmp(r(1).params.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticSpot')
    for ii = 1:length(r)
      params = r(ii).params;
      r(ii).stimTrace = getStimTrace(params);
      contrast = r(ii).params.contrast *100;
      [n, ~] = size(r(ii).resp);
      r(ii).binSize = 200;
%      r(ii).ptsh = zeros(n, length(r(ii).resp)/r(ii).binSize);
      for jj = 1:n
        figure; hold on;
        subplot(4,1,1:3); hold on;
        x = 1:length(r(ii).resp); x = x/10000;
        [c1, ~] = getPlotColor(r(ii).params.chromaticClass);
        plot(x, r(ii).resp(jj,:), 'color', 'k');
        set(gca,'box', 'off', 'tickdir', 'out'); axis tight;
        title([r(ii).label ' - ' r(ii).chromaticClass ' spot (' num2str(contrast) '%, ' num2str(r(ii).params.radiusMicrons) 'um radius, ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf)'])

        subplot(8,1,8); hold on;
        plot(r(ii).stimTrace, 'color', c1, 'linewidth', 2);
        set(gca,'box', 'off', 'tickdir', 'out', 'XColor', 'w', 'XTick', []);
        ylabel('contrast'); axis tight; ylim([0 1]);

      end
      % get PTSH without bothering with analyzeDataOnline
        r(ii).ptsh = getPTSH(r, r(ii).spikes, 200);
        if n > 1
          figure; hold on;
          subplot(4,1,1:3); hold on;
          bar(r(ii).ptsh.binCenters, r(ii).ptsh.spikeCounts, 'edgecolor', 'k', 'facecolor', c1, 'linestyle', 'none');
          title([r(ii).label ' - ' r(ii).chromaticClass ' spot (' num2str(contrast) '%, ' num2str(r(ii).params.radiusMicrons) 'um radius, ' num2str(r(ii).params.objectiveMag) 'x, ' num2str(ceil(r(ii).params.ndf)) ' ndf, ' num2str(n) ' trials)']);
          set(gca,'box', 'off', 'tickdir', 'out'); axis tight;
          ax=gca; ax.YLim(1) = 0; ax.YLim(2) = ceil(ax.YLim(2));

          subplot(8,1,8); hold on;
          plot(r(ii).stimTrace, 'color', c1, 'linewidth', 2);
          set(gca,'box', 'off', 'tickdir', 'out', 'XColor', 'w', 'XTick', []);
          ylabel('contrast'); axis tight; ylim([0 1]);
        end
    end
else
  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticGrating') || strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.TempChromaticGrating')
    figure;
    subplot(3,1,1:2); hold on;
    plot(r.params.spatialFrequencies, r.analysis.F1, 'o-', 'color', r.params.plotColor, 'linewidth', 1);
    if strcmp(r.params.temporalClass, 'reversing')
      c2 = r.params.plotColor + (0.5 * (1-r.params.plotColor));
      plot(r.params.spatialFrequencies, r.analysis.F2, 'o-', 'color', c2, 'linewidth', 1);
      legend('f1', 'f2'); set(legend, 'edgecolor', 'w');
    end
    ax = gca; ax.XScale = 'log'; ax.XTick = {}; ax.Box = 'off';
    ylabel('f1 amplitude'); axis tight; ax.YLim = [0, ceil(max(r.analysis.F1))];
    foo = sprintf('%u%s', r.params.orientation, char(176));
    title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.temporalClass ' ' r.params.spatialClass ' grating at ' num2str(r.params.contrast*100) '% and ' foo]);
    set(gca, 'titlefontsize', 1);

    subplot(313); hold on;
    plot(r.params.spatialFrequencies, r.analysis.P1, 'o-','color', r.params.plotColor, 'linewidth', 1);
    if strcmp(r.params.temporalClass, 'reversing')
      plot(r.params.spatialFrequencies, r.analysis.F2, 'o-', 'color', c2, 'linewidth', 1);
    end
    ax = gca; ax.XScale = 'log'; ax.Box = 'off';
    ylabel('f1 phase'); axis tight; ax.YLim = [-180 180]; ax.YTick = -180:90:180;
    xlabel('spatial frequencies');
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ConeSweep')
    figure; hold on;
    for ii = 1:length(r.params.stimClass)
      [c1, n] = getPlotColor(r.params.stimClass(ii)); %#ok<ASGLU>
      c2 = c1 + (0.5 * (1-c1));
      plot(abs(r.analysis.f1phase(ii,:)), abs(r.analysis.f1amp(ii,:)), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
      plot(mean(abs(r.analysis.f1phase(ii,:)), 2), mean(abs(r.analysis.f1amp(ii,:)), 2), 'o', 'MarkerFaceColor', c1, 'MarkerEdgeColor', c1);
    end
    title([r.cellName ' - ' r.params.stimClass ' cone iso ' num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot']);
    xlabel('f1 phase'); ylabel('f1amp'); xlim([0 180]);
    ax = gca; ax.YLim(1) = 0;

    x= 1:(length(r.resp(1,:))); x = x / 10000;
    for jj = 1:(r.numEpochs/length(r.params.stimClass))
      figure; hold on;
      for ii = 1:length(r.params.stimClass)
        [c1, n] = getPlotColor(r.params.stimClass(ii));
        subplot(4, 1, ii); hold on;
        plot(x, r.resp(ii+(3*(jj-1)),:), 'color', c1);
        axis tight; set(gca, 'box', 'off', 'TickDir', 'out');
        if ii ~= 3
          set(gca, 'XColor', 'w', 'XTick', []);
        end
        if ~strcmp(r.params.stimClass, 'lms') && ~strcmp(r.params.stimClass, 'cyp')
          legend(n); set(legend, 'edgecolor', 'w');
        end
      end
      subplot(411);
      title([r.cellName ' - ' r.params.stimClass ' cone iso ' num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot']);
      subplot(818);
      r.analysis.stimTrace = getStimTrace(r);
      plot(r.analysis.stimTrace, 'k', 'linewidth', 1);
      set(gca, 'box', 'off', 'XColor', 'w', 'XTick', []);
      ylabel('contrast'); ylim([0 1]);
    end

    % graph PTSH
    figure; ymax = 0;
    for ii = 1:length(r.params.stimClass)
      if ymax < max(r.ptsh.(r.params.stimClass(ii)).spikeCounts)
        ymax = max(r.ptsh.(r.params.stimClass(ii)).spikeCounts);
      end
    end
    for ii = 1:length(r.params.stimClass)
      subplot(4, 1, ii);

      [c1, n] = getPlotColor(r.params.stimClass(ii));
      bar(r.ptsh.(r.params.stimClass(ii)).binCenters, r.ptsh.(r.params.stimClass(ii)).spikeCounts, 'facecolor', c1, 'edgecolor', 'k');
      axis tight; set(gca, 'box', 'off', 'TickDir', 'out');
      if ii ~= 3
        set(gca, 'XColor', 'w', 'XTick', []);
      end
      legend(n); set(legend, 'edgecolor', 'w', 'location', 'northwest');
      ax = gca; ax.YLim(2) = ceil(ax.YLim(2)); ax.YLim(1) = 0;
      if ii == 1
        if isfield(r.params, 'equalQuantalCatch')
          title([r.cellName ' - ' r.params.stimClass ' ' num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot (equal qcatch)']);
        else
          title([r.cellName ' - ' r.params.stimClass ' ' num2str(ceil(2 * r.params.radiusMicrons)) ' micron spot']);
        end
      end
    end

    subplot(818); hold on;
    plot(r.analysis.stimTrace, 'k', 'linewidth', 1);
    set(gca, 'box', 'off', 'XColor', 'w', 'XTick', []);
    ylabel('contrast'); ylim([0 1]);
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.GaussianNoise')
    indivPlot = false;
    c2 = r.params.plotColor + (0.6 * (1-r.params.plotColor));

    % plot the linear filter
    figure; hold on;
    if r.params.radius > 1000
      stimType = 'full field';
    else
      stimType = sprintf('%u radius', ceil(r.params.radiusMicrons));
    end
    plot((0:length(r.analysis.linearFilter)-1), r.analysis.linearFilter/r.numEpochs, 'color', r.params.plotColor, 'linewidth', 1); hold on;
    plot([1 length(r.analysis.linearFilter)], zeros(1,2), 'color', [0.5 0.5 0.5]);
    title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
    set(gca,'box', 'off', 'TickDir', 'out');
    xlabel('msec'); ylabel('filter units');

    % plot individual linear filters
    if indivPlot
      figure;
      for ii = 1:r.numEpochs
        plot((0:length(r.analysis.lf)-1), r.analysis.lf(ii,:), 'color', c2, 'linewidth', 0.8); hold on;
      end
      plot((0:length(r.analysis.linearFilter)-1), r.analysis.linearFilter/r.numEpochs, 'color', r.params.plotColor, 'linewidth', 1);
      title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
      set(gca,'box', 'off', 'TickDir', 'out');
      xlabel('msec'); ylabel('filter units');
    end

    % plot the nonlinearity
    figure; hold on;
    plot(r.analysis.nonlinearity.xBin, r.analysis.nonlinearity.yBin, '.', 'color', c2);
    plot(r.analysis.nonlinearity.xBin, r.analysis.nonlinearity.fit, 'color', r.params.plotColor, 'linewidth', 1);
    axis square; %axis tight;
    set(gca, 'box', 'off', 'tickdir', 'out');
    xlabel('generator'); ylabel('spikes/sec');
    title([r.cellName ' - nonlinearity (' r.params.chromaticClass ', ' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);

    % plot both - mike format
    figure;
    subplot(1,2,1); hold on;
    if r.params.radius > 1000
      stimType = 'full field';
    else
      stimType = sprintf('%u radius', ceil(r.params.radiusMicrons));
    end
    plot((0:length(r.analysis.linearFilter)-1), r.analysis.linearFilter/r.numEpochs, 'color', r.params.plotColor, 'linewidth', 1); hold on;
    plot([1 length(r.analysis.linearFilter)], zeros(1,2), 'color', [0.5 0.5 0.5]);
    title([r.cellName ' - ' r.params.chromaticClass ' gaussian noise (' num2str(r.params.stdev) ' sd, ' stimType ', ' num2str(r.params.objectiveMag) 'x)']);
    set(gca,'box', 'off', 'TickDir', 'out');
    xlabel('msec'); ylabel('filter units');

    subplot(1,2,2); hold on;
    plot(r.analysis.nonlinearity.xBin, r.analysis.nonlinearity.yBin, '.', 'color', c2);
    plot(r.analysis.nonlinearity.xBin, r.analysis.nonlinearity.fit, 'color', r.params.plotColor, 'linewidth', 1);
    axis tight; axis square;
    xlabel('generator'); ylabel('spikes/sec');
    set(gca,'tickdir', 'out', 'box', 'off');
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.IsoSTC')
    if strcmp(r.params.paradigmClass, 'STA')
      x = 0:r.params.frameRate - 1;
      if r.params.radius > 1000
        stimType = sprintf('(full field, %ux)', r.params.objectiveMag);
      else
        stimType = sprintf('spot (%u micron radius)', ceil(r.params.radiusMicrons));
      end
      if ~isempty(strfind(r.params.chromaticClass, 'RGB'))
        r.params.plotColor = [0.82, 0, 0; 0, 0.53, 0.22; 0.14, 0.21, 0.84];
        figure; hold on;
        plot(x, r.analysis.linearFilter(1,:) / r.numEpochs, 'color', r.params.plotColor(1,:), 'linewidth', 1);
        plot(x, r.analysis.linearFilter(2,:) / r.numEpochs, 'color', r.params.plotColor(2,:), 'linewidth', 1);
        plot(x, r.analysis.linearFilter(3,:) / r.numEpochs, 'color', r.params.plotColor(3,:), 'linewidth', 1);
        xlabel('msec'); ylabel('filter units'); ax = gca;
        ax.Box = 'off'; ax.TickDir = 'out'; ax.YLim(1) = 0;
        title([r.cellName ' - RGB binary noise ' stimType]);

        figure; hold on;
        for ii = 1:length(r.analysis.linearFilter)
          rectangle('position', [ii-1, 0, 1, 1], 'facecolor', r.analysis.linearFilter(:,ii)/r.numEpochs, 'edgecolor', r.analysis.linearFilter(:,ii)/r.numEpochs);
        end
        ax=gca; ax.Box = 'off'; xlabel('msec'); ax.YColor = 'w'; ax.YTickLabel = [];
        if r.params.radius > 1000
  	      stimType = sprintf('full-field, %ux', r.params.objectiveMag);
        else
  	      stimType = sprintf('%u micron spot', ceil(r.params.radiusMicrons));
        end

        title([r.cellName ' - chromatic temporal receptive field (' stimType ')']);
        set(gca, 'TitleFontSize', 1);
      end
    elseif strcmp(r.params.paradigmClass, 'ID')
     if r.numEpochs > 1
       figure; hold on;
       c2 = r.params.plotColor + (0.5 * (1-r.params.plotColor));
       for ii = 1:r.numEpochs
         plot(abs(r.analysis.f1phase(ii)), abs(r.analysis.f1amp(ii)), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
       end
       plot(mean(abs(r.analysis.f1phase),2), mean(abs(r.analysis.f1amp), 2), 'o', 'MarkerFaceColor', r.params.plotColor, 'MarkerEdgeColor', r.params.plotColor);
       title([r.cellName ' - ' r.params.chromaticClass ' spot - ' num2str(r.params.radiusMicrons) ' microns, ' r.params.temporalClass ' at ' num2str(r.params.temporalFrequency) ' hz']);
       xlabel('f1 phase'); ylabel('f1amp'); xlim([0 180]);
       ax = gca; ax.YLim(1) = 0;
     else
       fprintf('F1amp is %.3f and F1phase is %.3f\n', r.analysis.meanAmp, r.analysis.meanPhase);
     end

     r.params.stimTrace = getStimTrace(r);

     % plot PTSH
     figure; set(gcf, 'color', 'w');
     subplot(3,1,1:2); hold on;
     bar(r.analysis.ptsh.binCenters, r.analysis.ptsh.spikeCounts, 'facecolor', r.params.plotColor, 'edgecolor', 'k', 'linestyle', 'none');
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
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.SpatialNoise')
    figure;
    imagesc(r.analysis.spatialRF);
    title([r.cellName ' spatial receptive field']);
    if strcmp(r.params.chromaticClass, 'RGB')
      STRF = shiftdim(r.analysis.strf, 1); %#ok<NASGU>
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticSpatialNoise')
    if isfield(r.liso)
      figure;
      subplot(3,1,1);
      imagesc(r.liso.analysis.spatialRF);
      subplot(3,1,2);
      imagesc(r.miso.analysis.spatialRF);
      subplot(3,1,3);
      imagesc(r.siso.analysis.spatialRF);
    else
      figure;
      imagesc(r.analysis.spatialRF);
      title([r.cellName ' - ' r.params.chromaticClass(1) '-cone iso noise (' r.params.objectiveMag 'x,' r.params.stixelSize ' microns)']);
    end
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.BarCentering')
    figure;
    posMicron = r.params.positions * r.params.micronsPerPixel;
    subplot(3,1,1:2); hold on;
    plot(posMicron, r.analysis.f1amp, '-ok', 'linewidth', 1);
    title([r.cellName ' - ' r.params.searchAxis ' bar centering (' num2str(ceil(r.params.barSizeMicrons(1))) ' x ' num2str(ceil(r.params.barSizeMicrons(2))) ' um)']);
    xlabel('bar position (microns)'); ylabel('f1 amplitude');
    ax = gca; axis tight; ax.YLim(1) = 0;
    set(gca, 'box', 'off', 'tickdir', 'out');

    subplot(9,1,8:9); hold on;
    plot(posMicron, r.analysis.f1phase, '-ok', 'linewidth', 1);
    axis tight; ylim([-180 180]); ylabel('f1 phase');
    set(gca,'box', 'off','YTick', -180:90:180, 'tickdir', 'out', 'xcolor', 'w');
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ConeIsoSearch')

  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ContrastResponseSpot')
    c2 = r.params.plotColor + (0.6 * (1-r.params.plotColor));
    figure;
    subplot(3, 1, 1:2); hold on;
    for ii = 1:r.numEpochs
      plot(r.params.contrasts(ii), r.analysis.f1amp(ii), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
    end
    plot(r.analysis.xaxis, r.analysis.mean_f1amp, '-o', 'color', r.params.plotColor, 'linewidth', 1);
    ax = gca; axis tight; ax.YLim(1) = 0;
    set(gca, 'box', 'off', 'tickdir', 'out');
    ylabel('f1 amplitude');
    title([r.cellName ' - ' r.params.chromaticClass ' contrast response spot (' num2str(round(r.params.radiusMicrons)) ' radius)']);

    subplot(9, 1, 8:9); hold on;
    for ii = 1:r.numEpochs
      plot(r.params.contrasts(ii), r.analysis.f1phase(ii), 'o', 'MarkerFaceColor', c2, 'MarkerEdgeColor', c2);
    end
    plot(r.analysis.xaxis, r.analysis.mean_f1phase, '-o', 'color', r.params.plotColor, 'linewidth', 1);
    set(gca, 'box', 'off', 'ytick', -180:90:180);
    ylabel('f1 phase'); ylim([-180 180]);
  end

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.sMTFspot')
    figure;
    subplot(3,1,1:2);
    c1 = getPlotColor(r.params.chromaticClass);
    semilogx(r.params.radii, r.analysis.f1amp, 'o-','color', c1, 'linewidth', 1);
    title([r.cellName ' - ' r.params.chromaticClass ' ' r.params.stimulusClass ' sMTF']);
    set(gca,'box', 'off'); ylabel('f1 amplitude'); axis tight;
    ax=gca; ax.YLim(1) = 0;
    subplot(3,1,3);
    semilogx(r.params.radii, r.analysis.f1phase, 'o-', 'color', c1, 'linewidth', 1);
    set(gca,'box', 'off'); ylabel('f1 phase'); axis tight; ylim([-180 180]);
    set(gca, 'YTick', -180:90:180);
  end

end

end
