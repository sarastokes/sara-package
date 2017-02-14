function SpikeDetectionGUI(r, varargin)
	% INPUTS:r = data structure from parseDataOnline, parseDataOffline
	% OPTIONAL:		epochNum = which epoch to start on, default 1
	%				expStatus = online, offline, onoffline (used by other fcns)
	%
	% TODO: figure out why output never worked
	%  		currently set at no output and using assignin to guioutput variable
	%		not a great idea in the long run
	% TODO: change inputs to resp, spikes, spikeData.. or even just resp matrix
	% epochNum = epoch number to show (0 or none for all epochs)
	%
	% 6Dec2016 - sorted handles to make this more manageable
	set(gcf, 'DefaultAxesFontSize', 10, 'DefaultAxesFontName', 'Segoe UI');

	ip = inputParser();
	ip.addParameter('epochNum', 1, @(x)isvector(x));
	ip.addParameter('detect', false, @(x)islogical(x));
	ip.parse(varargin{:});
	S.detectSpikes = ip.Results.detect;
	S.epochNum = ip.Results.epochNum;
    S.r = r;

	% flag for changes to spike detection
	S.changedSpikes = 0;

	f.h = figure('Name', 'Spike Detection GUI',...
		'Units', 'normalized',...
		'NumberTitle', 'off',...
		'MenuBar', 'none',...
		'Color', 'w');
