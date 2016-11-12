function instFt = getInstFt(spikes, sampleRate)
	% instantaneous firing rate
	if nargin <2 
		sampleRate = 10000;
	end
	filterSigma = (20/1000)*sampleRate;
	newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);
	instFt = sampleRate*conv(spikes, newFilt, 'same');
end