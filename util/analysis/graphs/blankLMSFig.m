function S = blankLMSFig(plotType, ptEnd)
	% creates blank DKL like figure and returns structure with figure, axis handle
	% OPTIONAL: plotType
	%							1	full figure to include phase (default)
	%							2	single triangle figure for just amplitude
	%						endPts - color points
	%
	% 22Jan2017

	if nargin < 1
		plotType = 1;
	elseif plotType ~= 1 && plotType ~=2
		error('Set plotType = 1 for full DKL, 2 for triangle DKL');
	end
	if nargin < 2
		ptEnd = false;
	end

	if ptEnd
		co = [rgb('light red'); rgb('greenish')];
	else
		co = 0.5+ zeros(2,3);
	end

	S.fh = figure('Color', 'w',...
	'DefaultAxesFontName', 'Roboto',...
	'PaperPositionMode', 'auto');
	S.ax = axes('Parent', S.fh); hold on;
    S.fh.Position(4) = S.fh.Position(4)-100;
	S.fh.Position(3) = S.fh.Position(4);

	if ptEnd
		plot3(1,0,0, 'o', 'MarkerFaceColor', getPlotColor('l'), 'MarkerEdgeColor', getPlotColor('l'));
		plot3(0,1,0, 'o', 'MarkerFaceColor', getPlotColor('m'), 'MarkerEdgeColor', getPlotColor('m'));
		plot3(0,0,1, 'o', 'MarkerFaceColor', getPlotColor('s'), 'MarkerEdgeColor', getPlotColor('s'));
	end
	xlabel('L-cone'); ylabel('M-cone'); zlabel('S-cone');

	if plotType == 1
		if ptEnd
			plot3(-1,0,0, 'o', 'MarkerFaceColor', getPlotColor('l'), 'MarkerEdgeColor', getPlotColor('l'));
			plot3(0,-1,0, 'o', 'MarkerFaceColor', getPlotColor('m'), 'MarkerEdgeColor', getPlotColor('m'));
			plot3(0,0,-1, 'o', 'MarkerFaceColor', getPlotColor('s'), 'MarkerEdgeColor', getPlotColor('s'));
		end

		plot3([-1 0 1 0 -1], [0 0 0 0 0], [0 -1 0 1 0], '--', 'Color', [0.5 0.5 0.5]);
		plot3([-1 0 1 0 -1], [0 -1 0 1 0], [0 0 0 0 0], '--', 'Color', [0.5 0.5 0.5]);
		plot3([0 0 0 0 0], [-1 0 1 0 -1], [0 -1 0 1 0], '--', 'Color', [0.5 0.5 0.5]);

		%if ptEnd
			plot3([-1 1], [0 0], [0 0], 'Color', co(1,:), 'LineWidth', 1.5);
			plot3([0 0], [-1 1], [0 0], 'Color', co(2,:), 'LineWidth', 1.5);
		%end
		xlim([-1 1]); ylim([-1 1]); zlim([-1 1]);
	else
		if ptEnd
			plot3([0 1], [0 0], [0 0], 'Color', co(1,:), 'LineWidth', 1.5);
			plot3([0 0], [0 1], [0 0], 'Color', co(2,:), 'LineWidth', 1.5);
		end
		plot3([1 0], [0 1], [0 0], '--', 'Color', [0.5 0.5 0.5]);
		xlim([0 1]); ylim([0 1]); zlim([0 1]);
	end
	axis equal;
    if ptEnd
        axis off;
    end
