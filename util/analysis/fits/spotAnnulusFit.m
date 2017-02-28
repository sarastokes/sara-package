function params = FitFullsMTF(data, radii, params0)
  % fit both spot and annulus sMTF simultaneously
  % INPUT: data = f1 amplitudes [spot, annulus]
  %         radii   [radii, outerRadius]
  %         params0   [Kc sigmaC Ks sigmaS]
  if nargin < 3
    yd = abs(data(:)');
    params0 = [max(yd) 200 0.1*max(yd) 400];
    fprintf('using default params\n');
  end

  options = optimoptions('lsqcurvefit',...
  'MaxFunEvals', 1500,...
  'Display', 'iter');

  % params = nlinfit(radii, data, @spotAnnulusSMTF, params0);

  [params, resNorm] = lsqcurvefit(@spotAnnulusSMTF, params0, radii, data, zeros(size(params0)), [], options);

  fprintf('Kc = %.2f, Ks = %.2f, sigmaC = %.2f, sigmaS = %.2f\n', params(1), params(3), params(2), params(4));
  fprintf('resnorm = %.2f\n', resNorm);
