function pixelSTA(r, x, y, varargin)
  % get temporal RF for a single spatial noise pixel
  % INPUTS: r = data structure
  %         x y = pixel coordinates (x = y-axis, y = x-axis...)
  % OPTIONAL: ax = plot to an existing figure
  %
  % 1Sept2016 - SSP - created
  % 1Nov2016 - SSP - added RGB, ChromaticSpatialNoise
  % 15Jun2017 - SSP - updated: binRate, xpts 
    
    ip = inputParser();
    ip.addParameter('bpf', [], @isnumeric);
    ip.addParameter('ax', [], @ishandle);
    ip.addParameter('fac', [], @isnumeric);
    ip.addParameter('norm', false, @islogical);
    ip.parse(varargin{:});


    ax = ip.Results.ax;
    if isempty(ax)
      figure; ax = gca;
    end

    if isempty(ip.Results.bpf)
      if isfield(r.analysis, 'binsPerFrame')
          xpts = linspace(0, 500, r.analysis.binsPerFrame * r.params.frameRate/2);
      else
          fprintf('setting bin rate to 60\n');
          xpts = linspace(0, 500, 60);
      end
    else
      xpts = linspace(0, 500, ip.Results.bpf);
    end

    if strcmp(r.params.chromaticClass, 'RGB')
      strf = shiftdim(r.analysis.strf, 1);
      temporal = squeeze(strf(x,y,:,:));
        plot(ax, xpts, squeeze(temporal(:,1)), 'color', [0.83 0 0], 'linewidth', 1);
        hold on;
        plot(ax, xpts, squeeze(temporal(:,2)), 'color', [0 0.73 0.30], 'linewidth', 1);
        plot(ax, xpts, squeeze(temporal(:,3)), 'color', [0.14 0.21 0.84], 'linewidth', 1);

        % for ii = 1:xpts
        %  rectangle('position', [ii-1, 0, 1, 1], 'facecolor', temporal(ii,:) + 0.5, 'edgecolor', temporal(ii,:) + 0.5); hold on;
        % end
        ax=gca; ax.Box = 'off'; xlabel('msec'); axis tight; %ax.YColor = 'w';

    elseif ~isempty(strfind(r.protocol,'ChromaticSpatialNoise'))
      cones = {'liso' 'miso' 'siso'};
      colors = [0.82 0 0; 0 0.72 0.30; 0.14 0.2 0.84];
      for ii = 1:3
        strf = r.(cones{ii}).analysis.strf;
        plot(ax, xpts, squeeze(strf(x,y,:)), 'color', colors(ii,:), 'linewidth', 1); hold on;
        set(gca,'box', 'off', 'TickDir', 'out');
      end
    else % achrom or cone iso
      if isfield(r.params, 'chromaticClass')
        c = getPlotColor(lower(r.params.chromaticClass(1)));
      else
        c = [0 0 0];
      end
      strf = r.analysis.strf;

      sta = line(xpts, squeeze(strf(x,y,:)),... 
        'Parent', ax,...
        'Color', c, 'LineWidth', 1);

      if ~isempty(ip.Results.fac)
        set(sta, 'YData', smooth(get(sta, 'YData'), ip.Results.fac));
      end

      if ip.Results.norm
        set(sta, 'YData', get(sta, 'YData')/max(abs(get(sta, 'YData'))));
      end

      hold on; set(gca, 'box', 'off', 'TickDir', 'out');
    end

    plot(ax, [xpts(1) xpts(end)], [0 0], 'Color', [0.5 0.5 0.5]);

    title(sprintf('STA at %u, %u', x, y)); 
    xlabel('time (ms)'); 
    axis tight;
  end
