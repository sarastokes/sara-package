function microns = deg2micron(deg, paramFlag)
	% convert cpd to microns
	% INPUT: number in degrees
	% OPTIONAL: paramFlag 	for fit parameters
	% OUTPUT: number in microns

	if nargin < 2
		paramFlag = false;
	else
		paramFlag = true;
	end

	micronsPerDegree = 200;
	if paramFlag
		microns = deg;
		microns(2) = deg(2) * micronsPerDegree;
		microns(4) = deg(4) * micronsPerDegree;
	else
		microns = deg * micronsPerDegree;
	end
