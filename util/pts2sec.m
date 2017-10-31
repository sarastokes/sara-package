function s = pts2sec(pts, sampleRate)
	% PTS2MS  Quick fcn for converting data points to ms
	%
	%	Input:
	%		pts 			number in data points
	%	Optional:
	%		sampleRate 		default is 10000 (hz)
	%	Output:
	%		secs 			number in seconds
	%	
	% 24Oct2017 - SSP

	if nargin == 1
		sampleRate = 10000;
	end

	s = pts/sampleRate;

