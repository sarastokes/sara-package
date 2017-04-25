function makeConeMaps(varargin)
	% separate spatial receptive field into + and - maps (w/ maps in UserData)
	% INPUT: 			r = data structure or strf (x,y,t)
	%	or normalize existing figure:
	%	   					runNorm = normalize to other maps (default = false) needs fh
	%						fh = plot to (or normalize) specific figure, new if empty
	%	OPTIONAL:			graphNum = 3, 4, 1 (default = 3)
	%						bins = which time bin(s) to show (default = mean of all)
	%						chromaticClass = full name, if r isn't data structure

	ip = inputParser();
	ip.addParameter('r', [], @(x)isstruct(x) || isnumeric(x));
	ip.addParameter('graphNum', 3, @(x)isvector(x));
	ip.addParameter('fh', [], @(x)ishandle(x));
	ip.addParameter('bins', [], @(x)isvector(x));
	ip.addParameter('chromaticClass', [], @(x)ischar(x));
	ip.addParameter('runNorm', false, @(x)islogical(x));
    ip.parse(varargin{:});
	r = ip.Results.r;
	graphNum = ip.Results.graphNum;
    bins = ip.Results.bins;
	f.h = ip.Results.fh;
	runNorm = ip.Results.runNorm;

	if isempty(r)
		if ~runNorm || isempty(f.h)
			error('no data input. need fh input and runNorm = true');
		end
	end


	if graphNum == 4;
		g2 = 2;
	else
		g2 = 0;
	end
	g1 = 2;

	if runNorm
		srf = get(f.h, 'UserData');
		maps = {'achromatic', 'L-iso', 'M-iso', 'S-iso'};
		if isempty(graphNum)
			graphNum = size(srf,1)/2;
		end
		if isempty(bins) % grab bin string from existing figure
			if isempty(strfind(f.h.Children(1).Title.String, 'ON'))
				b = f.h.Children(1).Title.String(6:end);
			else
				b = f.h.Children(1).Title.String(5:end);
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

		if ~isempty(f.h) % get existing maps
			srf = get(f.h, 'UserData');
		else
			f.h = figure();
			set(f.h, 'Color', 'w',...
			'DefaultAxesFontName', 'roboto',...
			'DefaultAxesFontSize', 10,...
			'DefaultAxesTitleFontWeight', 'normal');
			toolbar = findall(f.h, 'Type', 'uitoolbar');
			icon = zeros(10,10,3); icon(:,:,3) = 1;
			pb = uipushtool('Parent', toolbar,...
				'CData', icon,...
				'Separator', 'on',...
				'TooltipString', 'Combined map',...
				'ClickedCallback', {@onSelected_combMap, f});

			srf = zeros(2*graphNum, size(ONmap, 1), size(ONmap,2));
		end
		makeMap(chromaticClass, ONmap, OFFmap);
	end

	set(findobj(f.h, 'Type', 'Title'), 'FontWeight', 'normal');
	set(f.h, 'UserData', srf);
	setappdata(f.h, 'GUIdata', srf);

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
			title(sprintf('Achrom ON%s', b));

			subtightplot(graphNum, g1, 2, 0.07);
			srf(2,:,:) = OFFmap;
			imagesc(OFFmap, [lims(1) 0]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('white','black')); freezeColors;
			title(sprintf('Achrom OFF%s', b));

		case {'L-iso','liso','l'}
			subtightplot(graphNum, g1, 2 + g2, 0.07);
			srf(2+g2,:,:) = OFFmap;
			try
				imagesc(OFFmap, [lims(1) 0]);
			catch
				imagesc(OFFmap, [-1 0]);
			end
			colormap(rgbmap('green', 'black')); freezeColors;
			axis equal; axis tight; axis off;
			title(sprintf('L-OFF%s', b));

			subtightplot(graphNum, g1, 1 + g2, 0.05);
			srf(1+g2,:,:) = ONmap;
			imagesc(ONmap, [0 lims(2)]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'red')); freezeColors;
			title(sprintf('L-ON%s', b));

		case {'M-iso','miso', 'm'}
			subtightplot(graphNum, g1, 4 + g2, 0.07);
			srf(4+g2, :, :) = OFFmap;
			imagesc(OFFmap, [lims(1) 0]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('red', 'black')); freezeColors;
			title(sprintf('M-OFF%s', b));

			subtightplot(graphNum, g1, 3 + g2, 0.07);
			srf(3+g2, :, :) = ONmap;
			try
				imagesc(ONmap, [0 lims(2)]);
			catch
				imagesc(ONmap, [0 1]);
			end
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'green')); freezeColors;
			title(sprintf('M-ON%s', b));

		case {'S-iso','siso','s'}
			subtightplot(graphNum, g1, 6 + g2, 0.07);
			srf(6+g2, :, :) = OFFmap;
			try
				imagesc(OFFmap, [lims(1) 0]);
			catch
				imagesc(OFFmap, [-1 0]);
			end
			axis equal; axis tight; axis off;
			colormap(rgbmap('yellow', 'black')); freezeColors;
			title(sprintf('S-OFF%s', b));

			subtightplot(graphNum, g1, 5 + g2, 0.07);
			srf(5+g2, :, :) = ONmap;
            try
				imagesc(ONmap, [lims(1) 0]);
			catch
				imagesc(ONmap, [-1 0]);
			end
			imagesc(ONmap, [0 lims(2)]);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'blue')); freezeColors;
			title(sprintf('S-ON%s', b));
		end
	end

	function onSelected_combMap(varargin)
		f = varargin{3};
		% srf = get(f.h, 'UserData');
		srf = getappdata(f.h, 'GUIdata');

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

		fullMin = min(min(min(srf)));
		fullMax = max(max(max(srf)));

		fh2 = figure();
		ax(1) = subtightplot(1,2,1,0.05,[],[], 'Parent', fh2);
		imagesc(shiftdim(ONsrf,1), 'Parent', ax(1));
		axis equal; axis tight; axis off;
		title('ON cone inputs');
		ax(2) = subtightplot(1,2,2,0.05,[],[], 'Parent', fh2);
		imagesc(shiftdim(OFFsrf,1), 'Parent', ax(2));
		axis equal; axis tight; axis off;
		title('OFF cone inputs');

		fh3 = figure();
		ax(3) = axes('Parent', fh3);
		imagesc(shiftdim(ONsrf,1)+abs(shiftdim(OFFsrf,1)), 'Parent', ax(3));
		axis equal; axis tight; axis off;
		title('Cone Mosaic');
		tightfig(fh3);

		fh3 = figure();
		ax(4) = axes('Parent', fh3);
		imagesc(shiftdim(ONsrf,1), 'Parent', ax(4));
		axis equal; axis tight; axis off;
		title('Cone Mosaic');
		tightfig(fh3);
	end
end
