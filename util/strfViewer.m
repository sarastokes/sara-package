function strfViewer(r)

	if isstruct(r)
		S.strf = r.analysis.strf;
		if strcmp(r.params.chromaticClass, 'RGB')
			S.rgbFlag = 1;
		else
			S.rgbFlag = 0;
		end
	else
		S.strf = r;
		if length(size(r)) == 4
			S.rgbFlag = 1;
		else
			S.rgbFlag = 0;
		end
	end

	if S.rgbFlag == 1 && size(S.strf, 4) ~= 3
		S.strf = shiftdim(S.strf,1);
	end

	f.h = figure('Name', 'STRF Viewer',...
		'Units','normalized',...
		'Color','w');

	mainLayout = uix.VBox('parent', f.h,...
		'Spacing', 5);
	if S.rgbFlag == 0
		S.ax = axes('parent', mainLayout) 
		imagesc(squeeze(mean(S.strf(:,:,5:10))), 'parent', S.ax);
	else
		axLayout = uix.HBoxFlex('parent', mainLayout);
		for ii = 1:3
			S.ax(ii) = axes('parent', axLayout);
			imagesc(squeeze(mean(S.strf(:,:,5:10,ii),3)),...
				'parent', S.ax(ii));
			set(S.ax(ii), 'XTickLabel', [], 'YTickLabel', []);
		end
		set(axLayout, 'Widths', [-1 -1 -1]);
	end
	uiLayout = uix.HBox('parent', mainLayout,...
		'Padding', 5, 'Spacing', 5);
	buttonLayout = uix.HBox('parent', uiLayout,...
		'Spacing', 5, 'Padding', 5);

	set(mainLayout, 'Heights', [-4 -1]);

	S.back = uicontrol('parent', buttonLayout,...
		'Style', 'push',...
		'String', '<--',...
		'FontSize', 10);
	S.tx1 = uicontrol('parent', buttonLayout,...
		'Style', 'text',...
		'String', 'Mean',...
		'FontSize', 10);
	S.fwd = uicontrol('parent', buttonLayout,... 
		'Style', 'push',...
		'String', '-->',...
		'FontSize', 10);
	set(buttonLayout, 'Widths', [-1 -1 -1]);
	S.avg = uicontrol('parent', uiLayout,...
		'Style', 'push',... 
		'String', 'Mean',...
		'FontSize', 10);
	S.avgT = uicontrol('parent', uiLayout,...
		'Style', 'edit',...
		'String', 't1 t2',...
		'FontSize', 10);
	S.maps = uicontrol('parent', uiLayout,...
		'Style', 'listbox',...
		'String', {'Parula', 'Bone', 'CubicL', 'CubicYF', 'LMS'},...
		'FontSize', 10);
	S.cmap = uicontrol('parent', uiLayout,...
		'Style', 'push',...
		'String', 'Switch colormap',...
		'FontSize', 10);
	S.fpf = uicontrol('parent', uiLayout,...
		'Style', 'push',...
		'String', 'find peaks',...
		'FontSize', 10);
	set(uiLayout, 'Widths', [-1 -1 -1 -1 -1 -1]);

	S.t = 0; S.avgFlag = 1;
	setappdata(f.h, 'GUIdata', S);

	set(S.back, 'Callback', {@onSelected_back,f});
	set(S.fwd, 'Callback', {@onSelected_fwd,f});
	set(S.avg, 'Callback', {@onSelected_avg, f});
	set(S.cmap, 'Callback', {@onSelected_cmap,f});
	set(S.fpf, 'Callback', {@onSelected_fpf,f});

%% CALLBACKS %%

	function onSelected_fwd(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = 0;

		if S.t ~= size(S.strf, 3)
			S.t = S.t + 1;
			set(S.tx1, 'String', sprintf('t = %u msec', S.t));
			updateStrf(f);
		end
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_back(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.avgFlag = 0;

		if S.t ~= 1
			S.t = S.t - 1
			updateStrf(f);
			set(S.tx1, 'String', sprintf('t = %u msec', S.t));
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
		set(S.tx1, 'String', sprintf('t = %u - %u ms avg', S.tm(1), S.tm(2)));

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
					colormap(S.ax(ii), cmap_selected);
				end
			else
				colormap(S.ax, cmap_selected);
			end
		end
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
	end
end




