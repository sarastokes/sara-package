classdef MeanGratingFigure < symphonyui.core.FigureHandler
	% TODO: haven't used random SFs or numReps > 1 for avg gratings yet but should make this compatible with that anyway
	% 		some distinction b/w drifting and reversing??
	% 		show only one color?
	%		make code more concise once this works well

	% 23Oct - first version based on max's cycleaveragefigure

properties 
	device
	xvals
	onlineAnalysis
	preTime
	stimTime
	temporalFrequency
	chromaticClass
    plotColor
	numReps					% for now, let this stay at 1
end

properties
	axesHandle
%	colorIndex
	storedSweep

	epochNum
    xaxis
	% calculated:
	F1amp
	F1phase
	% the corresponding lines:
	newF1amp
	newF1phase
end

methods
	function obj = MeanGratingFigure(device, xvals, onlineAnalysis, preTime, stimTime, varargin)
		obj.device = device;
  		obj.xvals = xvals;
  		obj.onlineAnalysis = onlineAnalysis;
  		obj.preTime = preTime;
  		obj.stimTime = stimTime;

  		ip = inputParser();
  		ip.addParameter('temporalFrequency', [], @(x)ischar(x) || isvector(x));
  		ip.addParameter('chromaticClass',[] , @(x)ischar(x));
  		ip.addParameter('numReps', 1, @(x)isvector(x));
  		ip.parse(varargin{:});

  		obj.temporalFrequency = ip.Results.temporalFrequency;
        obj.chromaticClass = ip.Results.chromaticClass;
		obj.numReps = ip.Results.numReps;

        obj.plotColor = zeros(2,3);
        if ~isempty(obj.chromaticClass)
            [obj.plotColor(1,:),~] = getPlotColor(obj.chromaticClass);
        end
  		obj.plotColor(2,:) = obj.plotColor(1,:) + (0.5 * (1-obj.plotColor(1,:)));


  		% init some variables
		obj.epochNum = 0;       
		obj.xaxis = obj.xvals; % will be needed later
		obj.F1amp = zeros(size(obj.xvals));
		obj.F1phase = zeros(size(obj.xvals));

		% check for stored data, init if empty
		[storedData, colorIndex] = obj.storedAverages();
        if isempty(colorIndex)
        	colorIndex = [0 0 0 0];
        end
        if isempty(storedData)
        	cc = {'achrom' 'liso' 'miso' 'siso'};
        	for ii = 1:4
	        	storedData.(cc{ii}).F1amp = [];
    	    	storedData.(cc{ii}).F1phase = [];
    	    end
        end
        obj.storedAverages(storedData, colorIndex);

		obj.createUi();
	end

	function createUi(obj)
		import appbox.*;
		toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

		clearStoredButton = uipushtool(...
			'Parent', toolbar,...
			'TooltipString', 'Clear saved gratings',...
			'Separator', 'off',...
			'ClickedCallback', @obj.onSelectedClearStored);
		setIconImage(clearStoredButton, symphonyui.app.App.getResource('icons/sweep_clear.png'));

        storeSweepButton = uipushtool( ...
            'Parent', toolbar, ...
            'TooltipString', 'Store Sweep', ...
    	    'Separator', 'on', ...
            'ClickedCallback', @obj.onSelectedStoreSweep);
        setIconImage(storeSweepButton, symphonyui.app.App.getResource('icons/sweep_store.png'));
            
        obj.axesHandle(1) = subplot(3,1,1:2,...
			'Parent', obj.figureHandle,...
			'FontName', 'Roboto',...
			'FontSize', 10,...
			'XTickMode', 'auto',...
			'XScale', 'log');
        ylabel(obj.axesHandle(1), 'f1 amp');

        obj.axesHandle(2) = subplot(3,1,3,...
        	'Parent', obj.figureHandle,...
        	'FontName', 'Roboto',...
        	'FontSize', 10,...
        	'XTickMode', 'auto',...
        	'XScale', 'log');
        ylabel(obj.axesHandle(2), 'f1 phase');

        set(obj.figureHandle, 'Color', 'w');
        obj.setTitle([obj.device.name ' Mean Grating Response']);
	end

	function setTitle(obj, t)
		set(obj.figureHandle, 'Name', t);
		title(obj.axesHandle(1), t);
	end

	function clear(obj)
		cla(obj.axesHandle);
	end

	function handleEpoch(obj, epoch)
		if ~epoch.hasResponse(obj.device)
			error(['Epoch does not contain a response for', obj.device.name]);
		end

		obj.epochNum = obj.epochNum + 1;

		if isempty(obj.temporalFrequency)
			tempFreq = epoch.parameters('temporalFrequency');
		else
			tempFreq = obj.temporalFrequency;
		end

		response = epoch.getResponse(obj.device);
		responseTrace = response.getData();
		sampleRate = response.sampleRate.quantityInBaseUnits;

		responseTrace = getResponseByType(responseTrace, obj.onlineAnalysis);

		% bin the data
		responseTrace = responseTrace(obj.preTime/1000*sampleRate+1 : end);
  		binRate = 60;
  		binWidth = sampleRate / binRate; % Bin at 60 Hz.
  		numBins = floor(obj.stimTime/1000 * binRate);
  		binData = zeros(1, numBins);
		for k = 1 : numBins
	        index = round((k-1)*binWidth+1 : k*binWidth);
		    binData(k) = mean(responseTrace(index));
		end
		binsPerCycle = binRate / tempFreq;
		numCycles = floor(length(binData)/binsPerCycle);
		if numCycles == 0 % catch error with temporal tuning protocol
		  error('Make sure stimTime is long enough for at least 1 complete cycle');
		end
		cycleData = zeros(1, floor(binsPerCycle));
		for k = 1 : numCycles
		    index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
		    cycleData = cycleData + binData(index);
		end
		cycleData = cycleData / k;

		% get the F1 amplitude and phase
		ft = fft(cycleData);
		f1amp = abs(ft(2))/length(ft)*2;
		f1phase = angle(ft(2)) * 180/pi;

		obj.F1amp(obj.epochNum) = f1amp;
		obj.F1phase(obj.epochNum) = f1phase;

		% plot the most recent trace
  		if isempty(obj.newF1amp)
    		obj.newF1amp = line(obj.xaxis, obj.F1amp, 'parent', obj.axesHandle(1));
    		set(obj.newF1amp, 'Color', obj.plotColor(1,:), 'linewidth', 1, 'marker', 'o');
  		else
    		set(obj.newF1amp, 'XData', obj.xaxis, 'YData', obj.F1amp);
    		set(obj.axesHandle, 'XLim', [floor(min(obj.xaxis)) ceil(max(obj.xaxis))]);
  		end

  		if isempty(obj.newF1phase)
    		obj.newF1phase = line(obj.xaxis, obj.F1phase, 'parent', obj.axesHandle(2));
    		set(obj.newF1phase, 'Color', obj.plotColor(1,:), 'linewidth', 1, 'marker', 'o');
  		else
    		set(obj.newF1phase, 'XData', obj.xaxis, 'YData', obj.F1phase);
  		end

  		%% TODO: could be less redundant but at least it works
  		[storedData, colorIndex] = obj.storedAverages();
        if isempty(colorIndex)
            colorIndex = [0 0 0 0];
        else
  			colorIndex % print to cmd line
  			if isempty(storedData)
  				error('stored data is empty');
  			end
  			if colorIndex(1) > 0
  				if ~isempty(storedData.achrom.F1amp)
  					if obj.storedSweep.achrom.F1amp.line.isvalid

  					else
  						obj.storedSweep.achrom.F1amp.line = line(obj.xaxis, storedData.achrom.F1amp,...
  							'Parent', obj.axesHandle(1), 'Marker','o',... 
  							'Color', [0.5 0.5 0.5], 'LineWidth', 0.75);
  						obj.storedSweep.achrom.F1phase.line = line(obj.xaxis, storedData.achrom.F1phase,...
  							'Parent', obj.axesHandle(2), 'Marker','o',... 
  							'Color', [0.5 0.5 0.5], 'LineWidth', 0.75);
  					end
  				end
  			end
  			if colorIndex(2) > 0
  				if ~isempty(storedData.liso.F1amp)
  					if obj.storedSweep.liso.F1amp.line.isvalid

  					else
  						obj.storedSweep.liso.F1amp.line = line(obj.xaxis, storedData.liso.F1amp,...
  							'Parent', obj.axesHandle(1), 'Marker', 'o',...
  							'Color', [0.9 0.5 0.5], 'LineWidth', 0.75);
  						obj.storedSweep.liso.F1phase.line = line(obj.xaxis, storedData.liso.F1phase,...
  							'Parent', obj.axesHandle(2), 'Marker', 'o',...
  							'Color', [0.9 0.5 0.5], 'LineWidth', 0.75);
  					end
  				end
  			end
  			if colorIndex(3) > 0
  				if ~isempty(storedData.miso.F1amp)
  					if obj.storedSweep.miso.F1amp.line.isvalid

  					else
  						obj.storedSweep.miso.F1amp.line = line(obj.xaxis, storedData.miso.F1amp,...
  							'Parent', obj.axesHandle(1), 'Marker', 'o',...
  							'Color', [0.5 0.85 0.65], 'LineWidth', 0.75);
  						obj.storedSweep.miso.F1phase.line = line(obj.xaxis, storedData.miso.F1phase,...
  							'Parent', obj.axesHandle(2), 'Marker', 'o',...
  							'Color', [0.5 0.85 0.65], 'LineWidth', 0.75);
  					end
  				end
  			end
  			if colorIndex(4) > 0
  				if ~isempty(storedData.siso.F1amp)
  					if obj.storedSweep.siso.F1amp.line.isvalid
  					else
  						obj.storedSweep.siso.F1amp.line = line(obj.xaxis, storedData.siso.F1amp,...
  							'Parent', obj.axesHandle(1), 'Marker', 'o',...
  							'Color', [0.55 0.6 0.9], 'LineWidth', 0.75);
  						obj.storedSweep.siso.F1phase.line = line(obj.xaxis, storedData.siso.F1phase,...
  							'Parent', obj.axesHandle(2), 'Marker', 'o',...
  							'Color', [0.55 0.6 0.9], 'LineWidth', 0.75);
  					end
  				end
  			end
  		end
  	end
 end

