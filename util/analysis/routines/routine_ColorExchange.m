function w = routine_ColorExchange(r)

  cexcFcn = @(w, c) w(1) * c(1,:) + w(2)*c(2,:);

  ind1 = strfind('LMS', r.params.coneOne);
  ind2 = strfind('LMS', r.params.coneTwo);
  cws = [r.params.coneWeights(:,ind1), r.params.coneWeights(:, ind2)]';
  f1sign = r.analysis.F1 .* sign(r.analysis.P1);

  options = optimoptions('lsqcurvefit',...
    'MaxFunEvals', 1500,...
    'Display', 'iter');

  [w, resNorm, ~, exitFlag, opt] = lsqcurvefit(cexcFcn, [1 1], cws, -1*f1sign, [], [], options);
  fprintf('resNorm = %.3f\n', resNorm);

  if isempty(w > 0)
    fprintf('%s%s OFF cell with %.2f%s and %.2f%s\n', r.params.coneOne, r.params.coneTwo, w(1), w(2));
  elseif isempty(w < 0)
    fprintf('%s%s ON cell with %.2f%s and %.2f%s\n', r.params.coneOne, r.params.coneTwo, w(1), w(2));
  elseif w(1)>w(2)
    fprintf('%s-%s opponent cell with  %.2f%s %.2f%s\n', r.params.coneOne, r.params.coneTwo, w(1),r.params.coneOne, w(2), r.params.coneTwo);
  else
    fprintf('%s-%s opponent cell with  %.2f%s %.2f%s\n', r.params.coneOne, r.params.coneTwo, w(2), r.params.coneTwo, w(1), r.params.coneOne);
  end
