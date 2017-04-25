function [sta,stc, totalStim, numSpikes] = getSTAgauss(r, varargin)
  %


  ip = inputParser();
  ip.addParameter('bpf', 1, @(x)isvector(x));
  ip.parse(varargin{:});
  binsPerFrame = ip.Results.bpf;


  binRate = 60;
  numSpikes = 0;
  stc = 0;
  stimMean = zeros(1, binRate);
  numStim = 0;
  STA = 0;
  totalStim = [];

  chromaticClass = r.params.chromaticClass;
  preTime = r.params.preTime;
  stimTime = r.params.stimTime;
  frameRate = r.params.frameRate;
  sampleRate = r.params.sampleRate;

  binRate = frameRate * binsPerFrame;

 	numFrames = floor(stimTime/1000 * frameRate);
  preF = floor(preTime/1000 * frameRate);
  stimF = floor(stimTime/1000 * frameRate);
	prePts = preTime * 1e-3 * sampleRate;
  stimStart = prePts + 1;

  if ~isfield(r.params, 'frameDwell')
    r.params.frameDwell = 1;
  end

  if isfield(r, 'seed')
    seeds = r.seed;
  else
    seeds = r.params.seed;
  end

  for ii = 1:r.numEpochs
    resp = r.spikes(ii,:);

    seed = seeds(ii);

    noiseStream = RandStream('mt19937ar', 'Seed', seed);

		% noise = r.params.stdev * noiseStream.randn(1, numFrames);

    % stimulus = getSpatialNoiseFrames(1,1, numFrames, r.params.noiseClass, seed);
    stimulus = getGaussianNoiseFrames(numFrames, 1, r.params.stdev, seed);
    % stimulus = 2*(double(frameValues)/255)-1;

    % if binRate > obj.frameRate
    %     n = round(binRate / obj.frameRate);
    %     frameValues = ones(n,1)*frameValues(:)';
    %     frameValues = frameValues(:);
    % end
    % plotLngth = round(binRate*0.5);

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
      stimMean = stimMean + sum(sc,1);
      stc = stc + (sc' * sc);
    end
    totalStim = [totalStim; sc];
  end

  % divide by the number of spikes to get the sta
  sta = STA/numSpikes;
  % stc = stc/numStim;
