function phases = phaseWrap(phases, deg)
  % INPUT:    phases -180:180
  % OPTIONAL: deg (default = 180)

  if nargin == 1
      deg = 180;
  end

	ind = find(phases < deg/2);
	phases(ind) = phases(ind)+deg;

	ind = find(phases>deg/2);
	phases(ind) = phases(ind)-deg;
