classdef SpikeDetectionFigure < symphonyui.core.FigureHandler

properties
  device
end


properties (Access = private)
  axesHandle
end

methods
  function obj = SpikeDetectionFigure(device)
    obj.device = device;

    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;
    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

    obj.axesHandle(1) = subplot(5,1,1:2,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
    obj.axesHandle(2) = subplot(5, 1, 3,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
    obj.axesHandle(3) = subplot(5,1,4:5,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
    set (obj.figureHandle, 'color','w');
  end

  function handleEpoch(obj, epoch)
    response = epoch.getResponse(obj.device);
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    response = wavefilter(responseTrace(:)', 6);
    S = spikeDetectorOnline(response);
    spikes = zeros(size(response));
    spikes(S.sp) = 1;
    spikeAmps = S.spikeAmps;
    spikeTimes = S.sp;

    plot(response, 'parent', obj.axesHandle(1));
    set(obj.axesHandle(1), 'XColor', 'w','XTick', {}, 'box', 'off',... 
        'YLim', [0 ceil(max(response))], 'XLim', [0 length(response)]);
    ylabel(obj.axesHandle(1), 'response (nA)');

    plot(spikes, 'parent', obj.axesHandle(2));
    set(obj.axesHandle(2), 'XColor', 'w', 'XTick', {}, 'Box', 'off',... 
        'YLim', [0 1], 'XLim', [0 length(response)]);
    ylabel(obj.axesHandle(2), 'spikes');

    if ~isempty(find(spikes,1))
      plot(spikeTimes, spikeAmps, 'parent', obj.axesHandle(3));
      set(obj.axesHandle(3), 'XColor', 'w', 'XTick', {}, 'Box', 'off',... 
        'YGrid', 'on', 'YMinorGrid', 'on', 'xlim', [0 length(response)],...
        'ylim', [0 ceil(max(spikeAmps))]);
      ylabel(obj.axesHandle(3), 'spike amplitudes');
    else
      xlabel(obj.axesHandle(3), 'no spikes detected');
    end
  end
end
end
