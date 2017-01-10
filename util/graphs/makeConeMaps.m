function makeConeMaps(varargin)
	% separate spatial receptive field into + and - maps (w/ maps in UserData)
	% INPUT: 			r = data structure or strf (x,y,t)
	%		or normalize existing figure:
	%	   					runNorm = normalize to other maps (default = false) needs fh
	%							fh = plot to (or normalize) specific figure, new if empty
	%	OPTIONAL:		graphNum = 3, 4, 1 (default = 3)
	%							bins = which time bin(s) to show (default = mean of all)
	%							chromaticClass = full name, if r isn't data structure

	ip = inputParser();
	ip.addParameter('r', [], @(x)isstruct(x) || @(x)isvector(x));
	ip.addParameter('graphNum', 3, @(x)isvector(x));
	ip.addParameter('fh', [], @(x)ishandle(x));
	ip.addParameter('bins', [], @(x)isvector(x));
	ip.addParameter('chromaticClass', [], @(x)ischar(x));
	ip.addParameter('runNorm', false, @(x)islogical(x));
  ip.parse(varargin{:});
	r = ip.Results.r;
	graphNum = ip.Results.graphNum;
  bins = ip.Results.bins;
	fh = ip.Results.fh;
	runNorm = ip.Results.runNorm;

	if isempty(r)
		if ~runNorm || isempty(fh)
			error('no data input. need fh input and runNorm = true');
		end
	end


	if graphNum == 4;
		g2 = 2;
	else
		g2 = 0;
	end
	if graphNum == 1
		g1 = 1;
	else
		g1 = 2;
	end

	if runNorm
		srf = get(fh, 'UserData');
		maps = {'achromatic', 'L-iso', 'M-iso', 'S-iso'};
		if isempty(graphNum)
			graphNum = size(srf,1)/2;
		end
		if isempty(bins) % grab bin string from existing figure
			if isempty(strfind(fh.Children(1).Title.String, 'ON'))
				b = fh.Children(1).Title.String(6:end);
			else
				b = fh.Children(1).Title.String(5:end);
			end
		end
		if size(srf,1) == 6
			maps = maps(2:4);
		end
		for ii = 1:length(maps)
			ind = 1+(ii-1)*2;
			makeMap(maps{ii}, squeeze(srf(ind,:,:)), squeeze(srf(ind+1,:,:)),...
			[min(min(min(srf))) max(max(max(srf)))]);
		end
	else
		if isstruct(r)
			chromaticClass = r.params.chromaticClass;
			if isempty(bins)
				data = r.analysis.spatialRF;
			else
				data = r.analysis.strf;
			end
		else
			chromaticClass = ip.Results.chromaticClass;
			if isempty(chromaticClass)
				error('need chromaticClass or data structure input');
			end
			data = r;
		end

		if isempty(bins)
			ONmap = data .* (data > 0);
			OFFmap = data .* (data < 0);
			b = ' ';
		else % individual bin or mean of some bins
			if length(bins) > 1
				b = sprintf(' (t = %u:%u)', bins(1), bins(2));
			else
				b = sprintf(' (t = %u)', bins(1));
				bins = [bins, bins];
			end
			spatialRF = squeeze(mean(data(:,:,bins(1):bins(2)),3));
			ONmap = spatialRF .* (spatialRF > 0);
			OFFmap = spatialRF .* (spatialRF < 0);
		end

		if ~isempty(fh) % get existing maps
			srf = get(fh, 'UserData');
		else
			fh = figure();
			set(fh, 'Color', 'w',...
			'DefaultAxesFontName', 'roboto',...
			'DefaultAxesFontSize', 10,...
			'DefaultAxesTitleFontWeight', 'normal');
			toolbar = findall(fh, 'Type', 'uitoolbar');
			icon = zeros(10,10,3); icon(:,:,3) = 1;
			pb = uipushtool('Parent', toolbar,...
				'CData', icon,...
				'Separator', 'on',...
				'TooltipString', 'Combined map',...
				'ClickedCallback', {@onSelected_combMap, fh});

			srf = zeros(2*graphNum, size(ONmap, 1), size(ONmap,2));
		end
		makeMap(chromaticClass, ONmap, OFFmap);
	end

	set(findobj(fh, 'Type', 'Title'), 'FontWeight', 'normal');
	set(fh, 'UserData', srf);

	function makeMap(cc, ONmap, OFFmap, lims)
		if nargin < 4
			lims = [min(min(OFFmap)) max(max(ONmap))];
		end
		switch cc
		case 'achromatic'
			subtightplot(graphNum, g1, 1, 0.07);
			srf(1,:,:) = ONmap;
			imagesc(ONmap, [0 lims(2)]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black','white')); freezeColors;
			title(sprintf('Achrom ON%s'), b);

			subtightplot(graphNum, g1, 2, 0.07);
			srf(2,:,:) = OFFmap;
			imagesc(OFFmap, [lims(1) 0]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('white','black')); freezeColors;
			title(sprintf('Achrom OFF%s', b));

		case 'L-iso'
			subtightplot(graphNum, g1, 2 + g2, 0.07);
			srf(2+g2,:,:) = OFFmap;
			imagesc(OFFmap, [lims(1) 0]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('green', 'black')); freezeColors;
			title(sprintf('L-OFF%s', b));

			subtightplot(graphNum, g1, 1 + g2, 0.05);
			srf(1+g2,:,:) = ONmap;
			imagesc(ONmap, [0 lims(2)]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'red')); freezeColors;
			title(sprintf('L-ON%s', b));

		case 'M-iso'
			subtightplot(graphNum, g1, 4 + g2, 0.07);
			srf(4+g2, :, :) = OFFmap;
			imagesc(OFFmap, [lims(1) 0]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('red', 'black')); freezeColors;
			title(sprintf('M-OFF%s', b));

			subtightplot(graphNum, g1, 3 + g2, 0.07);
			srf(3+g2, :, :) = ONmap;
			imagesc(ONmap, [0 lims(2)]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'green')); freezeColors;
			title(sprintf('M-ON%s', b));

		case 'S-iso'
			subtightplot(graphNum, g1, 6 + g2, 0.07);
			srf(6+g2, :, :) = OFFmap;
			imagesc(OFFmap, [lims(1) 0]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('yellow', 'black')); freezeColors;
			title(sprintf('S-OFF%s', b));

			subtightplot(graphNum, g1, 5 + g2, 0.07);
			srf(5+g2, :, :) = ONmap;
			imagesc(ONmap, [0 lims(2)]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'blue')); freezeColors;
			title(sprintf('S-ON%s', b));
		end
	end

	function onSelected_combMap(varargin)
		fh = varargin{3};
		srf = get(fh, 'UserData');

		ONsrf = zeros(size(srf,1)/2, size(srf,2), size(srf,3));
		OFFsrf = zeros(size(ONsrf));
		for ii = 1:size(srf,1)/2
			ind = 1+(ii-1)*2;
			ONsrf(ii,:,:) = srf(ind,:,:);
			OFFsrf(ii,:,:) = srf(ind+1,:,:);
		end
		ONsrf = (ONsrf - min(min(min(ONsrf)))) / (max(max(max(ONsrf)))-min(min(min(ONsrf))));
		OFFsrf = -1*OFFsrf;
		OFFsrf = (OFFsrf - min(min(min(OFFsrf)))) / (max(max(max(OFFsrf)))-min(min(min(OFFsrf))));


		fh2 = figure();
		ax(1) = subplot(1,2,1, 'Parent', fh2);
		imagesc(ax(1), shiftdim(ONsrf,1));
		axis equal; axis tight;
		title('ON cone inputs');
		ax(2) = subplot(1,2,2, 'Parent', fh2);
		imagesc(ax(2), shiftdim(OFFsrf,1));
		axis equal; axis tight;
		title('OFF cone inputs');
	end
end
