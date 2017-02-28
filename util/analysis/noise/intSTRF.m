function [integrationSTRF r] = intSTRF(strf, intTime, varargin)

	ip = inputParser();
	ip.addParameter('graph', false, @islogical);
	ip.addParameter('frameRate', 60, @isnumeric);
	ip.addParameter('sigm', 2, @isnumeric);
	ip.parse(varargin{:});
	graph = ip.Results.graph;
	frameRate = ip.Results.frameRate;
	sigm = ip.Results.sigm;

	if isstruct(strf)
		r = strf;
		strf = strf.analysis.strf;
	else
		r = [];
	end

	intPts = round(intTime * frameRate / 1e3);	
	integrationSTRF = sum(strf(:,:,1:intPts), 3);

	if graph
		figure('Color', 'w');
		imagesc(imgaussfilt(integrationSTRF, sigm))
		tightfig(gcf);
		axis equal; axis off;
	end

	if ~isempty(r)
		r.analysis.intSTRF = integrationSTRF;
	end