methods (Access = private)
  	function onSelectedStoreSweep(obj,~,~)
  		% get current storedData
  		[storedData, colorIndex] = obj.storedAverages();

  		% add most recent trace
  		switch obj.chromaticClass
  		case 'achromatic'
  			if colorIndex(1) == 0
  				storedData.achrom.F1amp = obj.F1amp;
  				storedData.achrom.F1phase = obj.F1phase;
  			else
  				storedData.achrom.F1amp(end+1,:) = obj.F1amp;
  				storedData.achrom.F1phase(end+1,:) = obj.F1phase;
  			end
  			colorIndex(1) = colorIndex(1) + 1;
  		case 'L-iso'
  			if colorIndex(2) == 0
  				storedData.liso.F1amp = obj.F1amp;
  				storedData.liso.F1phase = obj.F1phase;
  			else
  				storedData.liso.F1amp(end+1,:) = obj.F1amp;
  				storedData.liso.F1phase(end+1,:) = obj.F1phase;
  			end
  			colorIndex(2) = colorIndex(2) + 1;
  		case 'M-iso'
   			if colorIndex(3) == 0
  				storedData.miso.F1amp = obj.F1amp;
  				storedData.miso.F1phase = obj.F1phase;
  			else
  				storedData.miso.F1amp(end+1,:) = obj.F1amp;
  				storedData.miso.F1phase(end+1,:) = obj.F1phase;
  			end
  			colorIndex(3) = colorIndex(3) + 1;
  		case 'S-iso'
  			if colorIndex(4) == 0
  				storedData.siso.F1amp = obj.F1amp;
  				storedData.siso.F1phase = obj.F1phase;
  			else
  				storedData.siso.F1amp(end+1,:) = obj.F1amp;
  				storedData.siso.F1phase(end+1,:) = obj.F1phase;
  			end
  			colorIndex(4) = colorIndex(4) + 1;
  		end

  		obj.storedAverages(storedData, colorIndex);
  		% change to stored color to show it was saved
  		set(obj.newF1amp, 'Color', obj.plotColor(2,:));
  		set(obj.newF1phase, 'Color', obj.plotColor(2,:));
  	end

  	function onSelectedClearStored(obj,~,~)

  		[~, colorIndex] = obj.storedAverages();
  		obj.storedAverages('Clear');

  		cc = {'achrom' 'liso' 'miso' 'siso'};
  		for ii = 1:length(cc)
  			if colorIndex(ii) > 0
  				obj.storedSweep.(cc{ii}).F1amp.line.delete;
  				obj.storedSweep.(cc{ii}).F1phase.line.delete;
  			end
  		end
  	end
end

methods (Static)
  	function [averages, colorIndex] = storedAverages(averages, colorIndex)
  		persistent stored;
  		persistent cIndex; 
  		if (nargin == 0) % retrieve stored data
  			averages = stored;
  			colorIndex = cIndex;
  		else % set or clear stored data
  			if strcmp(averages, 'Clear')
  				stored = [];
  				cIndex = [0 0 0 0];
  			else
  				stored = averages;
  				averages = stored;

  				cIndex = colorIndex;
                colorIndex = cIndex;
  			end
  		end
  	end
end
end
  			







