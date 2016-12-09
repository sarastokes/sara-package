classdef ConeSpaceFigure < symphonyui.core.FigureHandler

properties
	device
	onlineAnalysis
	preTime
	stimTime
	temporalFrequency
	theoreticalMins
  stimulusClass
end

properties
	axesHandle
	epochNum
end


properties
	redMin
	greenMin
	blueMin
	redAxis
	greenAxis
	blueAxis
	redF1
  redP1
	greenF1
  greenP1
	blueF1
  blueP1
	redF2
	greenF2
	blueF2
	redLine
	blueLine
	greenLine
	theoLine
end

methods
function obj = ConeSpaceFigure(device, onlineAnalysis, preTime, stimTime, temporalFrequency, varargin)
	obj.device = device;
	obj.onlineAnalysis = onlineAnalysis;
  	obj.onlineAnalysis = onlineAnalysis;
  	obj.preTime = preTime;
  	obj.stimTime = stimTime;	
  	obj.temporalFrequency = temporalFrequency;

  	ip = inputParser();
  	ip.addParameter('theoreticalMins', [], @(x)isvector(x));
  	ip.parse(varargin{:});

  	obj.theoreticalMins = ip.Results.theoreticalMins;

  	% init variables
  	obj.redAxis = [];
  	obj.greenAxis = [];
  	obj.blueAxis = [];
  	obj.epochNum = 0;

  	obj.createUi();
  end

  function createUi(obj)
  	import appbox.*;
  	toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
  	sendMinsButton = uipushtool('Parent', toolbar,...
  		'TooltipString', 'Send to workspace',...
  		'Separator', 'on',...
  		'ClickedCallback', @obj.onSelectedStoreSweep);
  	setIconImage(sendMinsButton, symphonyui.app.App.getResource('icons/sweep_store.png'));

  	obj.axesHandle(1) = subplot(3, 1, 1:2,...
  		'Parent', obj.figureHandle,...
        'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
        'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
        'XTickMode', 'auto');
  	ylabel(obj.axesHandle(1), 'f1 amp');

  	obj.axesHandle(2) = subplot(4, 1, 4,...
  		'Parent', obj.figureHandle,...
  		'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
        'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
        'XTickMode', 'auto');
  	ylabel(obj.axesHandle(2), 'f1 phase');

  	set(obj.figureHandle, 'Color', 'w', 'Name', 'Cone Space Figure');
  end

  function setTitle(obj, t)
  	title(obj.axesHandle(1), t);
  end

  function clear(obj)
  	cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
  	obj.greenF1 = []; obj.redF1 = []; obj.blueF1 = [];
  	obj.greenP1 = []; obj.redP1 = []; obj.blueP1 = [];
  end

  function handleEpoch(obj, epoch)
  	if ~epoch.hasResponse(obj.device)
  		error(['Epoch does not contain a response for ' obj.device.name]);
  	end

  	obj.epochNum = obj.epochNum + 1;

  	response = epoch.getResponse(obj.device);
  	[quantities, ~] = response.getData();
  	sampleRate = response.sampleRate.quantityInBaseUnits;

    binRate = 60;
    prePts = obj.preTime*1e-3*sampleRate;
    stimFrames = obj.stimTime * 1e-3 * binRate;

  	if numel(quantities) > 0
  		y = quantities;
  		% analyze response by type
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

  		% get temporal modulation
  		binSize = binRate / obj.temporalFrequency;
  		numBins = floor(stimFrames/binSize);
  		avgCycle = zeros(1, floor(binSize));
  		for k = 1:numBins
  			index = round((k-1)*binSize)+(1:floor(binSize));
  			index(index > length(y)) = [];
  			ytmp = y(index);
  			avgCycle = avgCycle + ytmp(:)';
  		end
  		avgCycle = avgCycle / numBins;

  		% take the fft
  		ft = fft(avgCycle);

  		% sort to the right LED
		searchAxis = epoch.parameters('searchAxis');
		ledContrasts = epoch.parameters('ledContrasts');
	  	switch searchAxis
	  		case 'green'
	  			obj.greenAxis(obj.epochNum) = ledContrasts(2);
	  			obj.greenF1(obj.epochNum) = abs(ft(2))/length(ft)*2;
	  			obj.greenP1(obj.epochNum) = angle(ft(2)); % *180/pi
	  			if strcmp(obj.stimulusClass, 'spot') && strcmp(obj.temporalClass, 'squarewave')
	  				obj.greenF2(obj.epochNum) = abs(ft(3))/length(ft)*2;
	  			end
	  		case 'red'
	  			if isempty(obj.redAxis)
	  				index = 1;
	  			else
	  				index = length(obj.redAxis) + 1;
	  			end
	  			obj.redAxis(index) = ledContrasts(1);
	  			obj.redF1(index) = abs(ft(2))/length(ft)*2;
	  			obj.redP1(index) = angle(ft(2));

	  			if strcmp(obj.stimulusClass, 'spot') && strcmp(obj.temporalClass, 'squarewave')
	  				obj.redF2(index) = abs(ft(3))/length(ft)*2;
	  			end
  		case 'blue'
  			if isempty(obj.blueAxis)
  				index = 1;
  			else
  				index = length(obj.blueAxis) + 1;
  			end
  			obj.blueAxis(index) = ledContrasts(3);
  			obj.blueF1(index) = abs(ft(2))/length(ft)*2;
  			obj.blueP1(index) = angle(ft(2));
  			if strcmp(obj.stimulusClass, 'spot') && strcmp(obj.temporalClass, 'squarewave')
  				obj.blueF2(index) = abs(ft(3))/length(ft)*2;
  			end
	  	end
  	end % quantities > 0

  	% create the plot
  	if ~isempty(obj.theoreticalMins)
	  	obj.theoLine.red = line(obj.theoreticalMins(1), 0, 'Marker', '*', 'Color', [0.5 0 0]);
  		obj.theoLine.green = line(obj.theoreticalMins(2), 0, 'Marker', '*', 'Color', [0 0.5 0]);
  	end
  	switch searchAxis
  	case 'green'
  		obj.greenLine.F1 = line(obj.greenAxis, obj.greenF1,... 
  			'Parent', obj.axesHandle(1),...
  			'Marker', 'o', 'Color', [0 0.7 0.3]);
  		obj.greenLine.P1 = line(obj.greenAxis, obj.greenP1,...
  			'Parent', obj.axesHandle(2),...
  			'Marker', 'o', 'Color', [0 0.7 0.3]);
  		legend(obj.axesHandle(1), sprintf('%.3f', obj.redMin),... 
  			'EdgeColor', 'w', 'Orientation', 'Horizontal');
  	case 'red'
  		obj.redLine.F1 = line(obj.redAxis, obj.redF1,... 
  			'Parent', obj.axesHandle(1),...
  			'Marker', 'o', 'Color', [0.85 0 0]);
  		obj.redLine.P1 = line(obj.redAxis, obj.redP1,...
  			'Parent', obj.axesHandle(2),...
  			'Marker', 'o', 'Color', [0.85 0 0]);
  		legend(obj.axesHandle(1), sprintf('%.3f',obj.greenMin), sprintf('%.3f',obj.redMin),... 
  			'EdgeColor', 'w', 'Orientation', 'Horizontal');
  	case 'blue'
  		obj.blueLine.F1 = line(obj.blueAxis, obj.blueF1,...
  			'Parent', obj.axesHandle(1),...
  			'Marker', 'o', 'Color', [0.15 0.2 0.85]);
  		obj.blueLine.P1 = line(obj.blueAxis, obj.blueP1,...
  			'Parent', obj.axesHandle(2),...
  			'Marker', 'o', 'Color', [0.15 0.2 0.85]);
  		legend(obj.axesHandle(1), sprintf('%.3f', obj.greenMin), sprintf('%.3f', obj.redMin),... 
  			sprintf('.3%f',obj.blueMin), 'EdgeColor', 'w', 'Orientation', 'Horizontal');
  	end

  	set(obj.axesHandle, 'XLim', [-1 1], 'TickDir', 'out', 'Box', 'off');

  end % handleEpoch
end % methods
end % classdef



