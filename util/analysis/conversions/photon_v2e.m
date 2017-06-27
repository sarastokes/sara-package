function [Ephoton, unitStr] = photon_v2e(v)
	% get energy of a photon at a specific frequency
	% INPUT: v = frequency
	% OUTPUT: Ephoton = 
	%
	% 7Jun2017 - SSP - created

	h = getConstant('planck');

	Ephoton = h*v; % J
	unitStr = 'J';