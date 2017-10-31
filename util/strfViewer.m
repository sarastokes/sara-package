function strfViewer(r)
	% INPUT: r = data structure (BW or RGB noise)
	% this is a better, offline version of ReceptiveFieldFigure
	% code really needs to be cleaned up
	%
	% 26Dec2016 - added print figure & peaks to cmd line, fixed colormap glitch
	% 14Jun2017 - removed print figure, added ingaussfilt and new colormap

	if isstruct(r)
		S.strf = r.analysis.strf;
		S.str = [r.cellName ' - ' r.params.chromaticClass ' receptive field'];
		if isfield(r.analysis, 'binsPerFrame')
			S.binSize = 1000 / (r.params.frameRate * r.analysis.binsPerFrame / r.params.frameDwell);
		else
			S.bpf = 1;
		end
	else
		S.strf = r;
		S.binSize = 1000/60;
		S.str = [];
	end
	if length(size(S.strf))==4
		S.rgbFlag = true;
	else
		S.rgbFlag = false;
	end


	S.t = 0;
	S.sd = 0;
	% this is all getting pretty convoluted.. works though
	S.normFlag = false;
	S.filtFlag = false;
	S.avgFlag = false;

	if S.rgbFlag && size(S.strf, 4) ~= 3
		S.strf = shiftdim(S.strf,1);
	end

	f.h = figure('Name', 'STRF Viewer',...
		'Units','normalized',...
		'Color','w',...
		'DefaultAxesFontSize', 10,...
		'DefaultAxesFontName', 'Roboto',...
		'DefaultUicontrolBackgroundColor', 'w',...
		'DefaultUicontrolFontName', 'Roboto',...
		'DefaultUicontrolFontSize', 10);

	mainLayout = uix.VBox('parent', f.h,...
		'Spacing', 5);
	if ~S.rgbFlag
		S.ax = axes('parent', mainLayout);
        if size(S.strf, 3) >= 10
    		imagesc(squeeze(mean(S.strf(:,:,3:10), 3)), 'Parent', S.ax);
        else
            imagesc(squeeze(mean(S.strf,3)), 'Parent', S.ax);
        end
		if ~isempty(S.str)
			title(S.ax, S.str);
		end
		set(S.ax, 'XTickLabel', [], 'YTickLabel', [])
	else
		axLayout = uix.HBoxFlex('parent', mainLayout);
		for ii = 1:3
			S.ax(ii) = axes('parent', axLayout);
			imagesc(squeeze(mean(S.strf(:,:,3:10,ii),3)),...
				'parent', S.ax(ii));
			set(S.ax(ii), 'XTickLabel', [], 'YTickLabel', []);
		end
		set(axLayout, 'Widths', [-1 -1 -1]);
	end

	uiLayout = uix.HBox('parent', mainLayout,...
		'Padding', 5, 'Spacing', 5);
	timeLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	buttonLayout = uix.HBox('parent', timeLayout,...
		'Spacing', 5, 'Padding', 5);

	set(mainLayout, 'Heights', [-5 -1]);

	S.back = uicontrol('parent', buttonLayout,...
		'Style', 'push',...
		'String', '<--',...
		'Callback', {@onSelected_back, f});
	S.fwd = uicontrol('parent', buttonLayout,...
		'Style', 'push',...
		'String', '-->',...
		'Callback', {@onSelected_fwd, f});
	S.tx.bins = uicontrol('parent', timeLayout,...
		'Style', 'text',...
		'String', 'Mean');
	set(buttonLayout, 'Widths', [-1 -1]);
	set(timeLayout, 'Heights', [-2 -1]);
	meanLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	S.avgT = uicontrol('parent', meanLayout,...
		'Style', 'edit',...
		'String', 't1 t2');
	% S.avgTimes = uitable('Parent', meanLayout,...
	% 	'Data', [0 0]);
	S.avg = uicontrol('parent', meanLayout,...
		'Style', 'push',...
		'String', 'Mean',...
		'Callback', {@onSelected_avg, f});
	set(meanLayout, 'Heights', [-2 -1]);
	filterLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);

	S.filt = uicontrol('Parent', filterLayout,...
		'Style', 'push',...
		'String', 'Gaussian filter',...
		'Callback', {@onSelected_filt, f});
	sigmaLayout = uix.HBox('Parent', filterLayout,...
		'Spacing', 5, 'Padding', 5);
	set(filterLayout, 'Heights', [-1 -2]);
	S.tx.filt = uicontrol('Parent', sigmaLayout,...
		'Style', 'text',...
		'String', 'Sigma: ');
	S.ed.filt = uicontrol('Parent', sigmaLayout,...
		'Style', 'edit',...
		'String', '1');
	set(sigmaLayout, 'Widths', [-2 -1]);
	cmapLayout = uix.HBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	S.cmap = uicontrol('parent', cmapLayout,...
		'Style', 'push',...
		'String', '<html>change<br/>color<br/>map:',...
        'FontSize', 8,...
		'Callback', {@onSelected_cmap, f});
	S.maps = uicontrol('parent', cmapLayout,...
		'Style', 'listbox',...
		'String', {'Parula', 'Bone', 'CubicL', 'Viridis', 'LMS'},...
		'FontSize', 7);
	set(cmapLayout, 'Widths', [-1 -1.75]);
	idkLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	S.normRF = uicontrol('Parent', idkLayout,...
		'Style', 'push',...
		'String', 'show norm',...
		'Callback', {@onSelected_normRF, f});
	S.fpf = uicontrol('parent', idkLayout,...
		'Style', 'push',...
		'String', 'find peaks',...
		'Callback', {@onSelected_fpf, f});
	set(idkLayout, 'Heights', [-1 -1]);
	set(uiLayout, 'Widths', [-1 -0.75 -1 -1.25 -1]);

	setappdata(f.h, 'GUIdata', S);

