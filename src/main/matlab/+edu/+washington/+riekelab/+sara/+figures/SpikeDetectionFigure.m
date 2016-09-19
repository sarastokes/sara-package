classdef spikeDetectionFigure < symphonyui.core.figureHandler

properties
  device
end


properties
  axesHandle
end

methods
  function obj = spikeDetectionFigure(device, varargin)
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
  end

  function handleEpoch(obj, epoch)
    response = epoch.getResponse(obj.device);
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    response = wavefilter(response(:)', 6);
    S = spikeDetectorOnline(response);
    spikes = zeros(size(response));
    spikes(S.sp) = 1;
    spikeAmps = S.spikeAmps;
    spikeTimes = S.sp;

    plot(response, 'parent', obj.axesHandle(1));
    set(obj.axesHandle(1), 'XColor', 'w','XTick', {}, 'box', 'off', 'YLim', [0 length(response)], 'XLim', [floor(response) ceil(response)]);

    plot(spikes, 'parent'  axesHandle(2));
    set(obj.axesHandle(2), 'XColor', 'w', 'XTick', {}, 'Box', 'off', 'YLim', [0 1], 'XLim', [0 length(response)]);

    plot(obj.axesHandle(3), spikeAmps);
    set(obj.axesHandle(3), 'XColor', 'w', 'XTick', {}, 'Box', 'off', 'YGrid', 'on', 'YMinorGrid', 'on', 'ylim', [0 ceil(max(spikeAmps))], 'xlim', [0 length(response)]);
  end
