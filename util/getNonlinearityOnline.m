function [linearPrediction, measured, ben] = getNonlinearityOnline(response, stimuli, linearFilter)
	% [linearPrediction, measured, ben] = getNonlinearityOnline(response, stimuli, linearFilter)
	% 
	% Adapted from Max's LinearFilterFigure. 
	% Moved out to a separate function mostly for calls from ConeKineticsFigure
	% 
	% 12Jun2017 - SSP - created

	measuredResponse = reshape(response', 1, numel(response));
	stimulusArray = reshape(stimuli', 1, numel(obj.stimuli));
	linearPrediction = conv(stimulusArray, linearFilter);
	linearPrediction = linearPrediction(1:length(stimulusArray));
	[~, edges, bin] = histcounts(linearPrediction, 'BinMethod', 'auto');
	binCtrs = edges(1:end-1) + diff(edges);

	binResp = zeros(size(binCtrs));
	for bb = 1:length(binCtrs)
		binResp(bb) = mean(measuredResponse(bin == bb));
	end
	ben.resp = binResp;
	ben.centers = binCtrs;

	% to plot:
	% plot(binCtrs, binResp, 'linestyle', 'none', 'marker', 'o');
    % limDown = min([linearPrediction measuredResponse]);
    % limUp = max([linearPrediction measuredResponse]);
    % htx = line([limDown limUp],[0 0],...
    %     'Parent', obj.axesHandle(2),'Color','k',...
    %     'Marker','none','LineStyle','--');
    % hty = line([0 0],[limDown limUp],...
    %     'Parent', obj.axesHandle(2),'Color','k',...
    %     'Marker','none','LineStyle','--');