function spatialRF = svdSTRF(strf, n)
	% INPUT: strf in Y,X,T format
	% OPTIONAL: number of columns of U to plot, default 1
	% 3Oct2016 - SSP - TODO: set up for RGB noise
	% 26Jan2016 - added new code from amath582, option to see 2nd and graph singular value energy


	if nargin < 2
		n = 1;
	end

	[numYChecks, numXChecks, ~] = size(strf);

	% create matrix with each stixel's STA as a row
	stixInd = allcomb(1:numYChecks, 1:numXChecks);
	stixMat = zeros(size(stixInd, 1), size(strf, 3));
	for ii = 1:(numYChecks * numXChecks)
		stixMat(ii, :) = strf(stixInd(ii,1), stixInd(ii,2), :);
	end

	[u, s, ~] = svd(stixMat);

	% first column of u contains 1 spatial component of STA
	% individual frames of STA movie where RF was most clear

	spatialRF = zeros(numYChecks, numXChecks);
	for ii = 1:length(u)
		spatialRF(stixInd(ii,1), stixInd(ii,2)) = u(ii,1);
	end

	figure;
	if n == 2
		spatialRF2 = zeros(numYChecks, numXChecks);
		for ii = 1:length(u)
			spatialRF2(stixInd(ii,1), stixInd(ii,2)) = u(ii,2);
        end
        % TODO : clean later
        if n == 3
            spatialRF3 = zeros(numYChecks, numXChecks);
            for ii = 1:length(u)
                spatialRF3(stixInd(ii,1), stixInd(ii,2)) = u(ii,3);
            end
            subtightplot(n,1,n,0.05);
            imagesc(spatialRF3);
            axis equal; axis tight;
        else
            subtightplot(2,1,2, 0.05);
        end
		imagesc(spatialRF2);
		axis equal; axis tight;

		subtightplot(n,1,1, 0.05);
	end
	imagesc(spatialRF); colormap('bone');
	axis equal; axis tight;

	figure();
	plot(1:length(diag(s)), diag(s), 'o', 'Color', getPlotColor('s', 0.5), 'MarkerEdgeColor', 'b');
	title(sprintf('sigma 1 captures %.2f% of energy', 100 * norm(stixMat) / norm(stixMat, 'fro')));
	set(gca, 'XLim', [0 10], 'YScale', 'log', 'Box', 'off', 'TickDir', 'out');
