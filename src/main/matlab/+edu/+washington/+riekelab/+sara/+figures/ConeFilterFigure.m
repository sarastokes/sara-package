classdef ConeFilterFigure < symphonyui.core.FigureHandler
	% just the outline for now
properties (SetAccess = private)
    % required:
	device
	frameMonitor
	preTime
	stimTime

	stDev
    % optional:
	recordingType
	frameDwell
	frameRate
end

properties
	handles
	epochNum
    
    % whats the difference between these two?
    epochData
	cellData

	coneInd % current cone as #

	nextCone % a list of next chromaticClass
	nextStimTime % how long the next stim will be

	nextStimulus
	nextStimulusInfo

	protocolShouldStop = false
	ignoreNextEpoch = false
	runPausedSoMayNeedNullEpoch = false
end

properties (Constant)
	% not really worth making an editable parameter right now
	BINSPERFRAME = 6
    FILTERLENGTH = 1000

	% cone options.. might add LM-iso at some point
	CONES = 'lmsa'

	% generate some fake filters + NLs for debugging
	DEMOMODE = true
end


methods
    function obj = ConeFilterFigure(device, frameMonitor, preTime, stimTime, varargin)
		obj.device = device;
		obj.frameMonitor = frameMonitor;
		obj.preTime = preTime;
		obj.stimTime = stimTime;

		ip = inputParser();
		ip.addParameter('stDev', 0.3, @(x)isnumeric(x));
		ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
		ip.addParameter('frameDwell', 1, @(x)isnumeric(x));
		ip.addParameter('frameRate', 60, @(x)isnumeric(x));
		ip.parse(varargin{:});
		obj.recordingType = ip.Results.recordingType;
		obj.frameDwell = ip.Results.frameDwell;
		obj.frameRate = ip.Results.frameRate;
		obj.stDev = ip.Results.stDev;

		obj.epochNum = 0;

		% create the UI here so can set line handles
		obj.createUi();


		obj.cellData.filterMap = containers.Map;
		obj.cellData.nlMap = containers.Map;
		for ii = 1:4
			obj.cellData.respMap(obj.CONES(ii)) = [];
			obj.cellData.stimMap(obj.CONES(ii)) = [];

			obj.handles.nl(ii) = line('Parent', obj.handles.ax.nl,...
				'XData', 1:1000, 'YData', obj.cellData.nlMap(obj.CONES(ii)),...
				'Color', getPlotColor(obj.CONES(ii)),...
				'LineWidth', 0.3, 'Marker', '.', 'MarkerSize', 4,...
				'Visible', 'off');
		end

		obj.nextStimulus = [];

		obj.waitIfNecessary();

		if ~isvalid(obj)
			fprintf('Not valid object\n');
			return;
		end

		obj.assignNextStimulus();

	end % constructor
	
	function createUi(obj)
		import appbox.*;

		% toolbar
		toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

		debugButton = uipushtool('Parent', toolbar,...
			'TooltipString', 'send obj to wkspace',...
			'Separator', 'on',...
			'ClickedCallback', @obj.onSelected_debugButton);
		setIconImage(debugButton, symphonyui.app.App.getResource('icons', 'modules.png'));

		plotNLButton = uipushtool('Parent', toolbar,...
			'TooltipString', 'Plot nonlinearity',...
			'Separator', 'on',...
			'ClickedCallback', @obj.onSelected_fitLN);
		setIconImage(plotNLButton, symphonyui.app.App.getResources('icons', 'store_sweep.png'));

		set(obj.figureHandle, 'Name', 'Cone Filter Figure',...
			'Color', 'w',...
			'NumberTitle', 'off');

		% basic layouts
		mainLayout = uix.HBox('Parent', obj.figureHandle);
		resultLayout = uix.VBox('Parent', mainLayout);
		plotLayout = uix.HBoxFlex('Parent', resultLayout);
        dataLayout = uix.HBox('Parent', resultLayout);
		uiLayout = uix.VBox('Parent', mainLayout);
		set(mainLayout, 'Widths', [-4 -1]);

		% axes:
		obj.handles.ax.lf = axes('Parent', plotLayout,...
			'XTickMode', 'auto',...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
		xlabel(obj.handles.ax.lf, 'Time (ms)');
		title(obj.handles.ax.lf, 'Linear Filter');
		obj.handles.ax.nl = axes('Parent', plotLayout,...
			'XTickMode', 'auto',...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
		set(plotLayout, 'Widths', [-1.5 -1]);
		xlabel(obj.handles.ax.nl, 'Linear prediction');
		ylabel(obj.handles.ax.nl, 'Meaured');
		title(obj.handles.ax.nl, 'Noninearity');

		% data table
		obj.handles.dataTable = uitable('Parent', dataLayout);
		set(obj.handles.dataTable, 'Data', zeros(4,4),...
			'ColumnName', {'N','T2P', 'ZC', 'BI'},... 
			'RowName', {'L', 'M', 'S', 'A'},...
			'ColumnEditable', false);

		paramLayout = uix.VBox('Parent', dataLayout,...
            'Spacing', 5, 'Padding', 5);
        xlimLayout = uix.HBox('Parent', paramLayout);
        
		obj.handles.pb.changeXLim = uicontrol('Parent', xlimLayout,...
			'Style', 'push',...
			'String', 'Change xlim',...
			'Callback', @obj.onSelected_changeXLim);
        obj.handles.ed.changeXLim = uicontrol('Parent', xlimLayout,...
			'Style', 'edit',...
			'String', '1000');
        set(xlimLayout, 'Widths', [-3 -1]);
        
        smoothLayout = uix.HBox('Parent', paramLayout);
		obj.handles.cb.smoothFilt = uicontrol('Parent', smoothLayout,...
			'String', 'Smooth filters',...
			'Style', 'checkbox',...
			'Callback', @obj.onSelected_smoothFilt);
        obj.handles.ed.smoothFac = uicontrol('Parent', smoothLayout,...
			'Style', 'edit',...
			'String', '0');
        set(smoothLayout, 'Widths', [-3 -1]);
        
        obj.handles.cb.normPlot = uicontrol('Parent', paramLayout,...
			'String', 'Normalize',...
			'Style', 'checkbox',...
			'Callback', @obj.onSelected_normPlot);
        set(paramLayout, 'Heights', [-1 -1 -1]);
        set(resultLayout, 'Heights', [-1.5 -1]);
        set(dataLayout, 'Widths', [-2 -1]);

		% display edit boxes
		uicontrol('Parent', uiLayout,...
			'Style', 'text',...
			'String', 'Stimulus queue:');
		obj.handles.tx.queue = uicontrol('Parent', uiLayout,...
			'Style', 'text',...
			'String', '');
		obj.handles.ed.queue = uicontrol('Parent', uiLayout,...
			'Style', 'edit',...
			'String', '');
        obj.handles.pb.addToQueue = uicontrol('Parent', uiLayout,...
			'Style', 'push',...
			'String', 'UpdateQueue',...
			'Callback', @obj.onSelected_updateQueue);
		obj.handles.pb.clearQueue = uicontrol('Parent', uiLayout,...
			'Style', 'push',...
			'String', 'Clear queue',...
			'Callback', @obj.onSelected_clearQueue);
        
		% protocol displays
		obj.handles.tx.curEpoch = uicontrol('Parent', uiLayout,...
			'Style', 'text',...
			'String', 'Current Epoch: -');
		obj.handles.tx.nextEpoch = uicontrol('Parent', uiLayout,...
			'Style', 'text',...
			'String', 'Next Epoch: -');
		% protocol control buttons
		uicontrol('Parent', uiLayout,...
			'Style', 'push',...
			'String', 'Resume Protocol',...
			'Callback', @(a,b) obj.resumeProtocol());
	end % createUi

	function handleEpoch(obj, epoch)
		%% DEBUGGING
		if obj.ignoreNextEpoch
			disp('ignoring epoch');
			epoch.shouldBePersisted = false;
			obj.assignNextStimulus();
			obj.ignoreNextEpoch = false;
			return;
		end

		obj.epochNum = obj.epochNum + 1;

		%% ANALYSIS ---------------------------------------------



		if obj.DEMOMODE
			pts = linspace(-1, 1, obj.BINSPERFRAME * obj.frameRate + 1);
			% make a fake filter
			e.lf = diff(normpdf(pts, 0, (0.1*obj.coneInd)));
			% add some variability
			e.lf = ((0.1*obj.coneInd) * randi(10)) .* e.lf;
			% make an M-center OFF cell
			if obj.coneInd == 2 || obj.coneInd == 4
				e.lf = -1 * e.lf;
			end
			e.xpts = 1:length(e.lf);

			% make a fake nonlinearity
			e.nl = normcdf(pts, 0, (0.1*obj.coneInd));
		else
			e.xpts = linspace(0, obj.FILTERLENGTH, obj.BINSPERFRAME * obj.frameRate);
			
			% this is where the real linear filter analysis goes

			if strcmp(obj.analysisType, 'frameMonitor')
				% use max's frame monitor analysis
				response = epoch.getResponse(obj.device);
				epochResponseTrace = response.getData();
				sampleRate = response.sampleRate.quantityInBaseUnits;
				prePts = sampleRate * obj.preTime/1000;
				if strcmp(obj.recordingType, 'extracellular')
					newResponse = zeros(size(epochResponseTrace));
					S = spikeDetectorOnline(epochResponseTrace);
					newResponse(S.sp) = 1;
				else
					% baseline
					epochResponseTrace = epochResponseTrace - mean(epochResponseTrace(1:prePts));
					if strcmp(obj.recordingType, 'exc')
						polarity = -1;
					else strcmp(obj.recordingType, 'inh')
						polarity = 1;
					end
					newResponse = polarity * epochResponseTrace;
				end

				% load frame monitor data
				FMresponse = epoch.getResponse(obj.frameMonitor);
				FMdata = FMresponse.getData();
				frameTimes = getFrameTiming(FMdata, 1);
				preFrames = obj.frameRate * (obj.preTime/1000);
				firstStimFrameFlip = frameTimes(preFrames+1);
                newResponse = newResponse(firstStimFrameFlip:end); %cut out pre-frames
                %reconstruct noise stimulus
                filterLen = 800; %msec, length of linear filter to compute
                %fraction of noise update rate at which to cut off filter spectrum
                freqCutoffFraction = 1;
                % get the seed
                currentNoiseSeed = epoch.parameters(obj.seed);

                %reconstruct stimulus trajectories...
                stimFrames = round(frameRate * (obj.stimTime/1e3));
                noise = zeros(1,floor(stimFrames/obj.frameDwell));
                response = zeros(1, floor(stimFrames/obj.frameDwell));
                %reset random stream to recover stim trajectories
                obj.noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);
                % get stim trajectories and response in frame updates
                chunkLen = obj.frameDwell*mean(diff(frameTimes));


			else % if frame monitor is suspicious, use original analysis

			end

			% put the NL analysis here
		end

		% calculate time to peak, zero cross, biphasic index

		if abs(min(e.lf)) > max(e.lf)
			e.filterSign = -1;
			t = (e.lf > 0);
			t(1:find(e.lf == min(e.lf), 1)) = 0;
			t = find(t == 1, 1);
			if ~isempty(t)
				e.zc = t/length(e.lf) * obj.FILTERLENGTH;
			end
		else
			e.filterSign = 1;
			t = (e.lf < 0);
			t(1:find(e.lf == max(e.lf), 1)) = 0;
			t = find(t == 1, 1);
			if ~isempty(t)
				e.zc = t/length(e.lf) * obj.FILTERLENGTH;
			end
		end

		[loc, pk] = peakfinder(e.lf, [], [], e.filterSign);
		[~, ind] = max(abs(pk));
		e.t2p = e.xpts(loc(ind));

		e.bi = abs(min(e.lf)/max(e.lf));

		%% STORE -------------------------------------------------
		obj.epochData{obj.epochNum, 1} = e;

		if isempty(obj.cellData.filterMap(obj.coneInd))
			obj.cellData.filterMap(obj.coneInd) = lf;
			% TODO: make the 
			obj.handles.lf(ii) = line('Parent', obj.handles.ax.lf,...
				'XData', e.xpts,... 
				'YData', obj.cellData.filterMap(obj.CONES(ii)),...
				'Color', getPlotColor(obj.CONES(ii)),...
				'LineWidth', 1, 'Visible', 'on');
            % set(obj.handles.lines(obj.coneInd),... 
            %     'XData', e.xpts, 'YData', lf,...
            %     'Visible', 'on');
		else
			groupLF = obj.cellData.filterMap(obj.coneInd);
			newLF = stepMean(groupLF, size(groupLF, 1), lf);
            set(obj.handles.lines(obj.coneInd), 'YData', newLF,...
                'Visible', 'on');
			obj.cellData.filterMap(obj.coneInd) = [groupLF; e.lf];
		end

		%% GRAPHS ------------------------------------------------
		% add to plots
		obj.updatePlot();
		% send stats to the data table
		obj.updateDataTable([tp, zc, bi]);

		%% STIMULI ------------------------------------------------
		obj.waitIfNecessary();
		if ~isvalid(obj)
			return;
		end

		obj.assignNextStimulus();
	end

%% ------------------------------------------------- callbacks ----
	function onChanged_normPlot(obj,~,~)
		if get(obj, 'Value') == get(obj, 'Max')
			obj.handles.flags.normPlot = true;
		else
			obj.handles.flags.normPlot = false;
		end

		obj.updateFilterPlot();
	end

	function onChanged_smoothFilt(obj,~,~)
		if get(obj.handles.cb.smoothFilt, 'Value') == 1
			obj.handles.flags.smoothFilt = true;
			try
				obj.handles.values.smoothFac = str2double(get(obj.handles.ed.smoothFac, 'String'));
			catch
				warndlg('Check smooth factor, setting smoothFilt to false');
				obj.handles.flags.smoothFilt = false;
				set(obj.handles.cb.smoothFilt, 'Value', 0);
				return;
			end
		else
			obj.handles.flags.smoothFilt = false;
		end

		obj.updateFilterPlot();
	end

	function onSelected_changeXLim(obj,~,~)
		% possibly just put this in updateFilterPlot()
		% not sure how much time this would even save...
		set(obj.handles.ax.lf, 'XLim',... 
			[0 str2double(get(obj.handles.ed.changeXLim, 'String'))]);
	end % changeXLim

	function onSelected_updatePlot(obj,~,~)
		obj.updateFilterPlot();
		obj.updateGenPlot();
	end % updatePlot

	function onSelected_updateQueue(obj,~,~)
        % appends to existing queue
        x = get(obj.handles.tx.queue, 'String');
        x = [x get(obj.handles.ed.queue, 'String')];
        set(obj.handles.tx.queue, 'String', x);
        obj.addStimuli(get(obj.handles.ed.queue, 'String'));
	end % updateQueue

	function onSelected_clearQueue(obj,~,~)
		obj.nextStimulus = [];
		obj.nextStimulusInfo = {};
		obj.updateUi();
	end % clearQueue

%% ------------------------------------------------ main -----------
	function updateFilterPlot(obj)
		% turn visible = 0N if first plot
		set(obj.handles.lines.lf(obj.coneInd), 'Visible', 'On');

		% set XData and YData
		% set(obj.handles.lines.lf(obj.coneInd),... 
		% 	'XData', obj.xpts,... 
		% 	'YData', mean(obj.filterMap(obj.nextStimulus),1));

		% check for smooth plot
		if obj.handles.flags.smoothFilt
			set(obj.handles.lines.lf(obj.coneInd),...
				'YData', smooth(get(obj.handles.lines.lf(obj.coneInd), 'YData'), obj.smoothFac));
		end

		% check for normPlot
		if obj.handles.flags.normPlot
			set(obj.handles.lines.lf(obj.coneInd),...
				'YData', get(obj.handles.lines.lf(obj.coneInd), 'YData')... 
				/ max(abs(obj.handles.lines.lf(obj.coneInd))));
        end
	end % updateFilterPlot

	function updateGenPlot(obj)
        
	end % updateGenPlot

	function updateDataTable(obj, stats)
		% stats should be [t2p zc bi]
		tableData = get(obj.handles.dataTable, 'Data');
		for ii = 1:3
			tableData(obj.coneInd, ii) = stepMean(tableData(obj.coneInd, ii),... 
				tableData(obj.coneInd, 1), stats(ii));
		end
		% update count after used for variables
		tableData(obj.coneInd, 1) = tableData(obj.coneInd, 1) + 1;

		set(obj.handles.dataTable, 'Data', tableData);
	end % updateDataTable

	function updateUi(obj)
		if obj.ignoreNextEpoch
			obj.handles.tx.curEpoch.String = ['NULL - ' num2str(obj.nextStimTime) 's'];
			obj.handles.tx.nextEpoch.String = obj.nextStimulus(1);
		else
			obj.handles.tx.curEpoch.String = obj.nextCone;
			obj.handles.tx.nextEpoch.String = obj.nextStimulus(1);
		end
		% update stimulus queue:
		obj.handles.tx.queue.String = obj.nextStimulus; 
	end % updateUi

%% ------------------------------------------------ support --------
	function clearFigure(obj)
		if obj.epochNum > 1
			obj.saveDlg();
		end
		obj.resetPlots();
		clearFigure@FigureHandler(obj);
	end

	function resetPlots(obj)
		obj.epochData = {};
		obj.epochNum = 0;
		obj.nextStimulus = [];
		obj.nextStimulusInfo = [];
		obj.protocolShouldStop = false;
	end % resetPlots

	function saveDlg(obj)
		selection = questdlg('Save the data?', 'Save dialog',...
			'Yes', 'No', 'Yes');
		if strcmp(selection, 'Yes')
			warndlg('set this up later...');
		end
	end % saveDlg

%% ------------------------------------------------ protocol --------
	function addStimuli(obj, newCones)
		% validate input - could be edit box

		% add to stimulus queue
		obj.nextStimulus = [obj.nextStimulus newCones];

		% reflect changes in the stimulus queue
		set(obj.handles.tx.queue, 'String', obj.nextStimulus);

	end % addStimuli


	function assignNextStimulus(obj)
        % This should be the very last thing called per epoch
		%if obj.handles.leadWithNull.Value && obj.runPausedSoMayNeedNullEpoch
		if obj.runPausedSoMayNeedNullEpoch
			disp('adding lead epoch');
			obj.ignoreNextEpoch = true;
			obj.runPausedSoMayNeedNullEpoch = false;
			% add an extra stimulus
			obj.nextStimulus = [obj.nextStimulus(1), obj.nextStimulus];
		end

		% don't want to wait 10s for null epochs
		if obj.ignoreNextEpoch
			obj.nextStimTime = 500;
		else
			obj.nextStimTime = 10000;
		end

		% just chromatic class for now
		fprintf('figure - setting next cone to %s\n', obj.nextStimulus(1));
		obj.nextCone = obj.nextStimulus(1);
        % set the coneInd
        obj.coneInd = strfind(obj.CONES, obj.nextCone);

		% move queue up 
		obj.nextStimulus(1) = [];

		% reflect in the ui
		obj.updateUi();
	end

	function resumeProtocol(obj)
		if isempty(obj.nextStimulus)
			disp('empty stimulus list');
		else
			uiresume(obj.figureHandle);
			set(obj.figureHandle, 'Name', 'Cone Filter Figure');
		end
	end % resumeProtocol

	function waitIfNecessary(obj)
		if isempty(obj.nextStimulus)
			disp('waiting for input');
			set(obj.figureHandle, 'Name', 'Cone Filter Figure: PAUSED');
			obj.runPausedSoMayNeedNullEpoch = true;
			uiwait(obj.figureHandle);
		end
	end % waitIfNecessary
end % methods

%% ------------------------------------------------ toolbar ------------
methods (Access = private)
	function onSelected_debugButton(obj, ~, ~)
		outputStruct = obj;
		answer = inputdlg('Send to workspaces as: ',...
			'Debug Dialog', 1, {'r'});
		assignin('base', sprintf('%s', answer{1}), outputStruct);
		fprintf('%s - figure data sent as %s', datestr(now), answer{1});
	end % onSelected_debugButton

	function onSelected_fitLN(obj, ~, ~)

		if isempty(obj.frameMonitor)
			return;
		end

		measuredResponse = reshape(obj.allResponses', 1, numel(obj.allResponses));
		stimulusArray = reshape(obj.allStimuli', 1, numel(obj.allStimuli));
		linearPrediction = conv(stimulusArray, obj.newFilter);
		linearPrediction = linearPrediction(1:length(stimulusArray));
		[~, edges, bins] = histcounts(linearPrediction, 'BinMethod', 'auto');
		binCntrs = edges(1:end-1) + diff(edges);

		binResp = zeros(size(binCntrs));
		for bb = 1:length(binCntrs)
			binResp(bb) = mean(measuredResponse(bin == bb));
		end
	end

	function [xBin, yBin] = getNL(obj, P, R)
		[a, b] = sort(P(:));
		xSort = a;
		ySort = R(b);

		% bin the data
	end % getNL

end % methods private

methods (Static)
% random methods for convinience. slowly moving elsewhere
	function newMean = stepMean(prevMean, prevN, newValue)
		x = prevMean * prevN;
		newMean = (x + newValue)/(prevN + 1);
	end % stepMean

end % methods static
end % classdef
