function Z = subunitSim(f, p, params)
	% simulate gaussian subunit response to grating
	% INPUTS: 
	% 	f 		spatial frequencies
	%	p 		orientations (degrees)
	%	params	[k w1 w2 x0 y0 p0 lag]
	% OUTPUT:
	%	Z 		response (complex number)

	k = params(1); w1 = params(2); w2 = params(3);
	x0 = params(4); y0 = params(5); 
	p0 = params(6); lag = params(7);

	efun = @(f,p) pi*k*w1*w2*exp(-(pi*w1*w2*f).^2.*((sin(p-p0).^2/w1^2)+(cos(p-p0).^2/w2^2)));
	earg = @(f,p) 2*pi*f.*sqrt(x0^2 + y0^2)^(0.5) .* cos(p-atan(y0/x0))+lag;

	if numel(f) == 1
		f = f + zeros(size(p));
		fprintf('single spatial frequency\n');
	elseif numel(p) == 1
		p = p + zeros(size(p));
		fprintf('single orientation \n');
	end

	if max(p) > 2*pi
		p = deg2rad(p);
	end
	if p0 > 2*pi
		p0 = deg2rad(p0);
	end
	if lag > 2*pi
		p0 = deg2rad(p0);
	end

	R = efun(f, p);
	theta = earg(f, p);
	Z = abs(R) .* exp(i*theta);