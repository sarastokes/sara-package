function instFt = getInstFt(spikes, sampleRate, fac)
	% instantaneous firing rate
    if nargin < 3
        fac = 20;
    end
	if nargin <2 
		sampleRate = 10000;
	end
	filterSigma = (fac/1000)*sampleRate;
	newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);
	instFt = sampleRate*conv(spikes, newFilt, 'same');
end