%    set(f.h, 'CloseRequestFcn', {@onFigureClose,f});

	%% basic layout
	mainLayout = uix.HBox('Parent', f.h,...
		'Padding', 5, 'Spacing', 5,...
		'BackgroundColor', 'w');
	axLayout = uix.VBoxFlex('Parent', mainLayout,...
		'Padding', 3, 'Spacing', 1,...
		'BackgroundColor', 'w');
	uiLayout = uix.VBox('Parent', mainLayout,...
		'Padding', 5, 'Spacing', 5,...
		'BackgroundColor', 'w');
	set(mainLayout, 'Widths', [-3 -1]);

	%% create the user interface panel
	S.tx1 = uicontrol('Style', 'text', 'Parent', uiLayout,...
		'String', 'Change Epoch');
	% buttons to switch epochs
	epochLayout = uix.HButtonBox('Parent', uiLayout);
	% button to go back one epoch
	S.pb.epochBack = uicontrol('Style', 'pushbutton',...
		'Parent', epochLayout,...
		'String', '<--');
	set(S.pb.epochBack, 'Callback', {@onSelected_epochBack,f});
	if S.epochNum == 1, set(S.pb.epochBack, 'Enable', 'off'); end
	% button to go forward one epoch
	S.pb.epochFwd = uicontrol('Style', 'pushbutton',...
		'Parent', epochLayout,...
		'String', '-->');
	set(S.pb.epochFwd, 'Callback', {@onSelected_epochFwd, f});
	if S.epochNum == size(r.resp,1), set(S.pb.epochFwd, 'Enable', 'off'); end

	empty1 = uix.Empty('Parent', uiLayout); %#ok<NASGU>
    %% threshold control
	S.preTxt = uicontrol('Style', 'text', 'Parent', uiLayout,...
		'String', '');
	S.ed.thresh(1) = uicontrol('Style', 'edit',...
		'Parent', uiLayout,...
		'String', '0');
	S.ed.thresh(2) = uicontrol('Style', 'edit',...
		'Parent', uiLayout,...
		'String', '0');
	S.pb.applyThresh = uicontrol('Style', 'pushbutton',...
		'Parent', uiLayout,...
		'String', 'Apply Threshold');
	set(S.pb.applyThresh, 'Callback', {@onSelected_applyThreshold,f});
	S.pb.saveThresh = uicontrol('Style', 'pushbutton',...
		'Parent', uiLayout,...
		'String', 'Save Threshold');
	set(S.pb.saveThresh, 'Callback', {@onSelected_saveThreshold, f});

	% save currently applied threshold to all epochs after
	S.saveAll = uicontrol('Style', 'checkbox',...
		'Parent', uiLayout,...
		'String', 'Save to all epochs');

	empty2 = uix.Empty('Parent', uiLayout); %#ok<NASGU>

	S.txt2 = uicontrol('Style', 'text',...
		'Parent', uiLayout,...
		'String', 'detection method');

	%% spike detection method
	% detect using differential of response
	S.pb.diff = uicontrol('Style', 'pushbutton',...
		'Parent', uiLayout,...
		'String', 'Differential');
	set(S.pb.diff, 'Callback', {@onSelected_diff,f});
	% detect using SDO
	S.pb.sdo = uicontrol('Style', 'pushbutton',...
		'Parent', uiLayout,...
		'String', 'SpikeDetectorOnline',...
		'Enable', 'off'); % default is SDO
	set(S.pb.sdo, 'Callback', {@onSelected_sdo,f});
	% option to save second neuron
	S.cb.N2 = uicontrol('Style', 'checkbox',...
		'Parent', uiLayout,...
		'String', 'Save 2nd neuron');

	% size ratio: 1 for empty and text, 1.5 for everything else
	set(uiLayout, 'Heights', [-1 -1.5 -1 -1 -1.5 -1.5 -1.5 -1.5 -1.5 -1 -1 -1.5 -1.5 -1.5]);

	%% create the axes
	S.ax.resp = axes('Parent', axLayout,...
		'XLimMode', 'manual', 'XLim', [1 size(S.r.resp,2)],...
		'Box', 'off', 'TickDir', 'out',...
		'TitleFontWeight', 'normal');
	S.ax.spikes = axes('Parent', axLayout,...
		'XLimMode', 'manual', 'XLim', [1 size(S.r.resp,2)],...
		'YLimMode', 'manual', 'YLim', [0 1],...
		'Box', 'off', 'TickDir', 'out',...
		'XColor', 'w', 'XTick', {},...
		'TitleFontWeight', 'normal');
	S.ax.detect = axes('Parent', axLayout,...
		'XLimMode', 'manual', 'XLim', [1 size(S.r.resp,2)],...
		'Box', 'off', 'TickDir', 'out');
	set(axLayout, 'Heights', [-1.5 -1 -1.5]);

	% plot the input epoch (default = 1)
	S.line.resp = line(1:size(S.r.resp, 2), S.r.resp(S.epochNum,:),...
		'Parent', S.ax.resp, 'Color', 'k');
	set(S.ax.resp, 'YLimMode', 'manual',...
		'YLim', [floor(min(S.r.resp(S.epochNum,:))) ceil(max(S.r.resp(S.epochNum,:)))]);
	title(S.ax.resp, sprintf('epoch %u of %u', S.epochNum, size(S.r.resp,1)));

	% plot original SDO spikes
	S.line.spikes = line(1:size(S.r.spikes,2), S.r.spikes(S.epochNum,:),...
		'Parent',S.ax.spikes);
	% init line for new spikes
	S.line.newSpikes(1) = line(1:size(S.r.spikes,2), zeros(1, size(S.r.spikes,2)),...
		'Parent', S.ax.spikes, 'Color', rgb('light red'));
	S.line.newSpikes(2) = line(1:size(S.r.spikes,2), zeros(1, size(S.r.spikes,2)),...
		'Parent', S.ax.spikes, 'Color', rgb('jade'));
	title(S.ax.spikes, sprintf('Initial detection = %u spikes',...
		size(nonzeros(S.r.spikes(S.epochNum)), 1)));

	if ~S.detectSpikes
		S.line.detected = line(1:length(S.r.spikeData.resp(S.epochNum,:)),...
			S.r.spikeData.resp(S.epochNum,:),...
			'Parent', S.ax.detect, 'Color', 'k');
	else
		% TODO: run spike detector online
	end
	set(S.ax.detect, 'XColor', 'w', 'XTick', {}, 'Box', 'off',...
		'YGrid', 'on', 'YMinorGrid', 'on', 'XLim', [0 size(S.r.resp,2)]);
	S.line.cutoff = line([1 size(S.r.spikes,2)], [0 0],...
     	'Parent', S.ax.detect, 'color', [0.5 0.5 0.5]);

	% init fields for thresholds and detectionMethod if doesn't already exist
	if ~isfield(S.r.spikeData, 'threshold')
		S.r.spikeData.threshold = zeros(1, size(S.r.resp,1));
		S.r.spikeData.detectionMethod = zeros(1, size(S.r.resp,1));
		set(S.preTxt, 'String', 'Original Spikes')
    elseif S.r.spikeData.detectionMethod(1) ~= 0
    	set(S.preTxt, 'String', 'Corrected Spikes');
    end

    S.detectionMethod = 1; % default is SDO

    S.N2.spikes = zeros(size(S.r.spikes));
    S.N2.spikeData.amps = zeros(18,1);
    S.N2.spikeData.amps = num2cell(S.N2.spikeData.amps);
    S.N2.spikeData.times = S.N2.spikeData.amps;

    setappdata(f.h, 'GUIdata', S);

