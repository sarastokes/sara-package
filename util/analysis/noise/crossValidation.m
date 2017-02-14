function crossValidation(r, cvEpochs)
	% check accuracy of LN model
	% INPUT: 
	%	r 			data structure
	%	cvEpochs	which epochs to cross validate with
	%
	% Basic idea:
	%	1. Convolve the response with the stimulus to get the STRF
	%	2. Convolve the strf with the stimulus to get the prediction
	%
	% TODO: add upsample, frameRate -> frameRate*binsPerFrame


    binsPerFrame = 1;
	% get the epochs not used for cross validation
	strfEpochs = setdiff(1:r.numEpochs, cvEpochs);
    tmp.strf = zeros(size(r.analysis.strf));

	% recalculate the strf without cvEpochs
	for ii = 1:length(strfEpochs)
		ep = strfEpochs(ii);
		% this convolves the response with the stimulus
		[~, tmp] = getSTRFOnline(r, tmp, r.spikes(ep,:), r.seed(ii));
    end
	strf = tmp.strf / std(tmp.strf(:));

	response = []; prediction = [];

	for ii = 1:length(strfEpochs(ii))
		seed = r.seed(strfEpochs(ii));
		noiseStream = RandStream('mt19937ar', 'Seed', seed);

		stimulus = noiseStream.rand(r.params.numYChecks, r.params.numXChecks, r.params.numFrames) > 0.5;
		stimulus = double(stimulus) * 2 - 1; % rescale to contrast

		if binsPerFrame > 1
			stimulus = upsampleFrames(stimulus, binsPerFrame);
		end

  		prePts = r.params.preTime * 1e-3 * r.params.sampleRate;

		responseTrace = BinSpikeRate(r.spikes(strfEpochs(ii), prePts+1:end), r.params.frameRate, r.params.sampleRate);
		responseTrace = responseTrace(1:r.params.numFrames);
		responseTrace = responseTrace(:);

		% zero out the first second as the cell is likely adapting...
		stimulus(:,:,1:r.params.frameRate) = 0;
		responseTrace(1:floor(r.params.frameRate)) = 0;

		% convolve the strf with the stimulus
		pred = zeros(size(stimulus, 3), 1);
		padLength = size(stimulus, 3) - size(strf, 3);
		for m = 1:r.params.numYChecks
			for n = 1:r.params.numXChecks
				pTmp = real(ifft(fft([squeeze(strf(m,n,:)); zeros(padLength+20,1)]) .* ...
					fft([squeeze(stimulus(m,n,:)); zeros(20,1)])));
				pTmp(1:r.params.frameRate) = 0;
				pred = pred + pTmp(1:length(pred));
			end
		end
		% copy the response
		response = [response; responseTrace(r.params.frameRate+1:end)];
		% copy the prediction
		prediction = [prediction; pred(r.params.frameRate+1:end)];
		% copy the stimulus
	end

	% bin the nonlinearity
	nonlinearityBins = 100;
	[a, b] = sort(prediction(:));
	xSort = a;
	ySort = response(b);

	% bin the data
	valsPerBin = floor(length(xSort)/nonlinearityBins);
	xBin = mean(reshape(xSort(1:nonlinearityBins*valsPerBin), valsPerBin, nonlinearityBins));
	yBin = mean(reshape(ySort(1:nonlinearityBins*valsPerBin), valsPerBin, nonlinearityBins));

	%% CROSS VALIDATION
	cvResponses = []; cvPrediction = [];
	for ii = 1:length(cvEpochs)
		% get the cvEpoch responses to use later
		prePts = r.params.preTime * 1e-3 * r.params.sampleRate;
		responseTrace = BinSpikeRate(r.spikes(strfEpochs(ii), prePts+1:end), r.params.frameRate, r.params.sampleRate);
		responseTrace = responseTrace(1:r.params.numFrames);
		responseTrace = responseTrace(:);
		responseTrace(1:floor(r.params.frameRate)) = 0;
		% same as above.. get cvEpoch stimuli & responses
		noiseStream = RandStream('mt19937ar', 'Seed', r.seed(cvEpochs(ii)));
		stimulus = noiseStream.rand(r.params.numYChecks, r.params.numXChecks, r.params.numFrames) > 0.5;
		stimulus = double(stimulus) * 2 -1;
		stimulus(:,:,1:r.params.frameRate) = 0;
		% generate the linear prediction by for the stimulus
		for m = 1:r.params.numYChecks
			for n = 1:r.params.numXChecks
				pTmp = real(ifft(fft([squeeze(strf(m,n,:)); zeros(padLength+20,1)]) .* ...
					fft([squeeze(stimulus(m,n,:)); zeros(20,1)])));
				pTmp(1:r.params.frameRate) = 0;
				pred = pred + pTmp(1:length(pred));
			end
        end
        cvPrediction = [cvPrediction; pred'];
        cvResponses = [cvResponses; responseTrace'];
	end
%%

	loglikeli = [];  r2 = []; %err = [];
    plotPred = true;
    if plotPred 
        figure('windowstyle', 'docked');
        co = pmkmp(6,'cubicL');
    end
	% The default is linear interpolation
	for ii = 1:length(cvEpochs)
		tmpPred = interp1(xBin, yBin, cvPrediction(ii,:), 'linear', 'extrap');
		tmpPred = tmpPred(r.params.frameRate+1:end);
		tmpResp = cvResponses(ii, r.params.frameRate+1:end);
        if plotPred
            subtightplot(length(cvEpochs),1,ii, 0.05, [0.1 0.1], [0.1 0.1]);
            plot(tmpPred./max(tmpPred), 'Color', co(2,:), 'LineWidth', 1); hold on;
            plot(tmpResp./max(tmpResp), 'Color', co(3,:), 'LineWidth', 1); axis tight;
            set(gca, 'Box', 'off', 'TickDir', 'out');
        end
		% measure how well the LN model performed
		tmpLoglikeli = -sum(log(poisspdf(tmpResp(:), tmpPred(:)))); % log likelihood
		%tmpErr = mse(tmpResp(:), tmpPred(:)); % mean squared error
		tmpR = corrcoef(tmpResp(:), tmpPred(:)); % r^2

		% save out results
		loglikeli = [loglikeli; tmpLoglikeli];
		%err = [err; tmpErr];
		r2 = [r2; tmpR];
	end
