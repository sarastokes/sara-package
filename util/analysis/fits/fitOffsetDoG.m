function [params, fit, fh] = fitOffsetDoG(radii,responses,params0, aoFlag)
  % for smtf spot --> params = [kc rc ks rs offset]
  % will be converted to microns
  % aoFlag = call from analyzeOnline

  if nargin < 4
    d = 'final';
    units = 'microns';
    if radii(end) == 456
      radii = pix2micron(radii, 10);
      fprintf('converted to microns\n');
    end
  else
    d = 'iter';
    units = 'pix';
  end

  if nargin < 3 || isempty(params0)
    yd = abs(responses(:)');
    params0 = [max(yd) 200 0.1*max(yd) 400 0];
  end

  offsetFcn = @(v, radii)(v(5) + (v(1)*(1-exp(-(radii/2).^2 ./ (2*v(2).^2))) - v(3)*(1-exp(-(radii/2).^2 ./ (2*v(4)^2)))));

  options = optimset('MaxIter', 2000, 'MaxFunEvals', 3000, 'Display', d);

  [params,resNorm] = lsqcurvefit(offsetFcn, params0, radii, responses, zeros(size(params0)), [1e4 2e3 1e4 5e3 100], options);

  fprintf('Kc = %.2f, Rc = %.2f, Ks = %.2f, Rs = %.2f, offset = %.2f (%s)\n resnorm = %.2f\n', params, units, resNorm);

  if nargout > 1
    fit = offsetFcn(params, radii);
  end

  if nargout == 3
    figure(); hold on;
    plot(radii, responses, '-ok', 'LineWidth', 1);
    plot(radii, fit, 'b', 'LineWidth', 1);
    xlabel('radii (microns)'); ylabel('f1 amplitude');
  end
