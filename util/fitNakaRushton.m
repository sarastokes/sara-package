function [params, fitdata, str] = fitNakaRushton(xvals, resp, p0)
	% FITNAKARUSHTON  Fit CRF data to 4 param Naka Rushton fcn
	%
	% INPUTS:	
	%	xvals		contrast/intensity used in CRF
	%	resp 		response at each contrast (like F1amp)
	% OPTIONAL:
	%	p0 			initial parameters
	% OUTPUTS:
	%	params 		fit parameters
	%	fitdata 	fitted data
	%	str			results display string
	%
	% parameters = [A C50]
	% function: 
	%	R(C) = A*(C^n/(C^(n*s) + C50^(n*s)))
	% where C is the contrast, C50 is the halfmax contrast, n is the slope, 
    % s is the saturation and A is the max response amplitude
	%
	% 29Aug2017 - SSP

	if nargin < 3
		p0 = [max(resp) 0.5 1 1];
	end

	nrfcn = @(p, contrasts)(p(1) .* (contrasts.^p(3) ./ ... 
        (contrasts.^(p(4)*p(3)) + p(2)^(p(3)*p(4)))));

  	options = optimset('MaxIter', 2000, 'MaxFunEvals', 3000,... 
  		'TolX', 1e-6, 'Display', 'final');

	[params, resNorm] = lsqcurvefit(nrfcn, p0, xvals, resp,... 
        [0 0 0 0], [Inf 1 Inf Inf], options);

	str = sprintf('A = %.2g, C50 = %.2g, n = %.2g, s = %.2g  (%.2g)',... 
        params, resNorm);
    
    if nargout > 1
        fitdata = nrfcn(params, xvals);
    end

	fprintf(['nakarushton - ', str, '\n']);