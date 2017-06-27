load('locus.mat');
% get copunctuals from Wyszecki & Stiles data
tritan = getConstant('tritan');

ind = round(linspace(0, size(locus,1)-1, 20) + 1);

figure('Name', 'CIE tritan'); hold on;
plot(locus(:,1), locus(:,2),... 
	'k', 'LineWidth', 2);
plot([locus(1,1) locus(end,1)], [locus(1,2) locus(end,2)],...
	'k', 'LineWidth', 2);

for ii = 1:length(ind)-1
	plot([tritan(1) locus(ind(ii), 1)], [tritan(2) locus(ind(ii), 2)],... 
		'Color', getPlotColor('s'));
end