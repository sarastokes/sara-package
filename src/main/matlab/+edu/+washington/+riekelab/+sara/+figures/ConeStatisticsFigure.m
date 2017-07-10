classdef ConeStatisticsFigure < symphonyui.core.FigureHandler
	% basically ResponseStatisticsFigure
	% set up a little oddly for later UI control
	%
	% obj.showFigure('symphonyui.builtin.figures.ResponseStatisticsFigure',... 
	% 	obj.rig.getDevice(obj.amp), {@mean, @var}, ...
	% 	'baselineRegion', [0 obj.preTime], ...
	% 	'measurementRegion', [obj.preTime obj.preTime+obj.stimTime]);

properties (SetAccess = private)
	device
	preTime
	stimTime
	temporalFrequency
	% measurementCallbacks
	storedData
end

properties (Access = private)
	coneData
	axesHandles
	lines
end

properties
	RES = {'F1', 'F2', 'P1', 'P2'}
	CONES = 'LMSAY'
end

methods
function obj = ConeStatisticsFigure(device, varargin)

	obj.device = device;
	obj.preTime = preTime;
	obj.stimTime = stimTime;
	obj.temporalFrequency = temporalFrequency;	

	obj.createUi();

	% check for stored coneData
	stored = obj.storedData();
	if ~isempty(stored)
		obj.coneData = stored;
		for i = 1:length(obj.CONES)
			obj.lines.([obj.CONES(i) 'F1']) = scatter(obj.axesHandles(1),...
	    		obj.coneData.(P1).(obj.CONES(i)),...
	    		obj.coneData.(F1).(obj.CONES(i)),...
				'Marker', 'o',...
				'MarkerEdgeColor', getPlotColor(obj.CONES(i)),...
				'MarkerFaceColor', getPlotColor(obj.CONES(i)));
			obj.lines.([obj.CONES(i) 'F2']) = scatter(obj.axesHandles(1),...
	    		obj.coneData.(P2).(obj.CONES(i)),...
	    		obj.coneData.(F2).(obj.CONES(i)),...
				'Marker', 'o',...
				'MarkerEdgeColor', getPlotColor(obj.CONES(i)),...
				'MarkerFaceColor', getPlotColor(obj.CONES(i)));
		end
	else
		for i = 1:length(obj.CONES)
			for j = 1:length(obj.RES)
				obj.coneData.(obj.RES{j}).(obj.CONES(i)) = [];
			end
		end
	end
end % constructor

function createUi(obj)
	import appbox.*;

	set(obj.figureHandle, 'Color', 'w',...
		'Name', 'Cone Statistics Figure');

	toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
	sendButton = uipushtool('Parent', toolbar,...
		'TooltipString', 'Send to Workspace',...
		'Separator', 'on',...
		'ClickedCallback', @obj.onSelected_send);
    setIconImage(sendButton, symphonyui.app.App.getResource('icons', 'modules.png'));
    
	%% TODO: needs icon
	storeSweepButton = uipushtool('Parent', toolbar,...
		'TooltipString', 'Store Sweep',...
		'Separator', 'on',...
		'ClickedCallback', @obj.onSelectedStoreSweep);
	setIconImage(storeSweepButton, symphonyui.app.App.getResource('icons', 'sweep_store.png'));
	clearSweepButton = uipushtool('Parent', toolbar,...
		'TooltipString', 'Clear Sweep',...
		'ClickedCallback', @obj.onSelectedClearSweep);
	setIconImage(clearSweepButton, symphonyui.app.App.getResource('icons', 'sweep_clear.png'));

	for i = 1:2
		obj.axesHandles(i) = subplot([1 2 i],...
			'Parent', obj.figureHandle,...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'XTickMode', 'auto',...
			'XColor', 'none');
		xlabel(obj.axesHandles(i), 'phase (deg)');
		ylabel(obj.axesHandles(i), 'spikes/sec');
		title(obj.axesHandles(i), sprintf('F%u amplitude', i));
	end
end % createUi

