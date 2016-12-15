function blankF1Fig

	figure();
	subplot(3,1,1:2); hold on;
	set(gca, 'Box', 'off', 'TickDir', 'out', 'XTickLabel', {});
	ylabel('f1 amplitude');
	set(gcf, 'DefaultLegendFontSize', 10);
	set(gcf, 'DefaultLegendEdgeColor', 'w');

	subplot(313); hold on;
	set(gca, 'Box', 'off', 'TickDir', 'out');
	ylabel('f1 phase');
	set(gca, 'YLim', [-180 180], 'YTick', -180:90:180);
