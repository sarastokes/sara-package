function strfViewer(r)
	% INPUT: r = data structure
	%
	% 26Dec2016 - added print figure & peaks to cmd line, fixed colormap glitch

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
		S.rgbFlag = 1;
	else
		S.rgbFlag = 0;
	end

	S.normFlag = false;

	if S.rgbFlag == 1 && size(S.strf, 4) ~= 3
		S.strf = shiftdim(S.strf,1);
	end

	f.h = figure('Name', 'STRF Viewer',...
		'Units','normalized',...
		'Color','w',...
		'DefaultAxesFontSize', 10);

	mainLayout = uix.VBox('parent', f.h,...
		'Spacing', 5);
	if S.rgbFlag == 0
		S.ax = axes('parent', mainLayout)
		imagesc(squeeze(mean(S.strf(:,:,3:10), 3)), 'parent', S.ax);
		if ~isempty(S.str)
			title(S.ax, S.str);
		end
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
		'String', '<--');
	S.fwd = uicontrol('parent', buttonLayout,...
		'Style', 'push',...
		'String', '-->');
	S.tx1 = uicontrol('parent', timeLayout,...
		'Style', 'text',...
		'String', 'Mean',...
		'FontSize', 10);
	set(buttonLayout, 'Widths', [-1 -1]);
	set(timeLayout, 'Heights', [-2 -1]);
	meanLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	S.avgT = uicontrol('parent', meanLayout,...
		'Style', 'edit',...
		'String', 't1 t2');
	S.avg = uicontrol('parent', meanLayout,...
		'Style', 'push',...
		'String', 'Mean');
	set(meanLayout, 'Heights', [-2 -1]);
	S.prnt = uicontrol('Parent', uiLayout,...
		'Style', 'push',...
		'String', 'Print figure');
	cmapLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	S.maps = uicontrol('parent', cmapLayout,...
		'Style', 'listbox',...
		'String', {'Parula', 'Bone', 'CubicL', 'CubicYF', 'LMS'});
	S.cmap = uicontrol('parent', cmapLayout,...
		'Style', 'push',...
		'String', 'Switch colormap');
	set(cmapLayout, 'Heights', [-3 -1]);
	idkLayout = uix.VBox('Parent', uiLayout,...
		'Padding', 5, 'Spacing', 5);
	S.normRF = uicontrol('Parent', idkLayout,...
		'Style', 'push',...
		'String', 'show norm');
	S.fpf = uicontrol('parent', idkLayout,...
		'Style', 'push',...
		'String', 'find peaks');
	set(idkLayout, 'Heights', [-1 -1]);
	set(uiLayout, 'Widths', [-1 -1 -1 -1 -1]);

	S.t = 0; S.avgFlag = 1;

	set(S.back, 'Callback', {@onSelected_back, f});
	set(S.fwd, 'Callback', {@onSelected_fwd, f});
	set(S.avg, 'Callback', {@onSelected_avg, f});
	set(S.cmap, 'Callback', {@onSelected_cmap, f});
	set(S.fpf, 'Callback', {@onSelected_fpf, f});
	set(S.prnt, 'Callback', {@onSelected_print, f});
	set(S.normRF, 'Callback', {@onSelected_normRF, f});
	setappdata(f.h, 'GUIdata', S);

%% CALLBACKS %%

	function onSelected_fwd(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = 0;

		if S.t ~= size(S.strf, 3)
			S.t = S.t + 1;
			set(S.tx1, 'String', sprintf(' bin %u: %u-%u ms', S.t, round((S.t-1)*S.binSize), round(S.t*S.binSize)));
			updateStrf(f);
		end
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_back(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = 0;

		if S.t ~= 1
			S.t = S.t - 1;
			updateStrf(f);
			set(S.tx1, 'String', sprintf(' bin %u: %u-%u ms', S.t, round((S.t-1)*S.binSize), round(S.t*S.binSize)));
		end
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_avg(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = 1;

		S.tm = str2num(S.avgT.String);
		t = S.tm(1):S.tm(2);

		if length(S.tm) == 2
			if S.rgbFlag == 1
				for ii = 1:3
					imagesc(squeeze(mean(S.strf(:,:,t,ii),3)),...
						'parent', S.ax(ii));
				end
			else
				imagesc(squeeze(mean(S.strf(:,:,t),3)),...
					'parent', S.ax);
			end
		end
		set(S.tx1, 'String', sprintf('bin %u - %u avg', S.tm(1), S.tm(2)));
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
			S.tm = str2num(S.avgT.String);
			t = S.tm(1):S.tm(2);
		else
			t = S.t;
		end

		if S.rgbFlag == 1
			for ii = 1:3
				S.pk_on{ii} = FastPeakFind(squeeze(mean(S.strf(:,:,t,ii),3)));
				S.pk_off{ii} = FastPeakFind(-1 * squeeze(mean(S.strf(:,:,t,ii),3)));
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

		if S.rgbFlag == 1
			for ii = 1:3
				hold(S.ax(ii), 'on');
				plot(S.pk_on{ii}(1:2:end),S.pk_on{ii}(2:2:end), c{1},...
					'parent', S.ax(ii));
				plot(S.pk_off{ii}(1:2:end), S.pk_off{ii}(2:2:end), c{2},...
					'parent', S.ax(ii));
			end
		else
			hold(S.ax, 'on');
			plot(S.pk_on(1:2:end),S.pk_on(2:2:end), c{1},...
				'parent', S.ax);
			plot(S.pk_off(1:2:end), S.pk_off(2:2:end), c{2},...
				'parent', S.ax);
		end
	end

	function onSelected_cmap(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		unfreezeColors;

		S.cmap_selected = S.maps.String{S.maps.Value};
		switch S.cmap_selected
		case 'LMS'
			if S.rgbFlag == 1
				for ii = 1:3
					colormap(S.ax(1), rgbmap('black', 'grey', 'red')); freezeColors;
					colormap(S.ax(2), rgbmap('black', 'grey', 'green')); freezeColors;
					colormap(S.ax(3), rgbmap('black', 'grey', 'blue')); freezeColors;
				end
			else
				colormap(S.ax, 'bone');
			end
		case {'CubicL' 'CubicYF'}
			if S.rgbFlag == 1
				for ii = 1:size(S.ax)
					colormap(S.ax(ii), pmkmp(126, S.cmap_selected));
				end
			else
				colormap(S.ax, pmkmp(126, S.cmap_selected));
			end
		otherwise
			if S.rgbFlag == 1
				for ii = 1:3
					colormap(S.ax(ii), S.cmap_selected);
				end
			else
				colormap(S.ax, S.cmap_selected);
			end
		end
	end

	function onSelected_print(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');
		%
		% f2 = figure();
		% ax2 = axes('Parent', f2);
		% imagesc(squeeze(S.strf(:,:,S.t)), 'Parent', ax2);

		setappdata(f.h, 'GUIdata', S);
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
		updateStrf(f);

		setappdata(f.h, 'GUIdata', S);
	end

	function updateStrf(f)
		if S.rgbFlag == 0
			imagesc(squeeze(S.strf(:,:,S.t)),...
				'parent', S.ax);
		else
			for ii = 1:3
				imagesc(squeeze(S.strf(:,:,S.t,ii)),...
				'parent', S.ax(ii));
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
	end
end
