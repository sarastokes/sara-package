function y = spotAnnulusSMTF(params, radii)
  % radii is [radii(:), outer radius]
  % params are the usual
  % data should be a vector [spot annulus]

  spot = abs(params(1)*(1-exp(-(radii(1:end-1).^2)/(2*params(2)^2))) - params(3)*(1-exp(-(radii(1:end-1).^2)/(2*params(4)^2))));

  annulus = abs(params(1)*(1-exp(-(radii(end).^2)/(2*params(2)^2))) - params(3)*(1-exp(-(radii(end).^2)/(2*params(4)^2))) - spot);

  y = [spot annulus];
