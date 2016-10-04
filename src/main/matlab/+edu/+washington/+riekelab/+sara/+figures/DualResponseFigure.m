 classdef DualResponseFigure < symphonyui.core.FigureHandler
 	% plots the response of two specified devices in the most recent epoch

 	% copied from riekelab-package, added response trace and spike detection options
 	% TODO: stimTrace options for temporalFrequency varying among epochs, multiple stimTraces

 	properties (SetAccess = private)
 		device1
 		sweepColor1
 		storedSweepColor1

 		device2
 		sweepColor2
 		storedSweepColor2

 		stimTrace
 		stimColor
 	end

 	properties (Access = private)
 		axesHandle1
 		sweep1

 		axesHandle2
 		sweep2

 		stimHandle
 		stim 
 		numAxes
 	end

 methods
 	function obj = DualResponseFigure(device1, device2, varargin)
 		co = get(groot, 'defaultAxesColorOrder');

 		ip = inputParser();
 		ip.addParameter('stimTrace', [], @(x)isvector(x));
 		ip.addParameter('stimColor', 'k', @(x)isvector(x) || @(x)ischar(x));
 		ip.addParameter('sweepColor1', co(1,:), @(x)ischar(x) || isvector(x));
 		ip.addParameter('storedSweepColor1', 'r', @ischar(x) || isvector(x));
 		ip.addParameter('sweepColor2', co(2,:), @(x)ischar(x) || @(x)isvector(x));
 		ip.addParameter('storedSweepColor2', 'r', @(x)ischar(x) || isvector(x));
 		ip.parse(varargin{:});

 		obj.stimTrace = ip.Results.stimTrace;
 		obj.stimColor = ip.Results.stimColor;

 		if isempty(obj.stimTrace)
 			obj.numAxes = 2;
 		else
 			obj.numAxes = 3;
 		end

 		obj.device1 = device1;
 		obj.sweepColor1 = ip.Results.sweepColor1;
 		obj.storedSweepColor1 = ip.results.storedSweepColor1;

 		obj.device2 = device2;
 		obj.sweepColor2 = ip.Results.sweepColor2;
 		obj.storedSweepColor2 = ip.Results.storedSweepColor2;

 		obj.createUi();

 		stored1 = obj.storedSweep1();
 		if ~isempty(stored1)
 			stored1.line = line(stored1.x, stored1.y,
 				'Parent', obj.axesHandle1,...
 				'Color', obj.storedSweepColor1,...
 				'HandleVisibility', 'off');
 		end
 		obj.storedSweep(stored1);

 		stored2 = obj.storedSweep2();
 		if ~isempty(stored2)
 			stored2.line = line(stored2.x, stored2.y, ...
 				'Parent', obj.axesHandle2, ...
 				'Color', obj.storedSweepColor2,...
 				'HandleVisibility', 'off');
 		end
 		obj.storedSweep2(stored2);
 	end

 	function createUi(obj)
 		import appbox.*;

 		toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
 		storeSweepButton = uipushtool(...
 			'Parent', toolbar, ...
 			'TooltipString', 'Store Sweep',...
 			'Separator', 'on',...
 			'ClickedCallback', @obj.onSelectedStoreSweep);
 		setIconImage(storeSweepButton, symphonyui.app.App.getResource('icons', 'sweep_store.png'));

 		clearSweepsButton = uipushtool('parent', 'toolbar',...
 			'TooltipString', 'clear sweep',...
 			'ClickedCallback', @obj.onSelectedClearSweep);
 		setIconImage(clearSweepsButton, symphonyui.app.App.getResource('icons', 'sweep_clear.png'));

 		checkSpikesButton = uipushtool('parent', 'toolbar',...
 			'TooltipString', 'check spikes',...
 			'Separator', 'on',...
 			'ClickedCallback', @obj.onSelectedCheckSpikes);
 		setIconImage(checkSpikesButton, symphonyui.app.App.getResource('icons', 'valid.png'));

 		obj.axesHandle1 = subplot(obj.numAxes, 1, 1,...
 			'Parent', obj.figureHandle,...
 			'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'),...
 			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
 			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
 			'XTickMode', 'auto');
 		xlabel(obj.axesHandle1, 'sec');
 		title(obj.axesHandle1, [obj.device1.name ' Response']);

 		obj.axesHandle2 = subplot(obj.numAxes, 1, 2,...
 			'Parent', obj.figureHandle,...
 			'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'),...
 			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
 			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
 			'XTickMode', 'auto');
 		xlabel(obj.axesHandle2, 'sec');
 		title(obj.axesHandle2, [obj.device2.name ' Response']);

 		if obj.numAxes == 3
 			obj.stimHandle = subplot(2 * obj.numAxes, 1, 2 * obj.numAxes,...
 				'Parent', obj.figureHandle, ...
 				'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'),...
 				'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
 				'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
 				'XTickMode', 'auto');
 			ylabel(obj.axesHandle2, 'contrast');
 		end

 		set(obj.figureHandle, 'Name', [obj.device1.name ' and ' obj.device2.name ' Respose']);
 	end

 	function clear(obj)
 		cla(obj.axesHandle1);
 		obj.sweep1 = [];

 		cla(obj.axesHandle2);
 		obj.sweep2 = [];
 	end

 	function handleEpoch(obj, epoch)
 		if ~epoch.hasResponse(obj.device1) || ~epoch.hasResponse(obj.device2)
 			error(['Epoch does not contain a response for ' obj.device1.name ' or ' obj.device2.name]);
 		end

 		obj.sweep1 = plotResponse(epoch.getResponse(obj.device1), obj.axesHandle1, obj.sweep1, obj.sweep1Color);
 		obj.sweep2 = plotResponse(epoch.getResponse(obj.device2), obj.axesHandle2, obj.sweep2, obj.sweep2Color);

 		if obj.axesNum = 3
 			x = length(obj.stimTrace);
 			y = obj.stimTrace;
 			if isempty(stim)
 				obj.stim.line = line(length(obj.stimTrace), obj.stimTrace, 'Parent', obj.stimHandle, obj.stimColor);
 			else
 				set(stim.line, 'XData', length(obj.stimTrace), 'YData', obj.stimTrace);
 			end
 		end

 		function sweep = plotResponse(response, axesHandle, sweep, sweepColor)
 			[quantities, units] = response.getData();
 			if numel(quantities) > 0
 				x = (1:numel(quantities)) / response.sampleRate.quantityInBaseUnits;
 				y = quantities;
 			else
 				x = [];
 				y = [];
 			end
 			if isempty(sweep)
 				sweep.x = x;
 				sweep.y = y;
 				sweep.line = line(sweep.x, sweep.y, 'Parent', axesHandle, 'Color', sweepColor)
 			else
 				sweep.x = x;
 				sweep.y = y;
 				set(sweep.line, 'XData', sweep.x, 'YData', sweep.y);
 			end
 			ylabel(axesHandle, units, 'Interpreter', 'none');
 		end
 	end

 methods (Access = private)
 	function onSelectedStoreSweep(obj, ~, ~)
 		obj.storedSweep();

 		store1 = storeSweep(obj.sweep1, obj.axesHandle1, obj.storedSweepColor1);
 		store2 = storeSweep(obj.sweep2, obj.axesHandle2, obj.storedSweepColor2);

 		function store = storeSweep(store, axesHandle, storedSweepColor)
 			if ~isempty(store)
 				store.line = copyobj(store.line, axesHandle);
 				set(store.line, 'Color', storedSweepColor, 'HandleVisibility', 'off');
 			end
 		end
 		obj.storedSweep1(store1)
 		obj.storedSweep2(store2)
 	end

 	function onSelectedStoreSweep(obj, ~, ~)
 		obj.clearSweep();
 	end

 	function clearSweep(obj)
 		stored1 = obj.storedSweep();
 		if ~isempty(stored1)
 			delete(stored1.line);
 		end

 		stored2 = obj.storedSweep2();
 		if ~isempty(stored2)
 			delete(stored2.line);
 		end

 		obj.storedSweep1([]);
 		obj.storedSweep2([]);
 	end

 	function onSelectedCheckSpikes(obj, ~, ~)
 		
 	end

end

methods (Static)

 	function sweep = storedSweep1(sweep)
 		% This method stores a sweep1 across figure handlers.
 		persistent stored;
 		if nargin > 0
 			stored = sweep;
 		end
 		sweep = stored;
 	end

 	function sweep = storedSweep2(sweep)
 		% This method stores a sweep2 across figure handlers.
 		persistent stored;
 		if nargin > 0
 			stored = sweep;
 		end
 		sweep = stored;
 	end

end % methods (static)
end % classdef




