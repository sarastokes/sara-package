function y = asymGaussian(x, p)
	% ASYMGAUSSIAN  Generates an asymmetric Gaussian
	%
	% INPUTS:
	%	x 			values to evaluate 
	%	p           [mu, sigma, fac] or [BL, A, mu, sigma, fac]
	%
	% If fitting something like a normalized temporal tuning curve, cut 
	% down the free parameters by skipping BL and A (defaults to 0 and 1).
	%
	% function:
	%	BL + A * exp(-((x - mu)^2) / (x-mu)*2*sigma^2)) for x > mu
	%	BL + A * exp(-((x-mu)^2) / (x-mu)*2*sigma^2) * fac) for x < mu
	%	 
	% where BL is the baseline, A is a scaling factor, mu is the mean/peak,
	% sigma is the gaussian sd, fac is the amount sd is scaled by for the
	% right side of the gaussian.
	% For some intuition:
	% y = asymGaussian(0:0.01:1, [0, 1, 0.5, 0.3, 1]);
	% y = asymGaussian(0:0.01:1, [0, 1, 0.5, 0.3, 0.5]);
	% y = asymGaussian(0:0.01:1, [0, 1, 0.5, 0.3, 1.5]);
	%
	% 30Aug2017 - SSP
    
    if p == 3
        y = exp(-((x-p(1)).^2) ./ ... 
		((heaviside(x-p(1))*(2*p(2)^2) + ... 
        (1-heaviside(x-p(1)))*(2*(p(2)^2)*p(3)))));
    else
    	y = p(1) + p(2) * exp(-((x-p(3)).^2) ./ ... 
		((heaviside(x-p(3))*(2*p(4)^2) + ... 
        (1-heaviside(x-p(3)))*(2*(p(4)^2)*p(5)))));
    end