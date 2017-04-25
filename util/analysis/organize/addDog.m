function r = addDog(r, fh)
	% save output of dogGUI to data structure
	% INPUT:  r		data structure
	%		  fh	dogGUI figure handle
	% OUTPUT: r		data structure
	
	S = getappdata(fh, 'GUIdata');
	
	if isfield(r, 'stats')
		if isfield(r, 'fit')
			selection = questdlg('overwrite existing fit?',... 
			'old fit exists',...
			'Yes', 'No', 'Yes');
			switch selection
			case 'Yes'
				fprintf('overwrote existing fit\n');
				if ~isfield(r.stats.fit, 'old')
					r.stats.fit.old = [];
				end
				r.stats.fit.old = cat(1, r.stats.fit.old, r.stats.fit.strOut);
			case 'No'
				return;
			end
		end
	end
	
	r.stats.fit.strOut = S.strOut;
	r.stats.fit.resNorm = S.resNorm;
	r.stats.fit.dogfit = S.dogfit;
	r.stats.fit.res = S.res;
	r.stats.fit.params = S.varOut;
	r.stats.fit.fcn = S.lst.fcn.String{S.lst.fcn.Value};
	
	