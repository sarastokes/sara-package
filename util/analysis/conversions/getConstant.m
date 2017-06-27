function [x, unitStr, abbrev] = getConstant(cname)
	% return a constant
	% INPUT: constant name or abbrev
	%
	% 7Jun2017 - SSP - created

	cname = lower(cname);

	switch cname
	case {'avogadro', 'mol', 'N'}
		x = 6.023e-34;
		unitStr = 'mol^-1';
		abbrev = 'N';
	case {'planck', 'plank', 'h'}
		x = 6.626e-34;
		unitStr = 'J sec';
		abbrev = 'h';
	case 'c'
		% velocity of light in a vacuum
		x = 2.998e8;
		unitStr = 'm/sec';
	case {'boltzmann', 'boltzman', 'k'}
		x = 0;
		unitStr = 'J/K';
		abbrev = 'k';
	case {'outersegment', 'os'}
		% outer segment cross-sectional area
		x = 0.67;
		unitStr = 'um^2';
		abbrev = 'os';
	case {'quantalefficiency', 'efficiency', 'qe'}
		x = [0.37 1.7];
		fprintf('returned vector [cone rod]\n');
		abbrev = 'qe';
	% copunctual points from Wyszecki & Stiles, Color Science 2e, 1982
	% table 1 (5.14.2), p. 464
	case 'protan'
		x = [0.747 0.253];
	case 'deutan'
		x = [1.08 -0.80];
	case 'tritan'
		x = [0.171 0];
	end
