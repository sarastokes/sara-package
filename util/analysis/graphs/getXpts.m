function xpts = getXpts(response, varargin)
  % get x-axis points quick
  % INPUT:    response (uses length)
  % OPTIONAL: 'sampleRate' (default = 10000)
  %           'firingRate' (length of instFt)
  %
  % 16Apr2017 - added option for firing rate xpts

  ip = inputParser();
  ip.addParameter('firingRate', [], @ismatrix);
  ip.addParameter('sampleRate', 10000, @isnumeric);
  ip.parse(varargin{:});
  firingRate = ip.Results.firingRate;
  sampleRate = ip.Results.sampleRate;
  
  if isempty(firingRate)
    if length(response) > 1
      xpts = (1:length(response));
    else
      xpts = 1:response;
    end
  else
      xpts = linspace(0, length(response), length(firingRate));
  end
  
  xpts = xpts / sampleRate;
