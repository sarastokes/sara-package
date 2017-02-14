function r = STRFexperiments(r, neuron)
	% not sure any of these are legit/necessary
	if nargin < 2
		neuron = 1;
	else
		neuron = 2;
	end
	if neuron == 2
		analysis = r.secondary.analysis;
		cellName = [r.cellName '*'];
	else
		analysis = r.analysis;
		cellName = r.cellName;
	end

	%% try 2d gaussian without specifying any parameters
	[xi, yi] = meshgrid(1:r.params.numXChecks, 1:r.params.numYChecks);
	analysis.g2results = autoGaussianSurf(yi, xi, analysis.spatialRF);

	figure;
	subplot(2,1,1);
	imagesc(analysis.spatialRF);
	title([cellName ' 2d gaussian rf estimate']);
	colormap(bone); axis equal; axis tight;
	subplot(2,1,2);
	imagesc(analysis.g2results.G);
	colormap(bone); axis equal; axis tight;

	figure;
	surf(analysis.g2results.G);
	title([cellName ' 2d gaussian rf estimate']);
	colormap(bone);

	%% SVD spatial receptive field
	stixInd = allcomb(1:r.params.numYChecks, 1:r.params.numXChecks);
	stixMat = zeros(size(stixInd, 1), size(analysis.strf, 3));
	for ii = 1:(r.params.numYChecks * r.params.numXChecks)
		stixMat(ii, :) = analysis.strf(stixInd(ii,1), stixInd(ii,2), :);
	end

	[u, s, v] = svd(stixMat);

	% first column of u contains 1 spatial component of STA
	% individual frames of STA movie where RF was most clear

	spatialRF = zeros(r.params.numYChecks, r.params.numXChecks);
	for ii = 1:length(u)
		spatialRF(stixInd(ii,1), stixInd(ii,2)) = u(ii,1);
	end

	analysis.svdSRF = spatialRF;

	figure;
	imagesc(spatialRF); colormap(bone);
	title([cellName ' ' r.params.chromaticClass ' SVD spatial receptive field']);
	axis equal; axis tight;

	% fast peak find (currently also in getSTRFOnline)
	analysis.peaks.on = FastPeakFind(analysis.spatialRF);
	analysis.peaks.off = FastPeakFind(-1 * analysis.spatialRF);

	figure;
	imagesc(spatialRF); colormap(bone); hold on;
	plot(analysis.peaks.on(1:2:end),analysis.peaks.on(2:2:end),'+', 'color', [0 0.6 0.1], 'MarkerSize', 10);
	plot(analysis.peaks.off(1:2:end), analysis.peaks.off(2:2:end), 'r+', 'MarkerSize', 10);

	if neuron == 2
		r.secondary.analysis = analysis;
	else
		r.analysis = analysis;
	end
