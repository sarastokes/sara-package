function S = rectSTA(sta)
sta = sta/max(abs(sta));
sta = (sta + 1)/2;

S = figure;
for ii = 1:length(sta)
	rectangle('Position', [(ii-1) 0 1 1], 'FaceColor', sta(ii)+zeros(1,3), 'EdgeColor', sta(ii)+zeros(1,3));
end
set(gca, 'Box', 'off', 'YColor', 'w', 'YTickLabel', []);