function SpikeGUI(r, epochNum)
	% r = data structure 
	% TODO: figure out why output never worked
	%  		currently set at no output and using assignin to guioutput variable
	%		not a great idea in the long run
	% TODO: change inputs to resp, spikes, spikeData.. or even just resp matrix
	% epochNum = epoch number to show (0 or none for all epochs)
	set(gcf, 'DefaultAxesFontSize', 7);
	set(gcf, 'DefaultAxesFontName', 'Roboto');

	if nargin < 2
		epochNum = 1;
	end

	% flag for changes to spike detection
	S.changedSpikes = 0;

%	set(groot, 'DefaultAxesColorOrder', distinguishable_colors(3));

	f.h = figure('Name', 'Spike Detection GUI',...
		'Units', 'normalized',...
		'NumberTitle', 'off',...
		'MenuBar', 'none',...
		'Color', 'w');
    set(f.h, 'CloseRequestFcn', {@onFigureClose,f});

	% create gui data structure		 
	S.r = r;
	if epochNum == 0
		S.epochNum = 1; % default = start at 1
    else
		S.epochNum = epochNum;
    end


	% set to userdata
	setappdata(f.h, 'GUIdata', S);

	% basic layout
	mainLayout = uix.HBox('Parent', f.h,...
		'Padding', 5, 'Spacing', 5,...
		'BackgroundColor', 'w');	
	axLayout = uix.VBoxFlex('Parent', mainLayout,...
		'Padding', 3, 'Spacing', 1,...
		'BackgroundColor', 'w');
	uiLayout = uix.VBox('Parent', mainLayout,...
		'Padding', 5, 'Spacing', 5,...
		'BackgroundColor', 'w');
	set(mainLayout, 'widths', [-3 -1]);

	%% create the user interface panel
	S.tx1 = uicontrol('Style', 'text', 'Parent', uiLayout,...
		'String', 'Change Epoch');

	% buttons to switch epochs 
	epochControl = uix.HButtonBox('Parent', uiLayout);
	% button to go back one epoch
	S.epochBack = uicontrol('Style', 'pushbutton',... 
		'Parent', epochControl,...
		'String', '<--',...
		'Tag', 'epochBack');
	set(S.epochBack, 'Callback', {@onSelected_epochBack,f});
	if epochNum == 1, set(S.epochBack, 'Enable', 'off'); end	
	% button to go forward one epoch
	S.epochFwd = uicontrol('Style', 'pushbutton',...
		'Parent', epochControl,...
		'String', '-->');
	set(S.epochFwd, 'Callback', {@onSelected_epochFwd, f});
	if epochNum == size(r.resp,1), set(S.epochFwd, 'Visible', 'off'); end

	empty1 = uix.Empty('Parent', uiLayout); %#ok<NASGU>

	S.thesholdTxt = uicontrol('Style', 'edit',... 
		'Parent', uiLayout,...
		'String', '0',...
		'Tag', 'tInput');
	S.applyThreshold = uicontrol('Style', 'pushbutton',... 
		'Parent', uiLayout,...
		'String', 'Apply Threshold');
	set(S.applyThreshold, 'Callback', {@onSelected_applyThreshold,f});
	S.saveThreshold = uicontrol('Style', 'pushbutton',... 
		'Parent', uiLayout,...
		'String', 'Save Threshold',...
		'FontName', 'Roboto', 'FontSize', 10);
	set(S.saveThreshold, 'Callback', {@onSelected_saveThreshold, f});

	empty2 = uix.Empty('Parent', uiLayout); %#ok<NASGU>

	S.txt2 = uicontrol('Style', 'text',... 
		'Parent', uiLayout,...
		'String', 'detection method');

	% buttons to change detection method
