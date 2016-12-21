classdef GratingOrientationFigure < symphonyui.core.FigureHandler

properties
	device
	onlineAnalysis
	preTime
	stimTime
	temporalFrequency
	spatialFrequencies
	chromaticClass
	orientations
	waitTime
    demoMode
end

properties
  axesHandle
  osHandle
	meanF1amp
	meanF1phase
	F1amp
	F1phase
	cInd1
	cInd2
	cInd3
	epochNum
	repNum
	ornt
	ind
	os
	legendstr
end

methods
function obj = GratingOrientationFigure(device, onlineAnalysis, preTime, stimTime,...
	temporalFrequency, spatialFrequencies, chromaticClass, varargin)

	obj.device = device;
	obj.onlineAnalysis = onlineAnalysis;
	obj.preTime = preTime;
	obj.stimTime = stimTime;
	obj.temporalFrequency = temporalFrequency;
	obj.spatialFrequencies = spatialFrequencies;
	obj.chromaticClass = chromaticClass;

	ip = inputParser();
	ip.addParameter('waitTime', 0, @(x)isvector(x));
	ip.addParameter('orientations', [], @(x)isvector(x));
    ip.addParameter('demoMode', false, @(x)islogical(x));
	ip.parse(varargin{:});

	obj.waitTime = ip.Results.waitTime;
	obj.orientations = ip.Results.orientations;
	obj.demoMode = ip.Results.demoMode;

	[obj.cInd1,~] = getPlotColor(obj.chromaticClass, [1 0.5]);
	obj.cInd2 = flipud(pmkmp(length(obj.orientations), 'CubicL'));
	obj.cInd3 = flipud(pmkmp(length(obj.spatialFrequencies), 'CubicL'))
	[obj.ornt, obj.ind] = sort(obj.orientations);

	obj.F1amp.y = zeros(length(obj.orientations), length(obj.spatialFrequencies));
  obj.F1phase.y = zeros(size(obj.F1amp.y));
	obj.legendstr = cell(1,length(obj.orientations)+1);
	obj.legendstr{2} = 'mean';

	for ii = 1:length(obj.ornt)
		deg = sprintf('deg%u', obj.ornt(ii));
		obj.F1amp.(deg) = [];
		obj.F1phase.(deg) = [];
		if ii == 1
			obj.legendstr{ii} = sprintf('%u%s', obj.ornt(ii), char(176));
		else
			obj.legendstr{ii+1} = sprintf('%u%s', obj.ornt(ii), char(176));
		end
	end
	for ii = 1:length(obj.spatialFrequencies)
		sf = sprintf('sf%u', ii);
		obj.os.(sf) = [];
	end

  obj.epochNum = 0;
  obj.repNum = 1;

	obj.createUi();
