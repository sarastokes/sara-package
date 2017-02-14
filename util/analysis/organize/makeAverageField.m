function r = makeAverageField(r, analysis, params)
	% r is level above avg and individual blocks
	% input fieldnames divided by parent field: analysis.x, params.x
	% r = getAverages(c9.dGrate.siso, {'f1amp', 'f1phase'}, {'contrast', 'orientations'})

	% all the blocks and avg
	f = fieldnames(r);
	if isempty(strfind(f, 'avg'))
		r.avg = struct;
	end

	% make sure the fields exist
	for ii = 1:length(analysis)
		if ~isfield(r.(f{1}).analysis, analysis{ii})
			error(sprintf('%s.analysis.%s does not exist', f{1}, analysis{ii}));
		end
	end
	for ii = 1:length(params)
		if ~isfield(r.(f{1}).params, params{ii})
			error(sprintf('%s.params.%s does not exist', f{1}, params{ii}));
		end
	end

	% all fields
	rf = [analysis params];

	% clear existing average data and/or create the fields
	for ii = 1:length(rf)
		r.avg.(rf{ii}) = 1;
	end

	avgFlag = 0;
	for ii = 1:length(f)
		if ~strcmp(f{ii}, 'avg')
			ind = ii-avgFlag;
			for jj = 1:length(analysis)
				r.avg.(analysis{jj}) = [avg.(analysis{jj}) r.(f{ii}).analysis.(analysis{jj})];
			end
			for jj = 1:length(params)
				r.avg.(params{jj}) = [avg.(params{jj}) r.(f{ii}).params.(params{jj})];
			end
		else
			avgFlag = 1;
		end
	end
