function pix = deg2pix(deg, micronsPerPixel)

  if nargin < 2
    micronsPerPixel = 0.8;
  end
  micronsPerDegree = 200;
  screenWidth = 912;
  pix = deg * screenWidth / micronsPerDegree * micronsPerPixel;
