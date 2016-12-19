function r = getOrientations(r)
	% r should be the level above the avg and individual traces

	f = fieldnames(r);
	if isempty(strfind(f, 'avg'))
		error('no average field found');
	end
	if ~isfield(r.avg, 'orientations')
		r.avg.orientations = zeros(1, length(f)-1);
	else
		warndlg('will overwrite existing orientations field');
		r.avg.orientations = [];
	end
	avgFlag = 0;
	for ii = 1:length(f)
		if ~strcmp(f{ii}, 'avg')
			f1 = r.(f{ii}).analysis.F1;
			for jj = 1:size(r.avg.F1, 1)
				if r.avg.F1(jj,:) == f1
					r.avg.orientations(ii-avgFlag) = str2double(f{ii}(4:end));
				end
			end
		else % so index doesn't increment for avg
			avgFlag = 1;
		end
	end
