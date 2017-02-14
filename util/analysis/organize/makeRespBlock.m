function r = makeRespBlock(r, groupBy, groupOrder)
	% r can be matrix of responses or data structure r

	if nargin < 3
		groupOrder = 1:length(groupBy);
	end

	if isstruct(r)
		resp = r.resp;
	else
		resp = r;
	end

	respBlock = zeros(length(groupBy), size(resp,1), size(resp,2));


	for ii = 1:size(resp, 1)
		[indo1, ind2] = ind2sub([length(groupBy), size(resp, 2)], ep);
	    r.block.resp(ind1, ind2, :) = r.resp(ep,:);
	end

	if isstruct
		r.respBlock = respBlock;
	else
		r = respBlock;
	end