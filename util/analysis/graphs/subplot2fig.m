function subplot2fig(axHandle)
	% bc i always forget how to do this.. plot subplot in it's own figure

	hh = copyobj(axHandle, figure);
	set(hh, 'Position', get(0, 'DefaultAxesPosition'));
