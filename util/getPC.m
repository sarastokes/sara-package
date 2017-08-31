function srf = getPC(strf, numPC)
  % get principal component from strf
  % INPUT:  strf        3d matrix with time as 3rd dimension
  %         numPC   (1) which principal component
  % OUTPUT: srf         2d rf (x,y) or sta (x,t)
  %
  % 11Mar2017 - added STA option
  % 12Aug2017 - removed it..

  if nargin < 2
    numPC = 1;
  end

  [m,n,t] = size(strf);

  [u, ~, ~] = svd(reshape(strf, m*n, t));

  srf = reshape(u(:, numPC), m, n);