%% ------------------------------------------------- callbacks ------------


	function onSelected_fwd(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = false;

		if S.t ~= size(S.strf, 3)
			S.t = S.t + 1;
			set(S.tx.bins, 'String', sprintf(' bin %u: %u-%u ms',... 
                S.t, round((S.t-1)*S.binSize), round(S.t*S.binSize)));
			updateStrf();
		end
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_back(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = false;

		if S.t ~= 1
			S.t = S.t - 1;
			updateStrf();
			set(S.tx.bins, 'String', sprintf(' bin %u: %u-%u ms',... 
				S.t, round((S.t-1)*S.binSize), round(S.t*S.binSize)));
		end
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_avg(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = true;

		S.tm = str2num(S.avgT.String);
		t = S.tm(1):S.tm(2);

		if length(S.tm) == 2
			updateAvg(t);
		end
		set(S.tx.bins, 'String', sprintf('bin %u - %u avg',...
			S.tm(1), S.tm(2)));
		if S.normFlag
			set(S.ax, 'CLim', [-1 1]);
		else
			set(S.ax, 'CLimMode', 'auto');
		end
		title(S.ax, S.str);

		setappdata(f.h, 'GUIdata', S);
	end


	function onSelected_fpf(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		if S.avgFlag == 1
			S.tm = str2double(S.avgT.String);
			t = S.tm(1):S.tm(2);
		else
			t = S.t;
		end

		if S.rgbFlag
			for led = 1:3
				S.pk_on{led} = FastPeakFind(squeeze(mean(S.strf(:,:,t,led),3)));
				S.pk_off{led} = FastPeakFind(-1 * squeeze(mean(S.strf(:,:,t,led),3)));
			end
		else
			S.pk_on = FastPeakFind(squeeze(mean(S.strf(:,:,t),3)));
			S.pk_off = FastPeakFind(-1 * squeeze(mean(S.strf(:,:,t),3)));
		end

		if strcmp(S.maps.String{S.maps.Value}, 'bone')
			c = {'g+' 'rx'};
		else
			c = {'w+' 'wx'};
		end

		if S.rgbFlag
			for led = 1:3
				hold(S.ax(led), 'on');
				plot(S.pk_on{led}(1:2:end),S.pk_on{led}(2:2:end), c{1},...
					'Parent', S.ax(led));
				plot(S.pk_off{led}(1:2:end), S.pk_off{led}(2:2:end), c{2},...
					'Parent', S.ax(led));
			end
		else
			hold(S.ax, 'on');
			plot(S.pk_on(1:2:end),S.pk_on(2:2:end), c{1},...
				'Parent', S.ax);
			plot(S.pk_off(1:2:end), S.pk_off(2:2:end), c{2},...
				'Parent', S.ax);
		end
	end

	function onSelected_cmap(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		unfreezeColors;

		S.cmap_selected = S.maps.String{S.maps.Value};
		switch lower(S.cmap_selected)
		case 'lms'
			if S.rgbFlag
					colormap(S.ax(1), rgbmap('black', 'grey', 'red')); freezeColors;
					colormap(S.ax(2), rgbmap('black', 'grey', 'green')); freezeColors;
					colormap(S.ax(3), rgbmap('black', 'grey', 'blue')); freezeColors;
			else
				colormap(S.ax, 'bone');
			end
		case 'cubicl'
			if S.rgbFlag
				for led = 1:size(S.ax)
					colormap(S.ax(led), pmkmp(126, S.cmap_selected));
				end
			else
				colormap(S.ax, pmkmp(126, S.cmap_selected));
			end
		case 'viridis'
			if S.rgbFlag
				for led = 1:size(S.ax)
					colormap(S.ax(led), viridis(256));
				end
			else
				colormap(S.ax, viridis(256));
			end
		otherwise
			if S.rgbFlag
				for led = 1:3
					colormap(S.ax(led), S.cmap_selected);
				end
			else
				colormap(S.ax, S.cmap_selected);
			end
		end
	end

	function onSelected_normRF(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		if S.normFlag
			S.strf = S.oldStrf;
			S.normFlag = false;
			set(S.normRF, 'String', 'show norm');
		else
			S.normFlag = true;
			S.oldStrf = S.strf;
			S.strf = S.strf/max(max(max(abs(S.strf))));
			set(S.normRF, 'String', 'show original');
		end
		updateStrf();

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_filt(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');
        
    try 
    	S.sd = str2double(get(S.ed.filt, 'String'));
    catch      
    	warndlg('Make sure sigma is a number!');
    	set(S.ed.filt, 'String', '0');
    	return;
    end

		if S.filtFlag || S.sd == 0
			S.filtFlag = false;
		else
			S.filtFlag = true;
		end

		if S.avgFlag
			updateAvg(S.tm(1):S.tm(2));
		else
			updateStrf();
		end

		setappdata(f.h, 'GUIdata', S);
	end
%% ------------------------------------------------- support -------------
	function updateStrf()
		if ~S.rgbFlag
			if S.filtFlag
				imagesc(imgaussfilt(squeeze(S.strf(:,:,S.t)), S.sd),...
					'Parent', S.ax);
			else
				imagesc(squeeze(S.strf(:,:,S.t)),...
					'Parent', S.ax);
			end
		else
			for led = 1:3
				if S.filtFlag
					imagesc(imgaussfilt(squeeze(S.strf(:,:,S.t,led)), S.sd),...
						'Parent', S.ax(led));
				else
					imagesc(squeeze(S.strf(:,:,S.t,led)),...
						'Parent', S.ax(led));
				end
			end
		end
		if S.normFlag
			set(S.ax, 'CLim', [-1 1]);
		else
			set(S.ax, 'CLimMode', 'auto');
		end
		if ~isempty(S.str)
			title(S.ax, S.str);
		end
		% set(S.ax, 'XTickLabel', {}, 'YTickLabel', {});
    end % updateStrf


	function updateAvg(t)
		if S.rgbFlag
			for led = 1:3
				if S.filtFlag
					imagesc(imgaussfilt(squeeze(mean(S.strf(:,:,t,led),3)), S.sd),...
						'Parent', S.ax(led));
				else
					imagesc(squeeze(mean(S.strf(:,:,t,led),3)),...
						'Parent', S.ax(led));
				end
			end
		else % achrom
			if S.filtFlag
				imagesc(imgaussfilt(squeeze(mean(S.strf(:,:,t), 3)), S.sd),...
					'Parent', S.ax);
			else
				imagesc(squeeze(mean(S.strf(:,:,t), 3)),...
					'Parent', S.ax);
			end
		end
    end % updateAvg
end
