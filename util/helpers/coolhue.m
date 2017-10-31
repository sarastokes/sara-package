function cmap = coolhue(npts, varargin)
	% COOLHUE Colormaps based on webkul coolhue gradient hues
	% https://webkul.github.io/coolhue
	% Needs lingrad, hex2rgb, xkcd's rgb
	%
	% INPUTS:
	%	npts 		how many points for the colormap
	% Specify the map with either:
	%	gradientName 	named gradient from coolhue:
    %       cyanmagenta, lightblue, darkblue, pastelblue, greenteal, warm,
    %       bluepurple, peach, yellowblue, greenred, pinkblue, pinkyellow
	% Or use your own colors:
	%	colorOne	first color (rgb, #hex, color name)
	%	colorTwo	2nd color (rgb, #hex, color name)
	% OPTIONAL:
	%	gradientMode	[linear] which gradient type:
	%		linear, softease, softinvert, invert, ease, cosine, waves
	%	demoMode 		[false] show colormap with matlab's peaks
	% 
	% 19Oct2017 - SSP

	ip = inputParser();
	ip.CaseSensitive = false;
	addParameter(ip, 'gradientName', [], @ischar);
	addParameter(ip, 'gradientMode', 'linear', @(x) validatestring(x,... 
		{'linear', 'ease', 'softease', 'invert', 'cosine', 'waves', 'softinvert'}));
	addParameter(ip, 'demoMode', false, @islogical);
	parse(ip, varargin{:});
	demoMode = ip.Results.demoMode;
	gradientMode = ip.Results.gradientMode;
	gradientName = ip.Results.gradientName;

	if ~isempty(gradientName)
		switch gradientName
			case 'cyanmagenta'
				colorOne = '81ffef';
				colorTwo = 'f067b4';
			case 'lightblue'
				colorOne = '5efce8';
				colorTwo = '736efe';
			case 'darkblue'
				colorOne = '52e5e7';
				colorTwo = '130cb7';
			case 'pastelblue'
				colorOne = 'c2ffd8';
				colorTwo = '465efb';
			case 'greenteal'
				colorOne = '92ffc0';
				colorTwo = '002661';
			case 'bluepurple'
				colorOne = '43cbff';
				colorTwo = '9708cc';
			case 'warm'
				colorOne = 'ffd3a5';
				colorTwo = 'fd6585';
			case 'peach'
				colorOne = 'fad7a1';
				colorTwo = 'e96d71';
			case 'yellowblue'
				colorOne = 'ffd26f';
				colorTwo = '3677ff';
			case 'greenred'
				colorOne = 'a0fe65';
				colorTwo = 'fa016d';
			case 'pinkblue'
				colorOne = 'fab2ff';
				colorTwo = '1904e5';
			case 'pinkyellow'
				colorOne = 'ffa8a8';
				colorTwo = 'ecff00';				
		end
		colorOne = hex2rgb(colorOne);
		colorTwo = hex2rgb(colorTwo);
	else
		colorOne = parseColor(ip.Results.colorOne);
		colorTwo = parseColor(ip.Results.colorTwo);
	end

	npts = [npts 1 3];
	cmap = lingrad(npts, [0 0; 1 0], [colorOne; colorTwo]*255, gradientMode);
    cmap = squeeze(cmap);
    cmap = double(cmap)/255;
    
	if demoMode
		fh = figure();
		surf(peaks);
		shading('interp');
        colormap(fh, cmap);
		axis off;
		tightfig(gcf);
	end

	function ret = parseColor(colorInput)
		% PARSECOLOR  Convert to matlab 0-1 colorspec
		% Tag hex colors with #
		if ischar(colorInput)
			if strcmp(colorInput(1), '#')
				ret = hex2rgb(colorInput);
			else
				ret = rgb(colorInput);
			end
		else
			ret = double(colorInput);
		end

		if max(colorInput) > 1
			ret = colorInput/255;
		end
	end
end


