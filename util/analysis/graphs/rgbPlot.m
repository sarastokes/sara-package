function rgbPlot(wavelength, spectra, titlestr, ax)
	% for checking calibrations
	% INPUT: wavelength is xaxis
	% 				spectra is yaxis with 3 columns for rgb
	% OPTIONAL: titlestr = title for graph


	co = 'lms';

	if nargin < 4
		fh = figure('Color', 'w');
		figPos(fh, 0.55, 0.6);
		ax = gca;
	end

	hold on;

	for ii = 1:3
		plot(ax, wavelength, spectra(:,ii),... 
			'Color', getPlotColor(co(ii)), 'LineWidth', 1); 
	end

	if nargin > 2
		title(titlestr);
	end
	
	if nargin < 4
		xlabel('wavelength (nm)'); % xlim([wavelength(1) 800]);
		tightfig(fh);
	end