function rplot(responses, varargin)
	% response plot

	ip = inputParser();
	ip.addParameter('xpts', (1:length(responses))*10e-3, @(x)isvector(x));
	ip.addParameter('label', [], @(x)iscellstr(x));
	ip.addParameter('co', [], @(x)ismatrix(x) || @(x)ischar(x));
	ip.addParameter('title', [], @(x)ischar(x));
	ip.addParameter('link', false, @(x)islogical(x));
	ip.parse(varargin{:});
	xpts = ip.Results.xpts;
	label = ip.Results.label;
	co = ip.Results.co;
	t = ip.Results.title;
	link = ip.Results.link;

	if isempty(co)
		co = repmat([0 0.447 0.741], [size(responses, 1) 1]);
	elseif isinteger(co)
		co = pmkmp(co, 'CubicL');
	elseif strcmp(co, 'k')
		co = zeros(size(responses,1), 3);
	elseif size(co,1) < size(responses,1)
		error('color order matrix rows less than response rows');
	end

	if isempty(label)
		l = 0.05;
	else
		l = 0.1;
	end

	figure('Color', 'w');
	for ii = 1:size(responses,1)
		subtightplot(size(responses,1), 1, ii, 0.01, [0.075 0.075], [l 0.025]);
		plot(xpts, responses(ii,:), 'Color', co(ii,:));
		set(gca,'Box', 'off', 'TickDir', 'out');
		if ~isempty(label)
			ylabel(label{ii}); set(ylabel, 'Orientation', 'horizontal');
		end
		if ii == 1 && ~isempty(t)
			title(t);
		end
		axis tight;
		if link
			ylim([min(min(responses)) max(max(responses))]);
		end
		if ii == size(responses,1)
			xlabel('time (msec)');
		else
			set(gca, 'XColor', 'w', 'XTick', [], 'YColor', 'w', 'YTick', []);
		end
	end

