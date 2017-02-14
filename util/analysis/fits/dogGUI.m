function dogGUI(sf, f1, varargin)
	% INPUTS:
	% 	sf 		spatial frequencies, should be cpd but will catch if pix
	%	f1 		f1 amplitudes
	% OPTIONAL
	%	p1 		phases
	%	theta   orientation
	%
	% DOG (enroth cugell 1983)
	% R = Rc - Rs = C * [Kc*pi*Rc^2*e^(-(pi*Rc*x))^2 - Ks*pi*Rs*e^(-(pi*Rs*x))^2]
	%
	% DOG with ellipse RF (soodak 1982)
	%
	% Offset
	% R = offset + R
	%
	% normal3 - (work in progress)
	% R = Rc - (Rsc-Rss) = C * [Kc*pi*Rc^2*e^(-(pi*Rc*x))^2 - Ks*pi*Rs*e^(-(pi*Rs*x))^2 + Kh*pi*Rh*e^(-(pi*Rh*x))^2]
	%
	%
	% Croner Kaplan 1995 (median, IQR)
	% 0-5 deg --> Kc = 352 (208), Rc = 0.03 (0.01), Ks = 4.4 (4.6), Rs = 0.18 (0.07)
	% 5-10 deg -> Kc = 114 (147), Rc = 0.05 (0.03), Ks = 0.7 (1.1), Rs = 0.43 (0.28)
	%
	% Crook et al (2008)
	%
	% 23Dec2016 - created, functional but messy
	% 3Jan - DoG3 experiment.. not going great
	% 4Jan - ellipse works outside
	%

	ip = inputParser();
	ip.addParameter('p1', [], @(x)isvector(x));
	ip.addParameter('theta', 0, @(x)isvector(x));
	ip.parse(varargin{:});
	S.data.theta = ip.Results.theta;
	theta = S.data.theta; % placeholder
	if isempty(ip.Results.p1)
		S.flag.phasePlot = false;
	else
		S.flag.phasePlot = true;
		S.data.p1 = ip.Results.p1; S.data.trueP1 = S.data.p1;
	end

	if max(sf) > 10 % probably not in cpd
		selection = questdlg('Convert to cycles per degree?',...
			'SF unit check',...
			'Yes', 'No', 'Yes');
		switch selection
		case 'Yes'
			sf = pix2deg(sf);
            fprintf('Converted to cpd\n');
		case 'No'
			fprintf('Odd spatial frequencies\n');
		end
	end

	S.data.f1 = f1; S.data.trueF1 = f1;
	S.data.sf = sf; S.data.trueSF = sf;

	if size(S.data.f1,1)>1
		S.flag.matrix = true;
		S.co = pmkmp(size(S.data.f1,1), 'CubicL');
	else
		S.flag.matrix = false;
	end

	% default fcn
	S.fcn.g2fun = @(v,x)(v(5)*abs(v(1)*pi*v(2)^2 * exp(-(pi*v(2)*x).^2) - v(3)*pi*v(4)^2*exp(-(pi*v(4)*x).^2)));
	S.params = {'Kc', 'Rc', 'Ks', 'Rs', 'BL'}; % default
	S.lb = zeros(1,length(S.params));
	S.ub = Inf + zeros(1, length(S.params));
	theta = 0;

  	S.fcn.gfun = @(v,x)((v(1)*exp(-(x*v(2)/2).^2) - v(3)*exp(-(x*v(4)/2).^2)));
	S.fcn.g3fun = @(v,x)(v(5)*abs(v(1)*pi*v(2)^2 * exp(-(pi*v(2)*x).^2) - v(3)*pi*v(4)^2*exp(-(pi*v(4)*x).^2) + v(5)*pi*v(6)^2 * exp(-(pi*v(6)*x).^2)));
	S.fcn.ellipse2 = @(v,sf)(v(9) * abs((pi*v(1)*v(2)*v(3)*exp(-(pi*v(2)*v(3)*sf).^2 * (sin(theta - v(4)).^2/v(2)^2) + cos(theta-v(4)).^2/v(3)^2)) - (pi*v(5)*v(6)*v(7) * exp((-(pi*v(6)*v(7)*sf).^2) * (sin(S.data.theta - v(8)).^2/v(6) + cos(S.data.theta - v(9)).^2/v(7)^2)))));
	S.fcn.ellipse1 = @(v, sf)(v(5) .* abs(pi*v(1)*v(2)*v(3)*exp(-(pi*v(2)*v(3)*sf).^2 * (sin(theta - v(4)).^2/v(2)^2) + cos(theta-v(4)).^2/v(3)^2)));
	S.fcn.offset = @(v, sf)(v(5) + (v(1)*(1-exp(-(sf/2).^2 ./ (2*v(2).^2))) - v(3)*(1-exp(-(sf/2).^2 ./ (2*v(4)^2)))));

	S.flag.fit = false;

	f.h = figure('Name', 'DoG GUI',...
		'Units', 'normalized',...
		'Color', 'w',...
		'DefaultAxesFontSize', 8,...
		'HandleVisibility', 'on',...
		'Position', [0.3 0.3 0.52 0.59],...
		'DefaultUiControlFontName', 'Roboto',...
		'DefaultUiControlFontSize', 8,...
		'DefaultAxesColorOrder', pmkmp(8, 'cubicL'));

	mainLayout = uix.HBoxFlex('Parent', f.h,...
		'Spacing', 5, 'Padding', 5);
	axLayout = uix.VBox('Parent', mainLayout,...
		'Spacing', 5, 'Padding', 5);

	S.ax.f1 = axes('Parent', axLayout,...
		'XScale', 'log',...
		'XLim', [S.data.sf(1) S.data.sf(end)]);
	ylabel(S.ax.f1, 'F1 amplitude');
	if S.flag.phasePlot
		S.ax.p1 = axes('Parent', axLayout,...
			'XLim', [S.data.sf(1) S.data.sf(end)]);
		if max(S.data.p1) > 5
			set(S.ax.p1, 'YLim', [-180 180], 'YTick', -180:90:180);
		else
			set(S.ax.p1, 'YLim', [-5 5], 'YTick', -5:2.5:5);
		end
		set(axLayout, 'Heights', [-4 -1]);
		xlabel(S.ax.p1, 'cycles per degree');
		ylabel(S.ax.p1, 'f1 phase');
	else
		set(axLayout, 'Heights', -1);
		xlabel(S.ax.f1, 'cycles per degree');
	end

	uiLayout = uix.VBox('Parent', mainLayout,...
		'Spacing', 5, 'Padding', 5);
	fitLayout = uix.HBox('Parent', uiLayout,...
		'Spacing', 5, 'Padding', 5);
	S.lst.fcn = uicontrol('Parent', fitLayout,...
		'Style', 'list',...
		'String', {'normal2', 'normal1', 'offset', 'ellipse1', 'ellipse2'});
	advLayout = uix.VBox('Parent', fitLayout,...
		'Spacing', 5, 'Padding', 5);
	S.pb.fcn = uicontrol('Parent', advLayout,...
		'Style', 'push',...
		'String', 'Fit Fcn');
	S.pb.adv = uicontrol('Parent', advLayout,...
		'Style', 'push',...
		'String', 'Adv');
	set(fitLayout, 'Widths', [-3 -1]);
	set(advLayout, 'Heights', [-2 -1]);
	S.paramLayout = uix.VBox('Parent', uiLayout,...
		'Spacing', 5, 'Padding', 5);

	sfLayout = uix.HBox('Parent', S.paramLayout,...
		'Padding', 5, 'Spacing', 5);
	S.ed1.sf = uicontrol('Parent', sfLayout,...
		'Style', 'edit',...
		'String', 1);
	S.ed2.sf = uicontrol('Parent', sfLayout,...
		'Style', 'edit',...
		'String', num2str(length(S.data.f1)));
	S.pb.sf = uicontrol('Parent', sfLayout,...
		'Style', 'push',...
		'String', 'Change SFs');
	S.tx.theta = uicontrol('Parent', sfLayout,...
		'Style', 'text',...
		'String', 'theta = ');
	S.ed.theta = uicontrol('Parent', sfLayout,...
		'Style', 'edit',...
		'String', num2str(S.data.theta));
	set(sfLayout, 'Widths', [-1 -1 -2 -1 -1]);

	S = getDefaults(S); % get S.varIn

	for ii = 1:9
			S.varLayout(ii) = uix.HBox('Parent', S.paramLayout,...
				'Spacing', 2, 'Padding', 2); %#ok<AGROW>
			p = sprintf('v%u', ii);
			S.tx.(p) = uicontrol('Parent', S.varLayout(ii),...
				'Style', 'text',...
				'String', '-');
			S.ed1.(p) = uicontrol('Parent', S.varLayout(ii),...
				'Style', 'edit',...
				'String', '');
		if ii <= length(S.params)
			set(S.tx.(p), 'String', S.params{ii});
			set(S.ed1.(p), 'String', num2str(S.varIn(ii)));
		end
		S.ed2.(p) = uicontrol('Parent', S.varLayout(ii),...
			'Style', 'edit',...
			'String', '');
		set(S.varLayout(ii), 'Widths', [-1 -2 -2]);
	end
	set(S.paramLayout, 'Heights', -1*ones(1, 10)); % var + sf


	checkLayout = uix.HBox('Parent', uiLayout,...
		'Spacing', 5, 'Padding', 5);
	S.pb.check = uicontrol('Parent', checkLayout,...
		'Style', 'push',...
		'String', 'Check params');
	errorLayout = uix.VBox('Parent', checkLayout,...
		'Spacing', 5, 'Padding', 5);
	S.tx.err1 = uicontrol('Parent', errorLayout,...
		'Style', 'text',...
		'String', 'ErrorFlag = ');
	S.tx.err2 = uicontrol('Parent', errorLayout,...
		'Style', 'text',...
		'String', 'ResNorm = ');
	set(errorLayout, 'Heights', [-1 -1]);
	set(checkLayout, 'Widths', [-1 -1]);
	graphLayout = uix.HBox('Parent', uiLayout,...
		'Spacing', 5, 'Padding', 5);
	S.tx.graph = uicontrol('Parent', graphLayout,...
		'Style', 'text',...
		'String', 'Graph:');
	S.pb.graphFit = uicontrol('Parent', graphLayout,...
		'Style', 'push',...
		'String', 'Fit');
	S.pb.graph1D = uicontrol('Parent', graphLayout,...
		'Style', 'push',...
		'String', 'RF',...
		'TooltipString', 'Plots in new figure window');
	% S.pb.graph2D = uicontrol('Parent', graphLayout,...
	% 	'Style', 'push',...
	% 	'String', '2D RF',...
	% 	'TooltipString', 'Plots in new figure window');
	S.pb.resNorm = uicontrol('Parent', graphLayout,...
		'Style', 'push',...
		'String', 'Err',...
		'TooltipString', 'Plots in new figure window');
	set(graphLayout, 'Widths', [-1 -1 -1 -1]);
	idkLayout = uix.HBox('Parent', uiLayout,...
		'Spacing', 5, 'Padding', 5);
	S.bg.axType = uibuttongroup('Parent', idkLayout,...
		'Visible', 'off',...
		'Units', 'normalized');
	S.bg.axLin = uicontrol(S.bg.axType, 'Style', 'radiobutton',...
		'String', 'linear',...
		'Units', 'normalized',...
		'Position', [0.05 0.75 0.9 0.2],...
		'HandleVisibility', 'off');
	S.bg.axLog = uicontrol(S.bg.axType, 'Style', 'radiobutton',...
		'String', 'loglog',...
		'Units', 'normalized',...
		'Position', [0.05 0.5 0.9 0.2],...
		'HandleVisibility', 'off');
	S.bg.axSemix = uicontrol(S.bg.axType, 'Style', 'radiobutton',...
		'String', 'semilogX',...
		'Units', 'normalized',...
		'Position', [0.05 0.25 0.9 0.2],...
		'HandleVisibility', 'off');
	S.bg.axSemiy = uicontrol(S.bg.axType, 'Style', 'radiobutton',...
		'String', 'semilogY',...
		'Units', 'normalized',...
		'Position', [0.05 0 0.9 0.2],...
		'HandleVisibility', 'off');
	S.bg.axType.Visible = 'on';
	% resLayout = uix.VBox('Parent', idkLayout,...
	% 	'Padding', 5,'Spacing', 5);
	% S.tx.resnorm = uicontrol('Parent', resLayout,...
	% 	'Style', 'text', 'String', ' ');
	% S.pb.resnorm = uicontrol('Parent', resLayout,...
	% 	'Style', 'push',...
	% 	'String', 'residuals');
	S.pb.print = uicontrol('Parent', idkLayout,...
		'Style', 'push',...
		'String', 'Send output');
	% set(resLayout, 'Heights', [-1 -1]);
	set(idkLayout, 'Widths', [-2 -1]);
	% fcns, paramLayout, checkLayout, graphLayout, idkLayout
	set(uiLayout, 'Heights', [-2 -7 -1.25 -1 -2]);
	set(mainLayout, 'Widths', [-3 -1]);

	% graph the data, init the fit
	S.ln.f1 = line(S.data.sf, S.data.f1,...
		'Parent', S.ax.f1,...
		'Marker', 'o', 'Color', 'k', 'LineWidth', 1);
	S.ln.dogfit = line(S.data.sf, zeros(length(S.data.sf)),...
		'Parent', S.ax.f1,...
		'LineWidth', 1, 'Color', rgb('aqua'));
	if S.flag.matrix
		S.ln.dogfit.Color = [0 0 0];
	% else
		% for ii = 1:length(S.ln.f1)
		% 	S.ln.f1(ii).Color = S.co(ii,:);
		% end
	end
	if S.flag.phasePlot
		S.ln.p1 = line(S.data.sf, S.data.p1,...
		'Parent', S.ax.p1,...
		'Marker', 'Color', 'k','LineWidth', 1);
		if S.flag.matrix
			for ii = 1:length(S.ln.p1)
				S.ln.p1(ii).Color = S.co(ii,:);
			end
		end
	end

	set(S.pb.fcn, 'Callback', {@onSelected_fitFcn, f});
	set(S.pb.resNorm, 'Callback', {@onSelected_plotResiduals, f});
	set(S.pb.graph1D, 'Callback', {@onSelected_graph1D, f});
	% set(S.pb.graph2D, 'Callback', {@onSelected_graph2D, f});
	set(S.pb.graphFit, 'Callback', {@onSelected_graphFit, f});
	set(S.pb.check, 'Callback', {@onSelected_checkParams, f});
	set(S.pb.sf, 'Callback', {@onSelected_changeSF, f});
	set(S.bg.axType, 'SelectionChangedFcn', {@onChanged_axisType, f});
	set(S.pb.adv, 'Callback', {@onSelected_advFit, f});

	setappdata(f.h, 'GUIdata', S);

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%CALLBACKS

	function onSelected_plotResiduals(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		fh2 = figure('Color', 'w');
		ax1 = axes('Parent', fh2);
		res = line(S.data.trueSF, S.res,...
			'Parent', ax1,...
			'Marker', 'o', 'LineWidth', 1, 'Color', rgb('reddish pink'));
	end

	function onSelected_fitFcn(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		switch S.lst.fcn.String{S.lst.fcn.Value}
		case 'normal1'
			S.params = {'Kc', 'Rc', 'Ks', 'Rs', 'BL'};
		case 'normal2'
			S.params = {'Kc', 'Rc', 'Ks', 'Rs', 'BL'};
		case 'normal3'
			S.params = {'Kc', 'Rc', 'Ks', 'Rs', 'Kx', 'Rx', 'BL'};
		case 'ellipse1'
			S.params = {'K', 'L', 'W', 'theta', 'BL'};
		case 'ellipse2'
			S.params = {'Kc', 'Lc', 'Wc', 'thetaC', 'Ks', 'Ls', 'Ws', 'thetaS', 'BL'};
		case 'offset'
			S.params = {'Kc', 'Rc', 'Ks', 'Rs', 'offset'};
		end

		S.lb = zeros(1, length(S.params));
		S.ub = Inf + zeros(1, length(S.params));

		if ~isempty(strfind(S.lst.fcn.String{S.lst.fcn.Value}, 'ellipse'))
			% if isempty(S.data.theta)
			% 	answer = inputdlg('Stimulus orientation?', 'get S.data.theta', 1, {'0'});
			% 	S.data.theta = str2double(answer{1});
			% 	set(S.tx.theta, 'String', sprintf('theta = %u', S.data.theta));
			% end
			S.data.theta = str2double(get(S.ed.theta, 'String'));
		end
		if S.flag.matrix
			S.varInMat = zeros(size(S.data.f1,1), length(S.params));
			S.varOutMat = zeros(size(S.data.f1,1), length(S.params));
		end

		S = getDefaults(S);
		S = updateParamDisplay(S);

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_advFit(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		answer = inputdlg(cellstr([strcat(char(S.params), '_lb'); strcat(char(S.params), '_ub')]),...
			S.lst.fcn.String{S.lst.fcn.Value}, 1, cellstr(num2str([S.lb, S.ub]'))');
		answer = str2double(answer)';
		S.lb = answer(1:length(S.params));
		S.ub = answer(length(S.params)+1:end);

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_checkParams(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		options = optimoptions('lsqcurvefit',...
			'MaxFunEvals', 1500,...
			'Display', 'iter');

		switch S.lst.fcn.String{S.lst.fcn.Value}
		case 'normal1'
			[S.varOut, S.resNorm, S.res, exitFlag, opt] = lsqcurvefit(S.fcn.gfun, S.varIn,...
				S.data.trueSF, S.data.trueF1, S.lb, S.ub, options);
			S.strOut = sprintf('Kc = %.2f, Rc = %.2f, Ks = %.2f, Rs = %.2f, BL = %.2f', S.varOut');
		case 'normal2'
			[S.varOut,S.resNorm S.res, exitFlag, opt] = lsqcurvefit(S.fcn.g2fun, S.varIn,...
				S.data.trueSF, S.data.trueF1, S.lb, S.ub, options);
			S.strOut = sprintf('Kc = %.2f, Rc = %.2f, Ks = %.2f, Rs = %.2f, BL = %.2f',...
				S.varOut');
		case 'normal3'
			[S.varOut,S.resNorm, S.res, exitFlag, opt] = lsqcurvefit(S.fcn.g3fun, S.varIn,...
				S.data.trueSF, S.data.trueF1, zeros(1, length(S.params)), [], options);
			S.strOut = sprintf('Kc = %.2f, Rc= %.2f, Ks = %.2f, Rs = %.2f, Kx = %.2f, Rx = %.2f, BL = %.2f',...
				S.varOut');
		case 'offset'
			[S.varOut,S.resNorm, S.res, exitFlag, opt] = lsqcurvefit(S.fcn.offset, S.varIn,...
				S.data.trueSF, S.data.trueF1, S.lb, S.ub, options);
			S.strOut = sprintf('Kc = %.2f, Rc = %.2f, Ks = %.2f, Rs = %.2f, Offset = %.2f', S.varOut');
		case 'ellipse1'
			theta = S.data.theta
			[S.varOut, ~, ~, exitFlag, opt] = lsqcurvefit(S.fcn.ellipse1, S.varIn,...
				S.data.trueSF, S.data.trueF1, [], [], options);
			S.strOut = sprintf('K = %.2f, LW = %.2fx%.2f, theta = %.2f, BL = %.2f\n', S.varOut');
		case 'ellipse2'
			theta = S.data.theta;
			[S.varOut, ~, ~, exitFlag, opt] = lsqcurvefit(S.fcn.ellipse2, S.varIn,...
				S.data.trueSF, S.data.trueF1, [], [], options);
			S.strOut = sprintf('Kc = %.2f, LWc = %.2fx%.2f, thetaC = %.2f,\n Ks = %.2f, LWs = %.2fx%.2f, thetaS = %.2f,\n BL = %.2f\n',...
				S.varOut');
		end

		fprintf('fcn = %s, resnorm = %.2f\n', S.lst.fcn.String{S.lst.fcn.Value}, S.resNorm);
		fprintf('%s\n', S.strOut);

		for ii = 1:length(S.varOut)
			set(S.ed2.(sprintf('v%u', ii)), 'String', num2str(S.varOut(ii)));
		end

		% set(S.tx.resnorm, 'String', sprintf('%.2f', S.resNorm));
		set(S.tx.err1, 'String', sprintf('ErrorFlag = %s', num2str(exitFlag)));
		set(S.tx.err2, 'String', sprintf('resnorm = %.2f', S.resNorm));
		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_printOutput(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		output.params0 = S.varIn;
		output.params = S.varOut;
		output.residuals = S.res;
		output.resNorm  = S.resNorm;
		if isfield(S, 'dogfit')
			output.fit = S.dogfit;
		else
			output.fit = 'not calculated';
		end

		assignin('base', 'guiout', output);
	end

	function onSelected_changeSF(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		S.data.trueSF = S.data.sf(1,str2double(S.ed1.sf.String) : str2double(S.ed2.sf.String));
		S.data.trueF1 = S.data.f1(:, str2double(S.ed1.sf.String) : str2double(S.ed2.sf.String));
		if S.flag.phasePlot
			S.data.trueP1 = S.data.p1(:, str2double(S.ed1.sf.String) : str2double(S.ed2.sf.String));
		end
		S = updateGraph(S);

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_graphFit(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		switch S.lst.fcn.String{S.lst.fcn.Value}
		case 'normal2'
			S.dogfit = S.fcn.g2fun(S.varOut, S.data.trueSF);
		case 'normal1'
			S.dogfit = S.fcn.gfun(S.varOut, S.data.trueSF);
		case 'offset'
			S.dogfit = S.fcn.offset(S.varOut, S.data.trueSF);
		case 'ellipse1'
			S.dogFit = S.fcn.ellipse1(S.varOut, S.data.trueSF);
		case 'ellipse2'
			S.dogFit = S.fcn.ellipse2(S.varOut, S.data.trueSF);
		end

		set(S.ln.dogfit, 'YData', S.dogfit);
		S.flag.fit = true;

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_graph1D(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		switch S.lst.fcn.String{S.lst.fcn.Value}
		case {'normal1', 'normal2', 'offset'}
			if S.varOut(4) > S.varOut(2) % this should be the case...
				xbound = ceil(S.varOut(4)*2);
			else
				xbound = ceil(S.varOut(2)*2);
			end
			xaxis = -1*xbound:0.001:xbound;
			f2 = figure('Color', 'w', 'Name', 'Gauss RF Plot');
			ax2 = axes('Parent', f2);
			S.ln.c = line(xaxis, S.varOut(1)*normpdf(xaxis, 0, S.varOut(2)),...
				'Parent', ax2,...
				'Color', rgb('light orange'), 'LineWidth', 1);
			S.ln.s = line(xaxis, -1*S.varOut(3)*normpdf(xaxis, 0, S.varOut(4)),...
				'Parent', ax2,...
				'Color', rgb('aqua'), 'LineWidth', 1);
			S.ln.cs = line(xaxis, S.ln.c.YData + S.ln.s.YData,...
				'Parent', ax2,...
				'Color', 'k', 'LineWidth', 1.5);
			% title(ax2, sprintf('DoG RF - K_c = %.2f, R_c = %.2f, K_s = %.2f, R_s = %.2f',...
				% S.varOut(1), S.varOut(2), S.varOut(3), S.varOut(4)));
			title(S.strOut);
			legend(ax2, {'center', 'surround', 'Dog RF'});
		case {'ellipse1', 'ellipse2'}
			
		end 

		setappdata(f.h, 'GUIdata', S);
	end

	function onSelected_graph2D(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		if S.varOut(4) > S.varOut(2)
			xbound = ceil(S.varOut(4)*2);
		else
			xbound = ceil(S.varOut(2)*2);
		end
		[x, y] = meshgrid(-1*xbound:0.001:xbound);
		[theta, r] = cart2pol(x, y);

		c = fspecial('gaussian', [x y], S.varOut(2));

		f2 = figure('Color', 'w', 'Name', 'Gauss 2D RF Plot');
		ax2 = axes('Parent', f2);


		setappdata(f.h, 'GUIdata', S);
	end

	function onChanged_axisType(varargin)
		f = varargin{3};
		S = getappdata(f.h, 'GUIdata');

		switch S.bg.axType.SelectedObject.String
		case 'linear'
			set(S.ax.f1, 'XScale', 'linear', 'YScale', 'linear', 'YLimMode', 'auto');
		case 'loglog'
			set(S.ax.f1, 'XScale', 'log', 'YScale', 'log', 'YLim', [10e-1 max(S.data.trueSF)]);
		case 'semilogX'
			set(S.ax.f1, 'XScale', 'log', 'YScale', 'linear', 'YLimMode', 'auto');
		case 'semilogY'
			set(S.ax.f1, 'XScale', 'linear', 'YScale', 'log', 'YLim', [10e-1 max(S.data.trueSF)]);
		end

		if S.flag.phasePlot
			switch S.bg.axType.SelectedObject.String
			case {'linear', 'semilogY'}
				set(S.ax.p1, 'XScale', 'linear');
			case {'log', 'semilogX'}
				set(S.ax.p1, 'YScale', 'log');
			end
		end

		set(S.ax.f1, 'XScale', 'log');
		setappdata(f.h, 'GUIdata', S);
	end

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%%FCNS

	function S = getDefaults(S)
		[pk, x0] = max(S.data.trueF1, [], 2);
		x0 = S.data.sf(x0); x0 = x0';
		mn = min(S.data.trueF1, [], 2);
		switch S.lst.fcn.String{S.lst.fcn.Value}
			case {'normal2', 'normal1'}
				S.varIn = [pk-mn, x0, (pk-mn)/2, x0*2, mn];
			case 'ellipse2'
				S.varIn = [pk-mn, x0, x0*0.75, 0, (pk-mn)/2, x0/2, x0*1.5, 0, mn]
			case 'ellipse1'
				S.varIn = [pk-mn, x0, x0*0.75, 0, mn];
			case 'offset'
				S.varIn = [pk - mn, x0/2, (pk-mn)/2, x0, 0];
				S.lb(5) = -Inf;
		end

	end

	function S = updateGraph(S)
		set(S.ln.f1, 'XData', S.data.trueSF, 'YData', S.data.trueF1);
		if S.flag.phasePlot
			set(S.ln.p1, 'XData', S.data.trueSF, 'YData', S.data.trueP1);
		end
		if S.flag.fit
			S.dogfit = S.fcn.g2fun(S.varOut, S.data.trueSF);
			set(S.ln.dogfit, 'XData', S.data.trueSF, 'YData', S.dogfit);
		else
			set(S.ln.dogfit, 'XData', S.data.trueSF, 'YData', zeros(size(S.data.trueSF)));
		end
	end

	function S = updateParamDisplay(S)
		for ii = 1:9
			p = sprintf('v%u', ii);
			if ii <= length(S.params)
				set(S.tx.(p), 'String', S.params{ii}, 'Visible', 'on');
				set(S.ed1.(p), 'String', num2str(S.varIn(ii)), 'Visible', 'on');
			else
				set(S.tx.(p), 'Visible', 'off');
				set(S.ed1.(p), 'Visible', 'off');
				set(S.ed2.(p), 'Visible', 'off');
			end
		end
		set(S.paramLayout, 'Heights', -1*ones(1, 10));

	end

	function y = DoOG(x, offset, centerC, surroundC, centerSD, surroundSD)
  		% difference of cumulative gaussians for center and surround
  		y = offset + centerC*(1-exp(-(x/2).^2 ./ (2*centerSD.^2)))...
    		-surroundC*(1-exp(-(x/2).^2 ./ (2*surroundSD^2)));
  end

	function S = DoG1D(v, x)
		% x = 1./x
		Kc = v(1); Rc = v(2);
		Ks = v(3); Rs = v(4);
		BL = v(5);

		dx = 0.0001;
		y = zeros(size(x));
		for k = 1 : length(x)
    		y(k) = BL+(Kc*sum(exp(-(2*(0:dx:x(k))/Rc).^2))...
    			- Ks*sum(exp(-(2*(0:dx:x(k))/Rs).^2)))*dx;
		end
		S.varOut = [Kc Rc Ks Rs BL];
	end % DoG1D
end % dogGUI
