function [val, ind] = closest(n, vec)
	% CLOSEST  Finds vector member closest to N
	%
	% 29Aug2017 - SSP - created

	[val, ind] = min(abs(vec - n));
	