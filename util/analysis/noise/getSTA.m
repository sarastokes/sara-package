function [sta, stimCov, stimMean] = getSTA(r, varargin)
	% preTime, stimTime, frameRate, sampleRate, frameDwell


	if isempty(r)
		ip = inputParser();
		ip.addParameter('spikes', @(x)ismatrix(x));
		ip.addParameter('seed', @(x)isvector(x));
		ip.addParameter('stimTime', @(x)isnumeric(x));
		ip.addParameter('preTime', 0, @(x)isvector(x));
		ip.addParameter('numChecks', [], @(x)isvector(x));
		ip.addParameter('frameDwell', 1, @(x)isvector(x));
		ip.addParameter('noiseClass', [], @(x)ischar(x));
		ip.addParameter('chromaticClass', 'achromatic', @(x)ischar(x));
		ip.addParameter('sampleRate', 10000, @(x)isvector(x));
		ip.addParameter('binsPerFrame', 1, @(x)isvector(x));
		ip.addParameter('frameRate', 60, @(x)isvector(x));
		ip.parse(varargin{:});

		spikes = ip.Results.spikes;
		seeds = ip.Results.seeds;
		stimTime = ip.Results.stimTime;
		preTime = ip.Results.preTime;
		frameDwell = ip.Results.frameDwell;
		sampleRate = ip.Results.sampleRate;
		frameRate = ip.Results.frameRate;
		numChecks = ip.Results.numChecks;
		chromaticClass = ip.Results.chromaticClass;
	else % use response structure
		ip = inputParser();
		ip.addParameter('binsPerFrame', 1, @(x)isnumeric(x));
		ip.parse(varargin{:});
		binsPerFrame = ip.Results.binsPerFrame;

		spikes = r.spikes;
		if isfield(r, 'seed')
			seeds = r.seed;
		else
			seeds = r.params.seed;
		end
		if isa(seeds, 'cell')
			seeds = mat2cell(seeds);
		end

		noiseClass = r.params.noiseClass;
		chromaticClass = r.params.chromaticClass;
		preTime = r.params.preTime;
		stimTime = r.params.stimTime;
		frameDwell = r.params.frameDwell;
		frameRate = r.params.frameRate;
		sampleRate = r.params.sampleRate;
		if isfield(r.params, 'numYChecks')
			numChecks = [r.params.numXChecks r.params.numYChecks];
		else
			numChecks = [1 1];
		end
	end

	binsPerFrame = ip.Results.binsPerFrame;
	binRate = frameRate * binsPerFrame;

	STA = zeros(1, binRate*numChecks(1)*numChecks(2));

	stimCov = zeros(binRate);
	stimMean = zeros(1, binRate);
	numSpikes = 0;
	numStim = 0;

 	numFrames = floor(stimTime/1000 * frameRate) / frameDwell;
  preF = floor(preTime/1000 * frameRate);
  stimF = floor(stimTime/1000 * frameRate);
	prePts = preTime * 1e-3 * sampleRate;

	if preTime > 0
		stimStart = prePts + 1;
	else
		stimStart = 1;
	end

	for ii = 1:size(spikes, 1)
		resp = spikes(ii,:);
		seed = seeds(ii);

		noiseStream = RandStream('mt19937ar', 'Seed', seed);

		if isempty(numChecks)
			noise = stdev * noiseStream.randn(1, numFrames);
		else
			% size(frames) = time, numXChecks, numYChecks
			frames = getSpatialNoiseFrames(numChecks(1), numChecks(2), numFrames, noiseClass, chromaticClass, seed);
		end

		stimulus = 2*(double(frames)/255)-1;

		if binsPerFrame > 1
			stimulus = upsampleFrames(stimulus, binsPerFrame);
		end

		spikeTimes = find(resp(stimStart:end) == 1);
		% convert to bin rate
		spikeTimes = ceil(spikeTimes/sampleRate*binRate);
		spikeTimes(spikeTimes > length(stimulus)) = [];
		response = spikeTimes;

		sr = makeStimRows(stimulus, binRate, response);
		STA = STA + sum(sr, 1);
		numSpikes = numSpikes + size(sr, 1);

    if nargout > 1
        sc = makeStimRows(stimulus(:), binRate, 1);
        numStim = numStim + size(sc,1);
        stimMean = stimMean + sum(sc, 1);
        stimCov = stimCov + (sc' * sc);
    end
    fprintf('Finished epoch %u\n',ii);
	end

	% divide by the number of spikes to get the STA
	sta = STA/numSpikes;
	sta = shiftdim(sta,1);
	if ~isequal(numChecks, [1 1])
		sta = reshape(sta, binRate, numChecks(2), numChecks(1));
	end
