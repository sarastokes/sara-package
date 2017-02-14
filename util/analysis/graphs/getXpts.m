function xpts = getXpts(response, sampleRate)
  % get x-axis points quick
  % INPUT:    response (uses length)
  % OPTIONAL: sampleRate (default = 10000)

  if nargin < 2
    sampleRate = 10000;
  end

  xpts = (1:length(response));
  xpts = xpts / sampleRate;
