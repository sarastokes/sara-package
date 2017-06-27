function wl = hz2wl(v, refInd)
	% convert frequency to wavelength
	% INPUTS: v (hz)
	% OPTIONAL: refractive index (default = 1)
	% OUTPUTS: wl (nm)
	%
	% 7Jun2017 - SSP - created

	if nargin == 1
		refInd = 1;
	end

	c = 3e8; % meters/sec
	wl = c/(v*n);
	wl = wl * 1e9; % m->nm