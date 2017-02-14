function r = changeObj(r, objMag)
	% change from 10 to 60x

	if objMag == 60
		r.params.objectiveMag = 60;
		r.params.micronsPerPixel = 0.1333;
	elseif objMag == 10
		r.params.objectiveMag = 10;
		r.params.micronsPerPixel = 0.8;
	elseif objMag == r.params.objectiveMag
		error('objective mag already set to input');
	else
		error('objective must be 10 or 60');
	end

	fn = fieldnames(r.params);
	ind = find(not(cellfun('isempty', strfind(fn, 'Micron'))));
	for ii = 1:length(ind)	
		str = fn{ind(ii)};	
		pix = fn{ind(ii)}(1:strfind(fn{ind(ii)}, 'Microns')-1);
		new = r.params.(pix) .* r.params.micronsPerPixel;
		r.params.(fn{ind(ii)}) = new;
	end

	r.log{end+1} = sprintf('Corrected objectiveMag to %u and %u parameters',... 
		objMag, size(ind));

