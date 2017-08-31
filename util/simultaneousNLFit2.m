function y = simultaneousNLFit2(params, xData)
	% scale L, M-iso linear filters by nonlinearities
    % xData is binned
    % 1 = mean
    % 2 = SD
    % 3 = spike rate (same for LMS)
    % 4 = scale factor for M

	
	y = [params(1) * normcdf(xData(1,:), params(2), params(3)), params(1) * normcdf(xData(2,:) * params(4), params(2), params(3))];