%%CALLBACKS%%%%%%%%%%%%%%%%%%%
	function onSelected_epochBack(varargin)
		% move to previous epoch
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% don't allow below epoch 1
		if S.epochNum == 1;return;end
		% increment epochNum
		S.epochNum = S.epochNum - 1;
		% disable epoch back if reached 1st epoch
		if S.epochNum == 1
			set(S.pb.epochBack, 'Enable', 'off');
		end

		% update the plots
		updatePlots('epoch');

    	% if save button was disabled, enable
    	set(S.pb.saveThreshS.pb.saveThresh, 'Enable', 'on');
    	% show whether spikes have already been corrected
		if S.r.spikeData.detectionMethod == 0
			set(S.preTxt, 'String', 'Original spikes');
		else
			set(S.preTxt, 'String', 'Corrected spikes');
		end

    	% get rid of new spikes line from last epoch
    	set(S.line.newSpikes(1), 'YData', zeros(1, size(S.r.spikes,2)));
		set(S.line.newSpikes(2), 'YData', zeros(1, size(S.r.spikes,2)));

    	setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_epochFwd(varargin)
		% move to next epoch
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% don't allow above last epoch
		if S.epochNum == size(r.resp, 1);return;end

		S.epochNum = S.epochNum + 1;

		% disable epochFwd button if reached last epoch
		if S.epochNum == size(r.resp, 1)
			set(S.pb.epochFwd, 'Enable', 'off');
		% enable epochBack if moved from first -> second
		elseif S.epochNum ~= 1
			set(S.pb.epochBack, 'Enable', 'on');
		end

		% if save threshold button was disabled, enable
		set(S.pb.saveThresh, 'Enable', 'on');

		% update the plots
		updatePlots('epoch');

		% get rid of prior epoch's newSpikes
		set(S.newSpikes(1), 'YData', zeros(1, size(S.r.spikes,2)));
		set(S.newSpikes(2), 'YData', zeros(1, size(S.r.spikes,2)));

		% show whether spikes have already been corrected
		if S.r.spikeData.detectionMethod == 0
			set(S.preTxt, 'String', 'Original spikes');
		else
			set(S.preTxt, 'String', 'Corrected spikes');
		end

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_applyThreshold(varargin)
		% apply threshold
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');
		threshold = str2double(get(S.ed.thresh(1), 'String'));
		threshold2 = str2double(get(S.ed.thresh(2), 'String'));

		% new method:
		% foundN2 = 0; % TODO: might not keep this
		if S.detectionMethod == 1 % SDO
			oldAmps = S.r.spikeData.amps{epochNum};
			over = find(oldAmps >= threshold);
			under = find(oldAmps < threshold);
			S.tmp.times = S.r.spikeData.times{epochNum}(over);
			S.tmp.amps = oldAmps(over);
			if ~isempty(under)
				% foundN2 = 1;
				S.tmp.N2.times = S.r.spikeData.times{epochNum}(under);
				S.tmp.N2.amps = oldAmps(under);
				S.tmp.N2.spikes = zeros(1, size(S.r.resp,2));
				S.tmp.N2.spikes(S.tmp.N2.times) = 1;
			end
    	else % derivative method
    		% first clip for the larger spikes
    		[S.tmp.spikes, S.tmp.times, S.tmp.amps] = getDiffSpikes(S, threshold);
    		% rerun with smaller threshold
    		[S.tmp.N2.spikes, S.tmp.N2.times, S.tmp.amps] = getDiffSpikes(S, threshold2);
    		% the differences b/w the 2 arrays are the actual subthreshold spikes
    		index = S.tmp.spikes == S.tmp.N2.spikes;
    		S.tmp.N2.times = find(index == 0);
    		S.tmp.N2.spikes(:) = 0;
    		S.tmp.N2.spikes(S.tmp.N2.times) = 1;
    		% set amps to 0 so it doesn't throw off mixed SDO/diff epochBlocks
    		S.tmp.N2.amps = 0; S.tmp.amps = 0;
    	end

		% plot new spikes
		set(S.line.newSpikes(1), 'YData', S.tmp.spikes);
		if (get(S.cb.N2,'Value') == get(S.cb.N2,'Max'))
			S.line.newSpikes(2) = line(1:length(S.tmp.N2.spikes), S.tmp.N2.spikes,...
				'Parent', S.ax.spikes, 'color', rgb('jade'));
		end

		% plot threshold
		set(S.line.cutoff, 'YData', [threshold threshold]);
		if get(S.cb.N2, 'Value') == get(S.cb.N2, 'Max')
			set(S.line.cutoff, 'YData', [threshold2 threshold2]);
			N2str = sprintf('new = %u + %u spikes', size(nonzeros(S.tmp.spikes), 1),... 
                size(nonzeros(S.tmp.N2.spikes), 1));
		else
			N2str = sprintf('new = %u spikes', size(nonzeros(S.tmp.spikes), 1));
		end

		% update title to reflect new spike count
		title(S.ax.spikes, sprintf('Initial detection = %u spikes, %s',...
			size(nonzeros(S.r.spikes(S.epochNum,:)), 1), N2str));

		% if save threshold button was disabled, enable
		set(S.pb.saveThresh, 'Enable', 'on');

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_saveThreshold(varargin)
		% save thresholded data
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');
		threshold = str2double(get(S.ed.thresh(1), 'String'));
		threshold2 = str2double(get(S.ed.thresh(2), 'String'));

		% save to the output structure
		S.r.spikeData.times{S.epochNum} = S.tmp.times;
		S.r.spikes(S.epochNum, :) = S.tmp.spikes;

		% only SDO returns spike amplitudes
		if S.detectionMethod == 1
			S.r.spikeData.amps{S.epochNum} = S.tmp.amps;
		else
			S.r.spikeData.amps{S.epochNum} = 0;
		end

		updateSpikes;

		% disable save threshold button so you know it's been saved
		set(S.pb.saveThresh, 'Enable', 'off');
		% display that spikes have been corrected
		set(S.preTxt, 'String', 'Saved spikes');

		% flag changes to spike detection
		S.changedSpikes = 1;
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_sdo(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% if already SDO
		if S.detectionMethod == 1;return;end
		S.detectionMethod = 1;

		set(S.pb.sdo, 'Enable', 'off');
		set(S.pb.diff, 'Enable', 'on');

		% plot SDO spike amplitudes
		set(S.line.detected, 'YData', S.r.spikeData.resp(S.epochNum,:));
		set(S.line.cutoff, 'YData', [0 0]);

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_diff(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% if already diff
		if S.detectionMethod == 2;return;end

		S.detectionMethod = 2;
		set(S.pb.sdo, 'Enable', 'on');
		set(S.pb.diff, 'Enable', 'off');
		set(S.ed.thresh(2), 'Enable', 'on');

		% plot derivative of response and update YLim
		diffResp = [0 diff(S.r.resp(S.epochNum, :))];
		set(S.line.detected, 'YData', diffResp);
		set(S.ax.detect, 'YLim', [floor(min(diffResp)) ceil(max(diffResp))]);
		clear diffResp;
		% reset the cutoff
		set(S.line.cutoff, 'YData', [0 0]);

		setappdata(f.h, 'GUIdata', S);
	end

	function onFigureClose(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% check to see whether should save
		if S.changedSpikes == 1
			selection = questdlg('Save changes before closing?',...
	      		'Close Request Function',...
	      		'Yes','No','Yes');
	   		switch selection,
	      	case 'Yes',
	      		if (get(S.cb.N2, 'Value' ~= get(S.cb.N2, 'Max')))
	      			S.r = rmfield(S.r, 'N2');
	      		end
		      	assignin('base', 'guioutput', S.r);
	         	delete(gcf);
	      	case 'No'
	      		delete(gcf);
	      	end
	    else
	    	delete(gcf);
	    end
    end

%% UTILS
  function dspk = getDiffSpikes(S, threshold)
		dspk.times = getThresCross([0 diff(S.r.resp(S.epochNum,:))], threshold, 1);
		dspk.spikes = zeros(size(S.r.resp(S.epochNum)));
		dspk.spikes(dspk.times) = 1;
		dspk.amps = 0; % so mixed SDO/diff blocks don't get messed up
  end

function updateSpikes()
  	S.r.spikeData.times{S.epochNum} = S.tmp.times;
  	S.r.spikes(S.epochNum, :) = zeros(1, size(S.r.resp,2));
  	S.r.spikes(S.epochNum, S.r.spikeData.times) = 1;
  	S.r.spikeData.detectionMethod(S.epochNum) = S.detectionMethod;
  	S.r.spikeData.threshold(S.epochNum) = str2double(get(S.ed.threshold(1), 'String'));
  	if ~isempty(S.tmp.N2.times)
  		S.r.N2.spikeData.times{S.epochNum} = S.tmp.N2.times;
  		S.r.N2.spikes(S.epochNum, S.tmp.N2.times) = 1;
  		S.r.N2.spikeData.detectionMethod(S.epochNum) = S.detectionMethod;
  		S.r.N2.threshold = str2double(get(S.ed.threshold(2), 'String'));
  		if strcmp(S.detectionMethod, 'diff')
  			S.r.N2.spikeData.amps{S.epochNum} = 0;
  		else
  			S.r.N2.spikeData.amps{S.epochNum} = S.tmp.N2.amps;
  		end
  	end
end

function updatePlots(plotType)
	% INPUT: epoch, threshold, detection
	% raw response
	if strcmp(plotType, 'epoch')
		set(S.line.resp, 'YData', S.r.resp(S.epochNum,:));
		title(S.ax.resp, sprintf('epoch %u of %u', S.epochNum, size(S.r.resp,1)));
		set(S.line.newSpikes(1), 'YData', zeros(1, size(S.r.resp,2)));
		set(S.line.newSpikes(2), 'YData', zeros(1, size(S.r.resp,2)));
	end

	if strcmp(plotType, 'thresh')
		set(S.line.newSpikes(1), 'YData', S.tmp.spikes);
		if get(S.cb.N2, 'Value') == get(S.cb.N2, 'Max')
			set(S.line.newSpikes(2), 'YData', S.tmp.N2.spikes);
		end
	end

	if strcmp(plotType, 'epoch') || strcmp(plotType, 'thresh')
		set(S.line.cutoff(1), 'YData', get(S.ed.threshold(1), 'String'));
		set(S.line.cutoff(2), 'YData', get(S.ed.threshold(2), 'String'));
	end

	if strcmp(plotType, 'epoch') || strcmp(plotType, 'detection')
		if S.detectionMethod == 1
			set(S.detected, 'YData', S.r.spikeData.resp(S.epochNum,:));
			set(S.line.spikes, 'YData', S.r.spikes(S.epochNum,:));
			title(S.ax.spike, sprintf('initial detection = %u spikes',...
				size(nonzeros(S.r.spikes(S.epochNum,:)), 1)));
		else
			diffResp = diff([0 S.r.resp(S.epochNum, :)]);
			set(S.detected, 'YData', diffResp);
			set(S.ax.detect, 'YLim', [floor(min(diffResp)) ceil(max(diffResp))]);
			diffResp = [];
%			set(S.line.spikes, 'YData', );
		end
	end
end % update plots
end % spikeGUI