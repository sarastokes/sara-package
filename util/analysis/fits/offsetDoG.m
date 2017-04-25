function p = offetDoG(params, radii)

params(5) + (params(1)*(1-exp(-(radii/2).^2 ./ (2*params(2).^2))) - params(3)*(1-exp(-(radii/2).^2 ./ (2*params(4)^2))));
