function plotDog(params)
	% plot dog receptive field
	% Kc, sigmaC, Ks, sigmaS

	if isstruct(params) % from r
		tmp = params;
		params = [tmp.Kc tmp.sigmaC tmp.Ks tmp.sigmaS];
	end

	figure('Color', 'w'); hold on;
	co = pmkmp(10, 'CubicL');

	if params(2) > params(4) % this should be the case...
		xbound = ceil(params(2)*3);
	else
		xbound = ceil(params(4)*3);
	end
	xaxis = -1*xbound:0.001:xbound;

	plot(xaxis, params(1)*normpdf(xaxis, 0, params(2)),...
		'Color', rgb('light orange'), 'LineWidth', 1);
	plot(xaxis, -1*params(3)*normpdf(xaxis, 0, params(4)),...
		'Color', rgb('aqua'), 'LineWidth', 1);
	plot(xaxis, (params(1) * normpdf(xaxis,0,params(2)))... 
		- (params(3)*normpdf(xaxis,0,params(4))),...
		'Color', 'k', 'LineWidth', 1.5);
	title(sprintf('DoG RF - K_c = %.2f, R_c = %.2f, K_s = %.2f, R_s = %.2f', params));
	legend({'center', 'surround', 'Dog RF'});
	set(legend, 'EdgeColor', 'w', 'FontSize', 10);
