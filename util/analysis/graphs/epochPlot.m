function epochPlot(resp, stimTrace)
	% plot a single epoch's raw response with stim trace


	if nargin < 2
		subplot(4,1,1:3); hold on;
	end
	plot((1:length(resp))/10e3,resp, )