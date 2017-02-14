function r = addEpoch(r1, r2)
	% combines 2 epoch blocks
	% runs faster if longer block is first

	r = r1;
	r.numEpochs = r.numEpochs + r2.numEpochs;
	r.log{end+1} = sprintf('%s  - merged with %s', datestr(now), r2.uuid);

	for ep = 1:r2.numEpochs
		r.spikes(end+1,:) = r2.spikes(ep,:);
		r.resp(end+1,:) = r2.resp(ep,:);
		r.spikeData.resp(end+1,:) = r2.resp(ep,:);
		r.spikeData.times{end+1} = r2.spikeData.times{ep};
		r.spikeData.amps{end+1} = r2.spikeData.amps{ep};
		if isfield(r, 'seed')
			r.seed(end+1) = r2.seed(ep);
		elseif isfield(r.params, 'seed')
			r.params.seed(end+1) = r2.params.seed(ep);
		end
		if isfield(r2, 'secondary')
			if isfield(r1,'secondary')
				r.secondary.spikes(end+1,:) = r2.secondary.spikes(ep,:);
				r.secondary.resp(end+1,:) = r2.secondary.resp(end+1,:);
				r.secondary.spikeData.resp(end+1,:) = r2.secondary.spikeData.resp(ep,:);
				r.secondary.spikeData.times{end+1} = r2.secondary.spikeData.times{ep};
				r.secondary.spikeData.amps{end+1} = r2.secondary.spikeData.amps{ep};
			else
				fprintf('r2 had secondary neuron but not r1\n');
			end
		end
	end
