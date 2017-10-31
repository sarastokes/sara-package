function [spikeTimes, spikeBinary, rawResponse] = demoWithPoissonSpikes(spikeRate, varargin)
	% DEMOWITHPOISSONSPIKES  Generate Poisson spiking
	% 
	%	Input:
	% 		spikeRate 		spikes/sec
	%	One of these:
	%		pts 			how many data points to generate
	%		sec 			response length in seconds
	% 		msec 			response length in milliseconds
	%	Optional:
	%		sampleRate 		points/sec (10000)
    %       output          'times', 'binary', 'raw'
	%	Output:
	%		response		spike binary matrix (1 x dataPoints)
	%
	%	Make sure units are correct!
	%
	%	25Oct2017 - SSP
	
	ip = inputParser();
	addParameter(ip, 'pts', [], @isnumeric);
	addParameter(ip, 'sec', [], @isnumeric);
	addParameter(ip, 'msec', [], @isnumeric);
	addParameter(ip, 'sampleRate', 1e4, @isnumeric);
	parse(ip, varargin{:})
	
	sampleRate = ip.Results.sampleRate;
	
	% Get data points from whatever unit was provided
	if ~isempty(ip.Results.pts)
		dataPoints = ip.Results.pts;
	elseif ~isempty(ip.Results.sec)
		dataPoints = ip.Results.sec/sampleRate;
	elseif ~isempty(ip.Results.msec)
		dataPoints = ip.Results.msec*1e3/sampleRate;
	end
	
	% Convert rate from spikes/sec to spikes/data point
	spikeRate = spikeRate/sampleRate;
	
	spikeTimes = [];
	nextSpike = -log(rand(1))/spikeRate;
	while nextSpike <= dataPoints
		spikeTimes = cat(2, spikeTimes, round(nextSpike));
		nextSpike = nextSpike - log(rand(1))/spikeRate;
	end
	
	fprintf('Generated %u spikes\n', numel(spikeTimes));
	
	if nargout > 1
		spikeBinary = zeros(1, dataPoints);
		spikeBinary(spikeTimes) = 1;
        if nargout == 3
            % This is a hack but looks okay
            load spikeShape.mat; % in util folder
            % White noise - too many high frequencies?
            noiseBinary = normrnd(0, 0.3, size(spikeBinary)); 
            noiseBinary(spikeTimes) = 1;
            rawResponse = conv(noiseBinary, demoSpike, 'same');
        end
	end