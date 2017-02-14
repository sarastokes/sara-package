function [S,fh,r] = F1amp2LMS(r, varargin)
	% put LMS f1 amplitude and phase into DKL-like figure
	% INPUTS: 	r = data structure
	% OPTIONAL:
	%		plotNum 	(1)		1 = full figure, 2 = triangle
	%		lngd	(false)		show legend
	%		fh 		(new)			existing figure handle
	% 	ft (1)					f1 or f2
	%		ptEnd (false)		inclue LMS end points
	% 	lag (15)				delay lag in degrees
	%
	% 22Jan2017

	r = analyzeOnline(r);


	ip = inputParser();
	ip.addParameter('plotNum', 1, @(x)isvector(x));
	ip.addParameter('lngd', false, @(x)islogical(x));
	ip.addParameter('fh', [], @(x)ishandle(x));
	ip.addParameter('ft', 1, @(x)isvector(x));
	ip.addParameter('ptEnd', false, @(x)islogical(x));
	ip.addParameter('lag', 15, @(x)isvector(x));
	ip.parse(varargin{:});
	plotNum = ip.Results.plotNum;
	fh = ip.Results.fh;
	showLegend = ip.Results.lngd;
	ft = ip.Results.ft;
	ptEnd = ip.Results.ptEnd;
	lag = ip.Results.lag;


	switch r.params.stimClass
	case 'alms'
		ind = [2 3 4];
	otherwise
		ind = [1 2 3];
	end

	F1 = zeros(3,1);
	P1 = zeros(3,1);
	P1sign = zeros(3,1);

	% if ft == 1
		res = {'F1', 'P1'};
		d = 'o';
	% else
	% 	res = {'F2','P2'};
	% 	d = 's';
	% end

	for ii = 1:3
			F1(ii) = mean(r.analysis.F1(ind(ii), :),2);
			P1(ii) = mean(r.analysis.P1(ind(ii),:),2);
			switch r.params.recordingType
			case 'voltage_clamp'
				if P1(ii) <=-90-lag
					P1sign(ii) = 1;
				elseif P1(ii) >= (0+lag) && P1(ii) <= (90+lag)
					P1sign(ii) = 1;
				else
					P1sign(ii) = -1;
				end
			case 'extracellular'
				P1sign(ii) = -1*sign(P1(ii));
			end
	end

	% get the % of total cone weight
	F1 = F1./sum(abs(F1));

	if plotNum ~= 0
		if isempty(fh)
			dkl = blankLMSFig(plotNum, ptEnd);
			fh = dkl.fh; ax = dkl.ax; hold on;
			data.n = {r.cellName};
			data.F1 = []; data.P1 = []; data.P1sign = [];
			set(fh, 'UserData', data);
		else
			gcf = fh; ax = gca;
			data = get(fh, 'UserData');
			data.n{end+1} = r.cellName;
			set(fh, 'UserData', data);
		end
		if plotNum == 1
			plot3(ax, P1sign(1)*F1(1), P1sign(2)*F1(2), P1sign(3)*F1(3), sprintf('%sk', d), 'MarkerFaceColor', 'w');
		elseif plotNum == 2
			tmp = plot3(ax, F1(1), F1(2), F1(3), sprintf('%sk',d), 'MarkerFaceColor', 'w');
		end
		if P1sign(3) == -1
			set(tmp, 'MarkerFaceColor', 'k');
		end
		if showLegend
			legend(data.n);
			set(legend, 'EdgeColor', 'w', 'FontSize', 8);
		end
	end

	% if ft == 1
		S.F1 = F1; S.P1 = P1; S.P1sign = P1sign;
		data.F1 = [data.F1, F1];
		data.P1 = [data.P1, P1];
		data.P1sign = [data.P1sign P1sign];
		set(fh, 'UserData', data);
	% else
	% 	S.F2 = F1; S.P2 = P1; S.P2sign = P1sign;
	% end
