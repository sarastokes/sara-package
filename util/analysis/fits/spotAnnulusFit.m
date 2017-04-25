function [params, resNorm, fit] = spotAnnulusFit(data, radii, params0)
  % fit both spot and annulus sMTF simultaneously
  % INPUT: data = f1 amplitudes [spot, annulus]
  %         radii   [radii, outerRadius], leave empty if data is struct
  %         params0   [Kc sigmaC Ks sigmaS]
  %         micronFlag      (f), include to output in microns, otherwise pix
  % OUTPUT: params    fit parameters
  %         resNorm   residual
  %
  % SSP 25Feb2017

  if nargin < 2 && ~isstruct(data(1))
    error('include radii if not using data structure inputs');
  end
  if isstruct(data(1))
    tmp = data; data = [];
    data = [tmp(1).analysis.F1, tmp(2).analysis.F1];
    if nargin < 2
      radii = [tmp(1).params.radii 456];
    end
  end

  if nargin < 3
    yd = abs(data(:)');
    params0 = [max(yd) 200 0.1*max(yd) 400];
    fprintf('using default params\n');
  end

  options = optimoptions('lsqcurvefit',...
  'MaxFunEvals', 1500,...
  'Display', 'iter');

  [params, resNorm] = lsqcurvefit(@spotAnnulusSMTF, params0, radii, data, zeros(size(params0)), [], options);

  if nargin < 4
    unit = 'pix';
  else
    unit = 'um';
    params(2) = pix2micron(params(2), 10);
    params(4) = pix2micron(params(4), 10);
  end

  fprintf('Kc = %.2f, Ks = %.2f, sigmaC = %.2f, sigmaS = %.2f (%s)\n', params(1), params(3), params(2), params(4), unit);
  fprintf('resnorm = %.2f\n', resNorm);

  if nargout > 2
    fit = spotAnnulusSMTF(params, radii);
  end
