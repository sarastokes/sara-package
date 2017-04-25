function [w, ft] = routine_ColorExchange(r, plotFlag)
  % 23Mar added plot option. might move to normal analysis

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

  if any(w > 0)
    fprintf('%s%s OFF cell with %.2f%s and %.2f%s\n', r.params.coneOne, r.params.coneTwo, r.params.coneOne, w(1), r.params.coneTwo, w(2));
  elseif any(w < 0)
    fprintf('%s%s ON cell with %.2f%s and %.2f%s\n', r.params.coneOne, r.params.coneTwo, r.params.coneOne, w(1), r.params.coneTwo, w(2));
  elseif w(1)>w(2)
    fprintf('%s-%s opponent cell with  %.2f%s %.2f%s\n', r.params.coneOne, r.params.coneTwo, w(1),r.params.coneOne, w(2), r.params.coneTwo);
  else
    fprintf('%s-%s opponent cell with  %.2f%s %.2f%s\n', r.params.coneOne, r.params.coneTwo, w(2), r.params.coneTwo, w(1), r.params.coneOne);
  end

  fprintf('Normalized cone weights are %.2f %.2f\n', w/max(abs(w)));

  ft = cexcFcn(w, cws);
  if nargin > 1
    figure; hold on;
    figPos(gcf, 0.8, 0.8);
    plot(1:length(ft), (-1*sign(r.analysis.P1)).*r.analysis.F1,...
    '-ok', 'LineWidth', 1);
    plot(1:length(ft), ft, 'b', 'LineWidth', 1);
    set(gca, 'Box', 'off');
    legend('Data', 'Fit');
    title([r.cellName sprintf(' - color exchange %.2f%s and %.2f%s', w(1), r.params.coneOne, w(2), r.params.coneTwo)]);
    ylabel('f1 amplitude'); xlabel('stimulus number');
    tightfig(gcf);
  end
