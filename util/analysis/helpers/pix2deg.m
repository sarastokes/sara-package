function cpd = pix2deg(spatialFrequencies, micronsPerPixel)
  % convert spatial frequencies in symphony protocol to cycles per degree
  % INPUT: spatialFrequencies
  % OPTIONAL: micronsPerPixel - default uses latest 10x value (this won't match early recordings or 60x tho, those will need r.params input)

  if nargin < 2
    micronsPerPixel = 0.8;
  end
  micronsPerDegree = 200;
  screenWidth = 912;

  cpd = spatialFrequencies / screenWidth / micronsPerPixel * micronsPerDegree;
