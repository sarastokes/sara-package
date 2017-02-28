function [err, fit] = staFit(w, sta, data)
  % INPUTS:     w = scalar weight
  %             sta = model linear filter
  %             data = same size as sta

  fit = w * sta;
  err = 0;
  d = (data-fit);
  err = err + sum(sum(d.*d));
