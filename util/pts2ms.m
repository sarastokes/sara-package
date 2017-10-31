function ms = pts2ms(pts, sampleRate)
	% PTS2MS  Quick fcn for converting data points to ms
	%
	%	Input:
	%		pts 			number in data points
	%	Optional:
	%		sampleRate 		default is 10000 (hz)
	%	Output:
	%		ms 				number in ms
	%	
	% 24Oct2017 - SSP
	
	if nargin == 1
		sampleRate = 1e4;
	end
	ms = pts * 1e3/sampleRate;