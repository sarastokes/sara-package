function blankGaussFig
	% make a blank linear fitler + nonlinearity figure

	figure;
	subplot(121); hold on;
	xlabel('msec');
	ylabel('linear filter units');

	subplot(122); hold on;
	axis tight; axis square;
	xlabel('generator');

	set(findobj(gcf, 'Type', 'axes'), 'TickDir', 'out', 'Box', 'off');

	set(gcf, 'DefaultLegendFontSize', 10,...
		'DefaultLegendEdgeColor', 'w',...
		'Color', 'w',...
		'DefaultAxesLineWidth', 1);
