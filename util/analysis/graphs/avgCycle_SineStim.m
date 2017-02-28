function [avgCycles, fh] = avgCycle_SineStim(r, varargin)
% graph cycle averages for voltage clamp sine stimuli
% INPUT: r = data structure
% OPTIONAL: binRate (480)
%           cycleNum (1)    number of cycles per avg
%           graph (true)    create new figures
% OUTPUT:   avgCycles = all the data in a structure
%           fh = figure handle

    ip = inputParser();
    ip.addParameter('binRate', 480, @(x)isvector(x));
    ip.addParameter('cycleNum', 1, @(x)isvector(x));
    ip.addParameter('graph', true, @(x)islogical(x));
    ip.parse(varargin{:});
    binRate = ip.Results.binRate;
    cycleNum = ip.Results.cycleNum;
    graph = ip.Results.graph;

    if ~isfield(r.params, 'waitTime')
      r.params.waitTime = 0;
    end

    prePts = r.params.preTime+r.params.waitTime*1e-3*r.params.sampleRate;
    stimPts = r.params.stimTime-r.params.waitTime*1e-3*binRate;
	  binSize = binRate/(r.params.temporalFrequency/cycleNum);
	  numBins = floor(stimPts/binSize);
	  avgCycles = struct();
	err = []; avg = [];
	for ii = 1:length(r.params.stimClass)
		avgCycles.(r.params.stimClass(ii)) = [];
		avgCycles.all.(r.params.stimClass(ii)) = [];
	end

	for ii = 1:r.numEpochs
		[stim,trial] = ind2sub([length(r.params.stimClass) size(r.respBlock,2)], ii);
		sc = r.params.stimClass(stim);
		tmp = zeros(1, floor(binSize));
		y = r.resp(ii,:);
	    % High-pass filter to get rid of drift.
	    y = highPassFilter(y, 0.5, 1/r.params.sampleRate);
	    if prePts > 0
	        y = y - median(y(1:prePts));
	    else
	        y = y - median(y);
	    end
	    y = binData(y(prePts+1:end), binRate, r.params.sampleRate);

		for k = 1:numBins
			index = round((k-1)*binSize)+(1:floor(binSize));
			index(index > length(y)) = [];
			ytmp = y(index);
			% tmp = tmp + ytmp(:)';
            try 
              tmp = [tmp; ytmp(:)'];
            catch
              fprintf('ep %u bin %u size tmp is %u%u and size ytmp is %u%u\n',ii,k,... 
                  size(tmp,1), size(tmp,2), size(ytmp,1), size(ytmp,2));
            end                       
		end
		tmp( ~any(tmp,2), : ) = [];
		avgCycles.all.(sc) = [avgCycles.all.(sc); tmp];
		% tmp = tmp/numBins;
		tmp = mean(tmp, 1);
		avgCycles.(sc) = [avgCycles.(sc); tmp];

		t = fft(tmp);
	    ft.F0(stim,trial) = abs(t(1))/length(tmp*2);
	    ft.F1(stim,trial) = abs(t(2))/length(tmp*2);
	    ft.F2(stim,trial) = abs(t(3))/length(tmp*2);
	    ft.F2F1(stim,trial) = ft.F2(stim,trial)/ft.F1(stim,trial);
	    ft.P1(stim,trial) = angle(t(2)) * 180/pi;
	    ft.P2(stim,trial) = angle(t(3)) * 180/pi;
    end
    if graph
    	fh = blankRespFig('vc');
    	co = pmkmp(r.numEpochs, 'CubicL');
    else
        fh = [];
    end
	xpts = linspace(1, r.params.stimTime/numBins, binSize);
	for ii = 1:length(r.params.stimClass)
		err = [err, sem(avgCycles.all.(r.params.stimClass(ii)))'];
		avg = [avg, mean(avgCycles.(r.params.stimClass(ii)),1)'];
        if graph
            plot(xpts, mean(avgCycles.(r.params.stimClass(ii)),1),...
                'Parent', fh.resp,...
                'Color', getPlotColor(r.params.stimClass(ii)), 'LineWidth', 1);
        end
    end
    stimTrace = getStimTrace(r.params, 'modulation', 'coneContrast', 0.3);
    if graph
        plot(stimTrace(r.params.preTime+1: r.params.preTime + (r.params.stimTime/numBins)),...
            'Parent', fh.stim, 'Color', 'k', 'LineWidth', 1);
        title(fh.resp, [r.cellName ' - cycle averages at ' num2str(r.holding) 'mV']);
        xlabel('time (msec)');
    end
	avgCycles.pts = [xpts', avg, err]; % TODO: clean up struct
	avgCycles.ft = ft; avgCycles.numBins = numBins;
    avgCycles.stim = stimTrace(r.params.preTime+1:r.params.preTime + (r.params.stimTime/numBins));
