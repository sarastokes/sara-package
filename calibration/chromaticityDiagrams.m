load('locus.mat');
%% LED Spectra
load('xySpectra_26Jun2017');

figure('Name', 'CIE LEDs'); hold on;
%%
whichLEDs = [1 3 4; 1 2 4];
cones = 'lmsp';

for ii = 1:2
    figure('Name', 'LED CIE'); hold on;
    plot(locus(:,1), locus(:,2),... 
	'k', 'LineWidth', 2);

    for jj = 1:length(whichLEDs)
        led = whichLEDs(ii,jj);
        plot(xySpectra(1,led), xySpectra(2,led), 'o',...
            'MarkerFaceColor', getPlotColor(cones(led)),...
            'MarkerEdgeColor', getPlotColor(cones(led)));
    end
    plot([xySpectra(1,whichLEDs(ii,:)) xySpectra(1,1)],... 
        [xySpectra(2,whichLEDs(ii,:)) xySpectra(2,1)],...
        'Color', [0.4 0.4 0.4], 'LineWidth', 1.5);
    plot([locus(1,1) locus(end,1)], [locus(1,2) locus(end,2)],...
        'k', 'LineWidth', 2);
end


%% Tritan lines
% get copunctuals from Wyszecki & Stiles data
tritan = getConstant('tritan');

ind = round(linspace(0, size(locus,1)-1, 20) + 1);

figure('Name', 'CIE tritan'); hold on;
plot(locus(:,1), locus(:,2),... 
	'k', 'LineWidth', 2);
plot([locus(1,1) locus(end,1)], [locus(1,2) locus(end,2)],...
	'k', 'LineWidth', 2);

for ii = 1:length(ind)-1
	plot([deutan(1) locus(ind(ii), 1)], [deutan(2) locus(ind(ii), 2)],... 
		'Color', getPlotColor('m'));
end

x=[];y=[];
for ii = 1:length(ind)-1
    x = [x; tritan(1); locus(ind(ii), 1)];
    y = [y; tritan(2); locus(ind(ii),2)];
end

deutan = getConstant('deutan');

ind = round(linspace(0, size(locus,1)-1, 20) + 1);
ind = [1 26 35 50 70 80 100 125 149 174 199 224];
figure('Name', 'CIE deutan'); hold on;
plot(locus(:,1), locus(:,2),... 
	'k', 'LineWidth', 2);
plot([locus(1,1) locus(end,1)], [locus(1,2) locus(end,2)],...
	'k', 'LineWidth', 2);

for ii = 1:length(ind)-1
	plot([deutan(1) locus(ind(ii), 1)], [deutan(2) locus(ind(ii), 2)],... 
		'Color', getPlotColor('m'));
end

x=[];y=[];
for ii = 1:length(ind)-1
    x = [x; deutan(1); locus(ind(ii), 1)];
    y = [y; deutan(2); locus(ind(ii),2)];
end