function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
        error(['Epoch does not contain a response for ' obj.device.name]);
    end

    % get the response
    response = epoch.getResponse(obj.ampDevice);
    epochResponseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    % get the fft (borrowed from max's protocols)
    noCycles = floor(obj.temporalFrequency * obj.stimTime/1000);
    period = (1/obj.temporalFrequency) * sampleRate;
    epochResponseTrace(1:(sampleRate * obj.preTime/1000)) = [];
    cycleAvgResp = 0;
    for c = 1:noCycles
    	cycleAvgResp = cycleAvgResp + epochResponseTrace((c-1) * period+1:c*period);
    end
    cycleAvgResp = cycleAvgResp ./ noCycles;

    ft = fft(cycleAvgResp);
    res = [abs(ft(2)) / length(ft)*2,...
    	abs(ft(3)) / length(ft)*2,...
    	angle(ft(2)) * 180/pi,...
    	angle(ft(3)) * 180/pi];

    % get the cone
    whichCone = epoch.parameters('chromaticClass');
    whichCone = upper(whichCone(1));

    % assign to cell data
    for i = 1:length(obj.RES)
    	obj.cellData.(obj.RES{i}).(whichCone) = [obj.cellData.(obj.RES{i}).(whichCone) res(i)];
    end

    cla(obj.axesHandles(1)); cla(obj.axesHandles(2));
    hold(obj.axesHandle(1), 'on');
    hold(obj.axesHandle(2), 'on');

    for i = 1:length(obj.CONES)
    	if ~isempty(obj.cellData.F1.(obj.CONES(i)))
    		if length(obj.cellData.F1.(obj.CONES(i))) == 1
	    		obj.lines.([obj.CONES(i), 'F1']) = scatter(obj.axesHandle(1),...
	    			obj.coneData.(P1).(obj.CONES(i)),...
	    			obj.coneData.(F1).(obj.CONES(i)),...
	    			'Marker', 'o',...
	    			'MarkerFaceColor', getPlotColor(obj.CONES(i)),...
	    			'MarkerEdgeColor', getPlotColor(obj.CONES(i)));
	    		obj.lines.([obj.CONES(i), 'F2']) = scatter(obj.axesHandles(2),...
	    			obj.coneData.(P2).(obj.CONES(i)),...
	    			obj.coneData.(F2).(obj.CONES(i)),...
	    			'Marker', 'o',...
	    			'MarkerFaceColor', getPlotColor(obj.CONES(i)),...
	    			'MarkerEdgeColor', getPlotColor(obj.CONES(i)));
	    	else
	    		set(obj.lines.([obj.CONES(i), 'F1']),...
	    			'XData', obj.coneData.(P1).(obj.CONES(i)),...
	    			'YData', obj.coneData.(F1).(obj.CONES(i)));
	    		set(obj.lines([obj.CONES(i), 'F2']),...
	    			'XData', obj.coneData.(P2).(obj.CONES(i)),...
	    			'YData', obj.coneData.(F2).(obj.CONES(i)));
	    	end
    	end
    end
end % handleEpoch
end % methods

methods (Access = private)
	function onSelected_send(obj, ~, ~)
		answer = inputdlg('Save to workspace as:',... 
			'Save Dialog', 1, {'r'});
	  	fprintf('%s new cone statistics data named %s\n', datestr(now), answer{1});
	  	assignin('base', sprintf('%s', answer{1}), obj.cellData);
	end

	function onSelected_storeData(obj, ~, ~)
		obj.storeData();
	end % onSelected_storeData

	function storeData(obj)
		obj.clearData();
		obj.storedData(obj.cellData);
	end % storeData

	function onSelected_clearData(obj, ~, ~)
		obj.clearData();
	end % onSelected_clearData

	function clearData(obj)
		stored = obj.storedSweep();
	    if ~isempty(stored)
	        delete(stored.line);
	    end
	    obj.storedSweep([]);
	end % clearData
end % methods private access

methods (Static)
	function sweeps = storedSweeps(sweeps)
		% This methods stores sweeps across figure handlers
		persistent stored;
		if nargin > 0
			stored = sweeps;
		end
		sweeps = stored;
	end % storedSweeps
end % methods static
end % classdef
