function fh = polarloop(xpts, ypts, avgFlag)
  % 25Mar2017 - SSP

  if max(xpts) > 2*pi
    xpts = deg2rad(xpts);
  end

  fh = figure();

  if nargin < 3
    polar([xpts xpts(1)], [ypts ypts(1)], '-ob');
  else
    ypts([1 end]) = (ypts(1)+ypts(end))/2;
    polar([xpts(1:end-1) xpts(1)], ypts, '-ob');
  end
