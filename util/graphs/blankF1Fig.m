function blankF1Fig(roomForLegend)

	if nargin < 1
		roomForLegend = 0;
	else
		roomForLegend = 1;
	end

	figure();
	set(gcf, 'DefaultFigureColor', 'w',... 
		'DefaultAxesFontName', 'Roboto',...
		'DefaultAxesTitleFontWeight', 'normal',...
		'DefaultLegendFontSize', 10,...
		'DefaultLegendEdgeColor', 'w');

	subplot(3,1,1:2); hold on;
	set(gca, 'Box', 'off', 'TickDir', 'out', 'XTickLabel', {});
	ylabel('f1 amplitude');
	if roomForLegend == 1
		subplot(6,1,5);
	else
		subplot(313); hold on;
	end
	set(gca, 'Box', 'off', 'TickDir', 'out');
	ylabel('f1 phase');
	set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
