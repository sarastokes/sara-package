classdef FullF1Figure < symphonyui.core.FigureHandler

properties
	device
	xvals
	onlineAnalysis
	preTime
	stimTime
	temporalFrequency
	plotColor
	numReps
	waitTime
	chromaticClass
	demoMode
end

properties
	axesHandle
	lineHandle
	repsPerX
	epochNum
	F1amp
	F1phase
	runningF1
	runningP1
	runningXvals
end

methods
function obj = FullF1Figure(device, xvals, onlineAnalysis, preTime, stimTime, temporalFrequency, varargin)
		obj.device = device;
		obj.xvals = xvals;
		obj.onlineAnalysis = onlineAnalysis;
		obj.preTime = preTime;
		obj.stimTime = stimTime;
		obj.temporalFrequency = temporalFrequency;

		ip = inputParser();
		ip.addParameter('plotColor', [0 0 0], @(x)ischar(x) || isvector(x));
		ip.addParameter('numReps', 1, @(x)isfloat(x));
		ip.addParameter('waitTime', 0, @(x)isfloat(x));
		ip.parse(varargin{:});

		obj.numReps = ip.Results.numReps;
		obj.waitTime = ip.Results.waitTime;

		obj.plotColor = zeros(2,3);
		obj.plotColor(1, :) = ip.Results.plotColor;
		obj.plotColor(2, :) = obj.plotColor(1, :) + (0.6*(1-obj.plotColor(1,:)));

		obj.F1amp = zeros(size(obj.xvals));
		obj.runningF1 = zeros(size(obj.xvals));
		obj.F1phase = zeros(size(obj.xvals));
		obj.runningP1 = zeros(size(obj.xvals));
        obj.repsPerX = zeros(size(obj.xvals));

		obj.epochNum = 0;

		obj.createUi();
	end

	function createUi(obj)
		import appbox.*;
		toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
		sendSweepButton = uipushtool('Parent', toolbar,...
			'Tooltipstring', 'Send to workspace',...
			'Separator', 'on',...
			'ClickedCallback', @obj.onSelectedSendSweep);
		setIconImage(sendSweepButton, symphonyui.app.App.getResource('icons/sweep_store.png'));

		obj.axesHandle(1) = subplot(3, 1, 1:2,...
			'Parent', obj.figureHandle,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XTickMode', 'auto', 'XLimMode', 'manual',... 
			'XScale', 'log', 'XLim', [min(obj.xvals) max(obj.xvals)]');
		ylabel(obj.axesHandle(1), 'F1 amplitude');
		obj.axesHandle(2) = subplot(3,1,3,...
			'Parent', obj.figureHandle,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XTickMode', 'auto', 'XLimMode', 'manual',...
			'XScale', 'log', 'XLim', [min(obj.xvals) max(obj.xvals)]');
		ylabel(obj.axesHandle(2), 'F1 phase');

		set(obj.figureHandle, 'Color', 'w');
%		obj.setTitle('spatial modulation profile');
	end

	function handleEpoch(obj, epoch)
		if ~epoch.hasResponse(obj.device)
			error(['Epoch does not contain a response for ' obj.device]);
		end

		obj.epochNum = obj.epochNum + 1;

		% get epoch info
		if obj.demoMode
			load demoGrating
			quantities = response(randi(18), :);
			sampleRate = 10000;
		else
			response = epoch.getResponse(obj.device);
			[quantities, ~] = response.getData();
			sampleRate = response.sampleRate.quantityInBaseUnits;
		end
		sf = epoch.parameters('spatialFreq');
		xIndex = obj.xvals == sf;

        binRate = 60;
		prePts = (obj.preTime + obj.waitTime)*1e-3*sampleRate;
		stimFrames = (obj.stimTime - obj.waitTime) * 1e-3 * binRate;

		if numel(quantities) > 0
			% get response by recording type
			y = quantities; size(y)
			if strcmp(obj.onlineAnalysis, 'extracellular')
				res = spikeDetectorOnline(y, [], sampleRate);
				y = zeros(size(y));
				y(res.sp) = 1; % spike binary
				y = BinSpikeRate(y(prePts+1:end), binRate, sampleRate);
			else
				if prePts > 0
					y = y - median(y(1:prePts));
				else
					y = y - median(y);
				end
				y = binData(y(prePts+1:end), binRate, sampleRate);
			end

			% bin the data
			binSize = binRate/obj.temporalFrequency;
			numBins = floor(stimFrames/binSize);
			avgCycle = zeros(1, floor(binSize));
			for ii = 1:numBins
				index = round((ii-1) * binSize) + (1:floor(binSize));
				index(index > length(y)) = [];
				ytmp = y(index);
				avgCycle = avgCycle + ytmp(:)';
			end
			avgCycle = avgCycle/numBins;

			% iterate the reps
			obj.repsPerX(xIndex) = obj.repsPerX(xIndex) + 1;
			
			% get the f1 amplitude and phase (maybe f0 and f2 later)
			ft = fft(avgCycle);
			fprintf('epoch %u\n', obj.epochNum);
			if obj.epochNum > length(obj.xvals)
				if obj.demoMode
					obj.runningF1 = [obj.runningF1 randi(5)];
					obj.runningP1 = [obj.runningP1 randi(5)];
				else
					obj.runningF1 = [obj.runningF1 abs(ft(2))/length(avgCycle)*2];
					obj.runningP1 = [obj.runningP1 angle(ft(2))];
				end
				obj.F1amp(xIndex) = obj.F1amp(xIndex) * (obj.repsPerX(xIndex)-1) + obj.runningF1(1,end) / obj.repsPerX(xIndex);
				obj.F1phase(xIndex) = obj.F1phase(xIndex) * (obj.repsPerX(xIndex)-1) + obj.runningP1(1, end) / obj.repsPerX(xIndex);
			else%
				if obj.demoMode
					obj.runningF1(1,obj.epochNum) = randi(5);
					obj.runningP1(1,obj.epochNum) = randi(5);
				else
					obj.runningF1(1, obj.epochNum) = abs(ft(2))/length(avgCycle)*2;
					obj.runningP1(1, obj.epochNum) = angle(ft(2));
				end
				if obj.epochNum == length(obj.xvals)
					obj.F1amp = obj.runningF1;
					obj.F1phase = obj.runningP1;
				end
			end
		end % quantities > 0

		% plot
		if obj.epochNum == 1
			obj.lineHandle.F1 = line(obj.xvals, obj.runningF1, 'Parent', obj.axesHandle(1),... 
				'Color', obj.plotColor(1,:), 'Marker', 'o', 'LineWidth', 1);
			obj.lineHandle.P1 = line(obj.xvals, obj.runningP1, 'Parent', obj.axesHandle(2),...
				'Color', obj.plotColor(1,:), 'Marker', 'o', 'LineWidth', 1);
		elseif obj.epochNum <= length(obj.xvals)
			obj.runningF1
			set(obj.lineHandle.F1, 'YData', obj.runningF1);
			set(obj.lineHandle.P1, 'YData', obj.runningP1);
		elseif obj.epochNum == (length(obj.xvals) + 1)
			fprintf('at %u should see two lines\n', obj.epochNum)
			obj.runningXvals = [obj.xvals obj.xvals(1)];
			obj.lineHandle.F1mean = line(obj.xvals, obj.F1amp, 'Parent', obj.axesHandle(1),...
				'Color', obj.plotColor(1,:), 'Marker', 'o', 'LineWidth', 1);
			obj.lineHandle.P1mean = line(obj.xvals, obj.F1phase, 'Parent', obj.axesHandle(2),...
				'Color', obj.plotColor(1,:), 'Marker', 'o', 'LineWidth', 1);
			set(obj.lineHandle.F1, 'Color', 'w',... 
				'XData', obj.runningXvals, 'YData', obj.runningF1,...
				'MarkerEdgeColor', obj.plotColor(2,:), 'MarkerFaceColor', obj.plotColor(2,:));
			set(obj.lineHandle.P1, 'Color', 'w',...
				'XData', obj.runningXvals, 'YData', obj.runningP1,...
				'MarkerEdgeColor', obj.plotColor(2,:), 'MarkerFaceColor', obj.plotColor(2,:));
		elseif obj.epochNum > (length(obj.xvals)+1)
			obj.runningXvals = [obj.runningXvals obj.xvals(xIndex)];
			obj.runningF1
			set(obj.lineHandle.F1, 'XData', obj.runningXvals, 'YData', obj.runningF1);
			set(obj.lineHandle.P1, 'XData', obj.runningXvals, 'YData', obj.runningP1);
			set(obj.lineHandle.F1mean, 'YData', obj.F1amp);
			set(obj.lineHandle.P1mean, 'YData', obj.F1phase);
		end

		if max(obj.runningF1) ~= 0
			set(obj.axesHandle(1), 'YLim', [0 max(obj.runningF1)]);
		end
		if max(obj.runningP1) ~= 0
			set(obj.axesHandle(2), 'YLim', [0 max(obj.runningP1)]);
		end

	end % handleEpoch
end % methods 1

methods(Access = private)
	function onSelectedSendSweep(obj, ~, ~)
		outputStruct.F1 = obj.F1amp;
		outputStruct.P1 = obj.F1phase; %#ok<STRNU>
		assignin('base', 'outputStruct', 'outputStruct');
	end % onSelectedSendSweep
end % methods 2
end % classdef