end
function createUi(obj)
	import appbox.*;
	toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
	sendToWorkspaceButton = uipushtool(...
		'Parent', toolbar,...
		'TooltipString', 'Send to workspace',...
		'Separator', 'on',...
		'ClickedCallback', @obj.onSelectedStoreSweep);
	setIconImage(sendToWorkspaceButton, symphonyui.app.App.getResource('icons/sweep_store.png'));

	if length(obj.orientations) > 1
		n = 7;
	else
		n = 5;
	end

	obj.axesHandle(1) = subplot(n,1,1:3,...
		'Parent', obj.figureHandle,...
		'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
		'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
		'XTickMode', 'auto', 'XScale', 'log', 'XColor', 'w');
	ylabel(obj.axesHandle(1), 'f1 amplitude');
	obj.setTitle([obj.device.name ' ' obj.chromaticClass 'Grating Figure']);

	obj.axesHandle(2) = subplot(n,1,4:5,...
		'Parent', obj.figureHandle,...
		'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
		'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
		'XTickMode', 'auto', 'XScale', 'log');
	ylabel(obj.axesHandle(2), 'f1 phase');
	xlabel(obj.axesHandle(2), 'spatial frequency');

	if length(obj.orientations)>1
		obj.osHandle = subplot(7, 1, 6:7,...
			'Parent', obj.figureHandle,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XLim', [min(obj.orientations) max(obj.orientations)]);
		ylabel(obj.osHandle, 'f1 amplitude');
		xlabel(obj.osHandle, 'orientation');
	end

	set(obj.figureHandle, 'Color', 'w',...
		'DefaultLegendEdgeColor', 'w',...
		'DefaultLegendFontSize', 8);
end

function setTitle(obj, t)
	set(obj.figureHandle, 'Name', t);
	title(obj.axesHandle(1), t);
end

function clear(obj)
	cla(obj.axesHandle); cla(obj.osHandle);
	obj.F1amp = []; obj.F1phase = [];
  obj.meanF1amp = []; obj.meanF1phase = [];
	obj.os = [];
end

function handleEpoch(obj, epoch)
	if ~epoch.hasResponse(obj.device)
		error(['Epoch does not contain a response for ' obj.device.name]);
	end

	response = epoch.getResponse(obj.device);
	responseTrace = response.getData();
	sampleRate = response.sampleRate.quantityInBaseUnits;

	% get the F1 amplitude and phase
	if numel(responseTrace) > 0
		responseTrace = getResponseByType(responseTrace, obj.onlineAnalysis);

		% get the f1 amplitude and phase
		responseTrace = responseTrace((obj.preTime+obj.waitTime)/1000*sampleRate+1:end);
		binRate = 60;
		binWidth = sampleRate/binRate;
		numBins = floor((obj.stimTime-obj.waitTime)/1000*binRate);
		binData = zeros(1, numBins);
		for k = 1:numBins
			index = round((k-1)*binWidth+1: k*binWidth);
			binData(k) = mean(responseTrace(index));
		end
		binsPerCycle = binRate/obj.temporalFrequency;
		numCycles = floor(length(binData)/binsPerCycle);
		if numCycles == 0
			error('Make sure stimTime is long enough for at least one complete cycle');
		end
		cycleData = zeros(1, floor(binsPerCycle));
		for k = 1:numCycles
			index = round((k-1)*binsPerCycle)+(1:floor(binsPerCycle));
			cycleData = cycleData+binData(index);
		end
		cycleData = cycleData/k;

		ft = fft(cycleData);
		f1amp = abs(ft(2))/length(ft)*2;
		f1phase = angle(ft(2))*180/pi;
	end

	if obj.demoMode
		f1amp = randi([1 5]);
		f1phase = randi([-180 180]);
	end

	% increment the counts
	obj.epochNum = obj.epochNum + 1;


	if obj.epochNum == length(obj.spatialFrequencies)+1
		obj.repNum = obj.repNum + 1;
		obj.epochNum = 1;
	end

	deg = sprintf('deg%u', obj.orientations(obj.repNum));
	sf = sprintf('sf%u', obj.epochNum);

	obj.F1amp.y(obj.ind(obj.repNum), obj.epochNum) = f1amp;
	obj.F1phase.y(obj.ind(obj.repNum), obj.epochNum) = f1phase;

	% debugging
	fprintf('epoch %u, rep %u = %s, %s\n', obj.epochNum, obj.repNum, deg, sf);

	if isempty(obj.F1amp.(deg))
		obj.F1amp.(deg) = line(obj.spatialFrequencies, obj.F1amp.y(obj.ind(obj.repNum),:),...
			'Parent', obj.axesHandle(1),...
		 	'Color', obj.cInd2(obj.repNum,:), 'LineWidth', 1, 'Marker', 'o');
		obj.F1phase.(deg) = line(obj.spatialFrequencies, obj.F1amp.y(obj.ind(obj.repNum),:),...
			'Parent', obj.axesHandle(2),...
			'Color', obj.cInd2(obj.repNum,:), 'LineWidth', 1, 'Marker', 'o');
	else
		set(obj.F1amp.(deg), 'YData', obj.F1amp.y(obj.ind(obj.repNum),:));
		set(obj.F1phase.(deg), 'YData', obj.F1phase.y(obj.ind(obj.repNum),:));
	end

	if isempty(obj.os.(sf))
		obj.os.(sf) = line(obj.ornt, obj.F1amp.y(:, obj.epochNum)', 'Parent', obj.osHandle,...
		'Color', obj.cInd3(obj.epochNum,:), 'LineWidth', 1, 'Marker', 'o');
	else
		set(obj.os.(sf), 'YData', obj.F1amp.y(:, obj.epochNum)');
	end

	% update the mean after each orientation run
	if obj.epochNum == length(obj.spatialFrequencies)
		if isempty(obj.meanF1amp)
			obj.meanF1amp = line(obj.spatialFrequencies, mean(obj.F1amp.y(1:obj.repNum,:), 1), 'Parent', obj.axesHandle(1),...
				'Color', obj.cInd1(1,:), 'LineWidth', 1, 'Marker', 'o');
			obj.meanF1phase = line(obj.spatialFrequencies, mean(obj.F1phase.y(1:obj.repNum, :), 1), 'Parent', obj.axesHandle(2),...
				'Color', obj.cInd1(1,:), 'LineWidth', 1, 'Marker', 'o');
			legend(obj.axesHandle(1), obj.legendstr{1:obj.repNum+1});
		else
			set(obj.meanF1amp, 'YData', mean(obj.F1amp.y(1:obj.repNum, :), 1));
			set(obj.meanF1phase, 'YData', mean(obj.F1phase.y(1:obj.repNum, :), 1));
			legend(obj.axesHandle(1), obj.legendstr{1:obj.repNum+1});
			set(legend, 'Location', 'northoutside', 'Orientation', 'horizontal');
		end
	end
end % handle epoch
end % methods

methods (Access = private)
function onSelectedStoreSweep(obj,~,~)
	outputStruct.F1 = obj.F1amp.y;
	outputStruct.P1 = obj.F1phase.y;
	outputStruct.debug1 = obj.F1amp;
	outputStruct.debug2 = obj.F1phase;
	outputStruct.debug3 = obj.os;
	answer = inputdlg('Save to workspace as:', 'save dialog', 1, {'r'});
	fprintf('%s new grating named %s\n', datestr(now), answer{1});
	assignin('base', sprintf('%s', answer{1}), outputStruct);
end
end % methods
end % classdef