%	methodLayout = uix.VButtonBox('Parent', uiLayout);
	% detect using differential of response
	S.diff = uicontrol('Style', 'pushbutton',... 
		'Parent', uiLayout,...
		'String', 'Differential',...
		'FontName', 'roboto', 'FontSize', 10);
	set(S.diff, 'Callback', {@onSelected_diff,f});
	% detect using SDO
	S.sdo = uicontrol('Style', 'pushbutton',... 
		'Parent', uiLayout,...
		'String', 'SpikeDetectorOnline',...
		'FontName', 'roboto', 'FontSize', 10,...
		'Enable', 'off'); % default is SDO
	set(S.sdo, 'Callback', {@onSelected_sdo,f});

	% size ratio: 1 for empty and text, 1.5 for everything else
	set(uiLayout, 'heights', [-1 -1.5 -1 -1.5 -1.5 -1.5 -1 -1 -1.5 -1.5]);

	% create the axes
	S.respHandle = axes('Parent', axLayout);
	S.spikeHandle = axes('Parent', axLayout);
	S.detectHandle = axes('Parent', axLayout);
	set(axLayout, 'Heights', [-1.5 -1 -1.5]);

	% plot the input epoch (default = 1)
	S.resp = line(1:size(S.r.resp, 2), S.r.resp(S.epochNum,:),... 
		'Parent', S.respHandle, 'color', 'k');
	set(S.respHandle, 'XColor', 'w','XTick', {}, 'box', 'off',... 
		'XLim', [0 length(S.r.resp(S.epochNum,:))],...
		'YLim', [floor(min(S.r.resp(S.epochNum,:))) ceil(max(S.r.resp(S.epochNum,:)))]);
	title(S.respHandle, sprintf('epoch %u of %u', S.epochNum, size(S.r.resp,1)));


	% plot original SDO spikes
	S.spikes = line(1:size(S.r.spikes,2), S.r.spikes(S.epochNum,:),... 
		'Parent',S.spikeHandle);
	set(S.spikeHandle, 'XColor', 'w', 'XTick', {}, 'Box', 'off',...
		'YLim', [0 1], 'XLim', [0 size(S.r.spikes,2)]);
	% init line for new spikes
	S.newSpikes = line(1:size(S.r.spikes,2), zeros(1, size(S.r.spikes,2)),... 
		'Parent', S.spikeHandle, 'color', [1 0 0]);
	title(S.spikeHandle, sprintf('Initial detection = %u spikes',... 
		size(nonzeros(S.r.spikes(S.epochNum)), 1)));

	if isfield(S.r.spikeData,'resp')
		S.detected = line(1:length(S.r.spikeData.resp(S.epochNum,:)),... 
			S.r.spikeData.resp(S.epochNum,:),...
			'Parent', S.detectHandle, 'Color', 'k');
	else % this is prob unnecessary, remove when sure
	    response = wavefilter(S.r.resp(S.epochNum,:)', 6);
        tmp.SDO = spikeDetectorOnline(response);
        tmp.spikeResp = zeros(1, size(S.r.spikes,2));
      	tmp.spikeResp(SDO.sp) = SDO.spikeAmps;
      	S.detected = line(1:size(S.r.spikeData.resp, 2), tmp.spikeResp,...
      		'Parent', S.detectHandle, 'Color', 'k');
    end
	set(S.detectHandle, 'XColor', 'w', 'XTick', {}, 'Box', 'off',...
		'YGrid', 'on', 'YMinorGrid', 'on', 'XLim', [0 size(S.r.resp,2)]);
	S.cutoff = line([1 size(S.r.spikes,2)], [0 0],... 
     	'Parent', S.detectHandle, 'color', [0.5 0.5 0.5]);

	% init fields for thresholds and detectionMethod if doesn't already exist
	if ~isfield(S.r.spikeData, 'threshold')
		S.r.spikeData.threshold = zeros(1, size(S.r.resp,1));
		S.r.spikeData.detectionMethod = zeros(1, size(S.r.resp,1));
    end
    S.detectionMethod = 1; % default is SDO

    setappdata(f.h, 'GUIdata', S);


%%CALLBACKS%%%%%%%%%%%%%%%%%%%
	function onSelected_epochBack(varargin)
		% move to previous epoch
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% don't allow below epoch 1
		if S.epochNum == 1
			return;
		end

		% increment epochNum
		S.epochNum = S.epochNum - 1;

		% disable epoch back if reached 1st epoch
		if S.epochNum == 1
			set(S.epochBack, 'Enable', 'off');
		end

		% update the plots
		set(S.resp, 'YData', S.r.resp(S.epochNum,:));
		title(S.respHandle, sprintf('epoch %u of %u', S.epochNum, size(S.r.resp,1)));
		set(S.spikes, 'YData', S.r.spikes(S.epochNum,:));
		title(S.spikeHandle, sprintf('Initial detection = %u spikes',... 
			size(nonzeros(S.r.spikes(S.epochNum)), 1)));
		if S.detectionMethod == 1
			set(S.detected, 'YData', S.r.spikeData.resp(S.epochNum,:));
			set(S.detectHandle, 'YLim', [floor(min(S.r.spikeData.resp(S.epochNum,:)))... 
			ceil(min(S.r.spikeData.resp(S.epochNum,:)))]);
		else
			set(S.detected, 'YData', [0 diff(S.r.resp(S.epochNum,:))]);
			set(S.detectHanlde, 'YLim', [floor(min(get(S.detected, 'YData')))... 
				ceil(max(get(S.detected, 'YData')))]);
        end

        % if save button was disabled, enable
        set(S.saveThreshold, 'Enable', 'on');

        % get rid of new spikes line from last epoch        
        set(S.newSpikes, 'YData', zeros(1, size(S.r.spikes,2)));

        setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_epochFwd(varargin)
		% move to next epoch
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% don't allow above last epoch
		if S.epochNum == size(r.resp, 1)
			return;
		end

		S.epochNum = S.epochNum + 1;

		% disable epochFwd button if reached last epoch
		if S.epochNum == size(r.resp, 1)
			set(S.epochFwd, 'Enable', 'off');

		% enable epochBack if moved from first -> second
		elseif S.epochNum ~= 1
%			set(findobj(gcbf, 'Tag', 'epochBack'), 'Enable', 'on');
			set(S.epochBack, 'Enable', 'on');
		end

		% if save threshold button was disabled, enable
		set(S.saveThreshold, 'Enable', 'on');

		% update the plots
		set(S.resp, 'YData', r.resp(S.epochNum,:));
		title(S.respHandle, sprintf('epoch %u of %u', S.epochNum, size(S.r.resp,1)));
		set(S.spikes, 'YData', r.spikes(S.epochNum,:));
		title(S.spikeHandle, sprintf('Initial detection = %u spikes',... 
			size(nonzeros(S.r.spikes(S.epochNum)), 1)));
		if S.detectionMethod == 1
			set(S.detected, 'YData', S.r.spikeData.resp(S.epochNum,:));
			set(S.detectHandle, 'YLim', [floor(min(S.r.spikeData.resp(S.epochNum,:)))... 
			ceil(max(S.r.spikeData.resp(S.epochNum,:)))]);
		else
			diffResp = diff([0 S.r.resp(S.epochNum,:)]);
			set(S.detected, 'YData', diffResp);
			set(S.detectHandle, 'YLim', [floor(min(diffResp))... 
				ceil(max(diffResp))]);
			clear diffResp;
		end
		
		% get rid of prior epoch's newSpikes
		set(S.newSpikes, 'YData', zeros(1, size(S.r.spikes,2))); % get rid of newSpikes line

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_applyThreshold(varargin)
		% apply threshold

		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');
		threshold = str2double(get(findobj(gcbf, 'Tag', 'tInput'), 'String'));

		% get new spikes
		if S.detectionMethod == 1
			correctedSpikeTimes = 0; correctedSpikeAmps = 0;
    		for ii = 1:length(r.spikeData.times{S.epochNum})
        		if r.spikeData.amps{S.epochNum}(1,ii) > threshold
          			correctedSpikeTimes(1, end+1) = S.r.spikeData.times{S.epochNum}(ii);
          			correctedSpikeAmps(1, end+1) = S.r.spikeData.amps{S.epochNum}(ii);
                end
            end
    		S.tmp.spikeTimes = correctedSpikeTimes(2:end);
    		S.tmp.spikeAmps = correctedSpikeAmps(2:end);
    		S.tmp.spikes = zeros(1, size(S.r.resp,2));
    		S.tmp.spikes(S.tmp.spikeTimes) = 1;	
    	else
    		S.tmp.spikeTimes = getThresCross([0 diff(S.r.resp(S.epochNum,:))], threshold, 1);
    		S.tmp.spikes = zeros(size(S.r.resp(S.epochNum,:)));
    		S.tmp.spikes(S.tmp.spikeTimes) = 1;
    	end  

		% plot new spikes
		if S.newSpikes == 0
			S.newSpikes = line(1:length(S.tmp.spikes), S.tmp.spikes,... 
				'parent', S.spikeHandle, 'color', [1 0 0]);
		else
			set(S.newSpikes, 'YData', S.tmp.spikes);
		end
		% update title to reflect new spike count
		title(S.spikeHandle, sprintf('Initial detection = %u spikes, new = %u spikes',... 
			size(nonzeros(S.r.spikes(S.epochNum)), 1),...
			size(nonzeros(S.tmp.spikes), 1)));

		% plot threshold
		set(S.cutoff, 'YData', [threshold threshold]);

		% if save threshold button was disabled, enable
		set(S.saveThreshold, 'Enable', 'on');

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_saveThreshold(varargin)
		% save thresholded data

		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');
		threshold = str2double(get(findobj(gcbf, 'Tag', 'tInput'), 'String'));

		% save to the output structure
		S.r.spikeData.times{S.epochNum} = S.tmp.spikeTimes;
		S.r.spikes(S.epochNum, :) = S.tmp.spikes;

		% only SDO returns spike amplitudes
		if S.detectionMethod == 1
			S.r.spikeData.amps{S.epochNum} = S.tmp.spikeAmps;
		else
			S.r.spikeData.amps{S.epochNum} = 0;
		end

		% save threshold and method used
		S.r.spikeData.threshold(S.epochNum) = threshold;
		S.r.spikeData.detectionMethod(S.epochNum) = S.detectionMethod;

		% disable save threshold button so you know it's been saved
		set(S.saveThreshold, 'Enable', 'off');

		% flag changes to spike detection
		S.changedSpikes = 1;
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_sdo(varargin)
		% use SpikeDetectorOnline

		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% if already SDO
		if S.detectionMethod == 1
			return;
		end
		S.detectionMethod = 1;

		set(S.sdo, 'Enable', 'off');
		set(S.diff, 'Enable', 'on');

		% plot SDO spike amplitudes and update YLim
		set(S.detected, 'YData', S.r.spikeData.resp(S.epochNum,:));
		set(S.detectHandle, 'YLim', [floor(min(S.r.spikeData.resp(S.epochNum,:)))... 
			ceil(min(S.r.spikeData.resp(S.epochNum,:)))]);
		set(S.cutoff, 'YData', [0 0]);

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_diff(varargin)
		% use differential of response

		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		% if already diff
		if S.detectionMethod == 2
			return;
		end

		S.detectionMethod = 2;
		set(S.sdo, 'Enable', 'on');
		set(S.diff, 'Enable', 'off');

		% plot derivative of response and update YLim
		diffResp = [0 diff(S.r.resp(S.epochNum, :))];
		set(S.detected, 'YData', diffResp);
		set(S.detectHandle, 'YLim', [floor(min(diffResp)) ceil(max(diffResp))]);
		clear diffResp;
		% reset the cutoff
		set(S.cutoff, 'YData', [0 0]);

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
	      		assignin('base', 'guioutput', S.r);
	         	delete(gcf);
	      	case 'No'
	      		delete(gcf); 
	      	end
	    else
	    	delete(gcf);
	    end
    end
end % spikeGUI

