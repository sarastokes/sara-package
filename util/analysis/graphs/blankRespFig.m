function S = blankRespFig(recordingType, stimType)
	% regular response with stim figure
	% INPUT: recordingType: (ec, vc, ic) default extracellular
    
    if nargin < 2
        stimType = 'contrast';
    end
	if nargin < 1
		recordingType = 'extracellular';
	end

	S.fh = figure();
	set(S.fh, 'DefaultFigureColor', 'w',... 
		'DefaultAxesFontName', 'Roboto',...
		'DefaultAxesTitleFontWeight', 'normal',...
		'DefaultLegendFontSize', 10,...
		'DefaultLegendEdgeColor', 'w',...
        'DefaultAxesTickDir', 'out',...
        'DefaultAxesBox', 'off');
	

	S.resp = subtightplot(10,1,1:7, 0.05, [0.05 0.08], [0.1 0.05], 'Parent', S.fh); 
    hold on;
    xlabel(S.resp, 'time (ms)');
	switch recordingType
      case {'extracellular', 'ec'}
		ylabel(S.resp, 'amplitude (mV)');
      case {'voltage_clamp', 'vc'}
		ylabel(S.resp, 'current (pA)');
      case 'ptsh'
        ylabel(S.resp, 'spikes count');
    end

    S.stim = subtightplot(5,1,5, 0.05, [0.05 0.09], [0.1 0.05], 'Parent', S.fh); 
    hold on;
    set(S.stim, 'XColor', 'w', 'XTickLabel', {}, 'XTick', []);
    if strcmp(stimType, 'contrast')
        ylabel(S.stim, 'contrast');
        set(S.stim, 'YLim', [0 1]);
    end
