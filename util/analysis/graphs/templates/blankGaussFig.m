function S = blankGaussFig
	% make a blank linear fitler + nonlinearity figure

	S.fh = figure;
	S.lf = subplot(1,3,1:2); hold on;
	xlabel(S.lf, 'msec');
	% ylabel('linear filter units');

	S.nl = subplot(1, 3, 3); hold on;
	axis tight; axis square;
	xlabel(S.nl, 'generator');

	set(findobj(gcf, 'Type', 'axes'),...
	'TickDir', 'out', 'Box', 'off');

	set(gcf, 'DefaultLegendFontSize', 10,...
		'DefaultLegendEdgeColor', 'w',...
		'Color', 'w',...
		'DefaultAxesLineWidth', 1);
