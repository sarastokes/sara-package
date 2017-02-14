function pixelSTA(r, x, y, ax)
  % get temporal RF for a single spatial noise pixel
  % INPUTS: r = data structure
  %         x y = pixel coordinates (x = y-axis, y = x-axis...)
  % OPTIONAL: ax = plot to an existing figure

    if nargin < 4
      figure; ax = gca;
    end

    if strcmp(r.params.chromaticClass, 'RGB')
      strf = shiftdim(r.analysis.strf, 1);
      temporal = squeeze(strf(x,y,:,:));
      [msec,~] = size(temporal);
        plot(ax, 0:msec-1, squeeze(temporal(:,1)), 'color', [0.83 0 0], 'linewidth', 1);
        hold on;
        plot(ax, 0:msec-1, squeeze(temporal(:,2)), 'color', [0 0.73 0.30], 'linewidth', 1);
        plot(ax, 0:msec-1, squeeze(temporal(:,3)), 'color', [0.14 0.21 0.84], 'linewidth', 1);

        % for ii = 1:msec
        %  rectangle('position', [ii-1, 0, 1, 1], 'facecolor', temporal(ii,:) + 0.5, 'edgecolor', temporal(ii,:) + 0.5); hold on;
        % end
        ax=gca; ax.Box = 'off'; xlabel('msec'); axis tight; %ax.YColor = 'w';

    elseif ~isempty(strfind(r.protocol,'ChromaticSpatialNoise'))
      cones = {'liso' 'miso' 'siso'}
      colors = [0.82 0 0; 0 0.72 0.30; 0.14 0.2 0.84];
      for ii = 1:3
        strf = r.(cones{ii}).analysis.strf;
        msec = size(strf,3);
        plot(ax, 0:msec-1, squeeze(strf(x,y,:)), 'color', colors(ii,:), 'linewidth', 1); hold on;
        set(gca,'box', 'off', 'TickDir', 'out');
      end
    else % achrom or cone iso
      if isfield(r.params, 'chromaticClass')
        c = getPlotColor(lower(r.params.chromaticClass(1)));
      else
        c = [0 0 0];
      end
      strf = r.analysis.strf;
      msec = size(strf, 3);
      plot(ax, 0:msec-1, squeeze(strf(x,y,:)), 'Color', c, 'LineWidth', 1); hold on;
      set(gca, 'box', 'off', 'TickDir', 'out');
    end
    zeroBar = zeros(1, msec);
    plot(ax, 0:msec-1, zeroBar, 'color', [0.5 0.5 0.5]);
    title(sprintf('STA at %u, %u', x, y)); xlabel('msec'); axis tight;
  end
