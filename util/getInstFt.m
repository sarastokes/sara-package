function instFt = getInstFt(spikes, fac, sampleRate)
  % spikes -> firing rate
  % INPUT: spikes (binary)
  % OPTIONAL:    fac  for filter (20)
  %             sampleRate (10000)
  % 
  %
  % 5Mar2017 - now works for block of spike responses
  % 16Apr2017 - works with 3 dim blocks

  if nargin < 2
      fac = 20;
  end
	if nargin < 3
		sampleRate = 10000;
	end

  if length(size(spikes)) == 3
      flag3 = true; 
      [n, m, t] = size(spikes);
      spikes = reshape(spikes, [n*m t]);
  else
      flag3 = false;
  end
  instFt = [];

  filterSigma = (fac/1000)*sampleRate;
  newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);

  for ii = 1:size(spikes,1)
	tmp = sampleRate * conv(spikes(ii,:), newFilt, 'same');
    instFt = cat(1, instFt, tmp);
  end
  
  if flag3
    instFt = reshape(instFt, n, m, t);
  end
    
