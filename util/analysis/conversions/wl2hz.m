function v = wl2hz(wl, refInd)
	% convert wavelength to frequency
	% INPUTS: wl (nm)
	% OPTIONAL: refractive index (default = 1)
	% OUTPUTS: frequency
	%
	% 7Jun2017 - SSP - created

	if nargin == 1
		refInd = 1;
	end

	c = 3e8; % meters/sec
	wl = wl * 1e-9; % nm->m

	v = c/(wl*refInd);


