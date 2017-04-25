function srf = getPC(strf, numPC, staFlag)
  % get principal component from strf
  % INPUT:  strf        3d matrix with time as 3rd dimension
  %         numPC   (1) which pc
  %         staFlag (f) get best (x,t), not best (x,y)
  % OUTPUT: srf         2d rf (x,y) or sta (x,t)
  %
  % 11Mar2017 - added STA option

  if nargin < 2
    numPC = 1;
  end
  if nargin < 3
    staFlag = false;
  end

  [m,n,t] = size(strf);
  if staFlag
    tmp = shiftdim(strf,1);
    tmp = reshape(strf, t*m,n);
  else
    tmp = reshape(strf, m*n,t);
  end

  [u, s, v] = svd(tmp);

  if staFlag
  else
    srf = reshape(u(:, numPC), m, n);
  end
