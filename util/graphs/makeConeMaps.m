function makeConeMaps(r, graphType, figureHandle)
	% make +- color maps like conway 2001

	if nargin < 1
		fprintf('required: r. optional: 2=graphType 3=figureHandle[all,on]\n');
		return;
	end
	
	if nargin < 2
		graphType = 'all';
	end

	if nargin < 3
		fig = figure;
	else
		srf = get(figureHandle, 'UserData');
	end

	set(gcf, 'color', 'w',... 
		'DefaultAxesFontName', 'roboto',...
		'DefaultAxesFontSize', 10);

	ONmap = r.analysis.spatialRF .* (r.analysis.spatialRF > 0);
	OFFmap = r.analysis.spatialRF .* (r.analysis.spatialRF < 0);

	switch r.params.chromaticClass
	case 'achromatic'
		subtightplot(1,2,1, 0.07);
		srf.Aon = ONmap;
		imagesc(srf.Aon); 
		axis equal; axis tight; axis off;
		colormap(rgbmap('black','white')); freezeColors;
		title('Achrom ON', 'FontWeight', 'normal');

		subtightplot(1,2,2,0.07);
		srf.Aoff = OFFmap;
		imagesc(srf.Aoff);
		axis equal; axis tight; axis off;
		colormap(rgbmap('white','black')); freezeColors;
		title('Achrom OFF', 'FontWeight', 'normal');
	case 'L-iso'
		if strcmp(graphType, 'all') 
			subtightplot(3, 2, 2, 0.07);
			srf.Loff = OFFmap;
			imagesc(srf.Loff); 
			axis equal; axis tight; axis off;
			colormap(rgbmap('green', 'black')); freezeColors;
			title('L-OFF', 'FontWeight', 'normal');
			subtightplot(3, 2, 1, 0.05);
		else
			subtightplot(1, 3, 1, 0.07);
		end
		srf.Lon = ONmap;
		imagesc(srf.Lon); 
		axis equal; axis tight; axis off;
		colormap(rgbmap('black', 'red')); freezeColors;
		title('L-ON', 'FontWeight', 'normal'); 

	case 'M-iso'
		if strcmp(graphType, 'all')
			subtightplot(3, 2, 4, 0.07);
			srf.Moff = OFFmap;
			imagesc(srf.Moff);
			axis equal; axis tight; axis off;
			colormap(rgbmap('red', 'black')); freezeColors;
			title('M-OFF', 'FontWeight', 'normal');
			subtightplot(3, 2, 3, 0.07);
		else
			subtightplot(3, 1, 2, 0.07);
		end
			srf.Mon = ONmap;
			imagesc(srf.Mon); 
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'green')); freezeColors;
			title('M-ON', 'FontWeight', 'normal');


	case 'S-iso'
		if strcmp(graphType, 'all')
			subtightplot(3, 2, 6, 0.07);
			srf.Soff = OFFmap;
			imagesc(srf.Soff);
			axis equal; axis tight; axis off;
			colormap(rgbmap('yellow', 'black')); freezeColors;
			title('S-OFF', 'FontWeight', 'normal');
			subtightplot(3, 2, 5, 0.07);
		else
			subtightplot(1, 3, 3, 0.07);
		end
			srf.Son = ONmap;
			imagesc(srf.Son);
			axis equal; axis tight; axis off;
			colormap(rgbmap('black', 'blue')); freezeColors;
			title('S-ON', 'FontWeight', 'normal');

	end

	% save the maps to user data (at least for now)
	set(figureHandle, 'UserData', srf);