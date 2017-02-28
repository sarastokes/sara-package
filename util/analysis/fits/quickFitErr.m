function [err, r2] = quickFitErr(fit, data)

  d = data-fit;
  err = sum(sum(d .* d));
  if nargout > 1
    r2 = 1 - err/sum((data-mean(data)).^2));
  end
