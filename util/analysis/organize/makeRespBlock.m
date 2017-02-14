function r = makeRespBlock(r, groupBy, groupOrder)
	% r can be matrix of responses or data structure r

	if nargin < 3
		groupOrder = 1:length(groupBy);
	end

	if isstruct(r)
		resp = r.resp;
        if isfield(r, 'spikes')
            spikes = r.spikes;
        else
            spikes = [];
        end
	else
		resp = r;
	end

	respBlock = zeros(length(groupBy), size(resp,1)/length(groupBy), size(resp,2));
    if ~isempty(spikes)
        spikeBlock = zeros(size(respBlock));
    end


	for ep = 1:size(resp, 1)
		[ind1, ind2] = ind2sub([length(groupBy), size(resp, 2)], ep);
	    respBlock(ind1, ind2, :) = resp(ep,:);
        if ~isempty(spikes)
            spikeBlock(ind1,ind2,:) = spikes(ep,:);
        end
	end

	if isstruct(r)
		r.respBlock = respBlock;
        if ~isempty(spikes)
            r.spikeBlock = spikeBlock;
        end
	else
		r = respBlock;
	end