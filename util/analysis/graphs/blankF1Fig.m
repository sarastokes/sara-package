function [S, fh] = blankF1Fig(roomForLegend)
	% make blank F1 amplitude and phase figure
	%
	% OPTIONAL INPUT: 		roomForLegend (false)
	% OPTIONAL OUTPUT:
	%			S				structure with figure and axes handles
	%			fh 			figure handle

	if nargin < 1
		roomForLegend = 0;
	else
		roomForLegend = 1;
	end

	fh = figure();
	set(gcf, 'DefaultFigureColor', 'w',...
		'DefaultAxesFontName', 'Roboto',...
		'DefaultAxesTitleFontWeight', 'normal',...
		'DefaultLegendFontSize', 10,...
		'DefaultLegendEdgeColor', 'w');

	S.F1 = subplot(3,1,1:2); hold on;
	set(gca, 'Box', 'off', 'TickDir', 'out', 'XTickLabel', {});
	ylabel('f1 amplitude');
	if roomForLegend == 1
		S.P1 = subplot(6,1,5);
	else
		S.P1 = subplot(313); hold on;
	end
	set(S.P1, 'Box', 'off', 'TickDir', 'out');
	ylabel('f1 phase');
	set(S.P1, 'YLim', [-180 180], 'YTick', -180:90:180);

	S.fh = fh;
