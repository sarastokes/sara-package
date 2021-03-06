classdef ConeFiringRateFigure < symphonyui.core.FigureHandler

properties
  device
  stimClass
  stimTrace
  onlineAnalysis
end

properties (Access = private)
  axesHandle
  traceHandle
  plotStim
  epochSort
  epochCap
  epochColors
  epochNames
  sweepOne
  sweepTwo
  sweepThree
  sweepFour
end

methods
  function obj = ConeFiringRateFigure(device, stimClass, varargin)
    obj.device = device;
    obj.stimClass = stimClass;
    obj.epochSort = 0;

    ip = inputParser();
    ip.addParameter('stimTrace', [], @(x)isvector(x));
    ip.addParameter('onlineAnalysis', 'extracellular', @(x)ischar(x));
    ip.parse(varargin{:});
    obj.stimTrace = ip.Results.stimTrace;
    obj.onlineAnalysis = ip.Results.onlineAnalysis;

    obj.epochCap = length(obj.stimClass);

    if isempty(obj.stimTrace)
      obj.plotStim = false;
    else
      obj.plotStim = true;
    end

  obj.epochColors = zeros(length(obj.stimClass), 3);
  for ii = 1:length(obj.stimClass)
    colorCall = obj.stimClass(ii);
    [obj.epochColors(ii,:), obj.epochNames{ii}] = getPlotColor(colorCall);
  end
    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;
    % toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

    if isempty(obj.epochColors)
      obj.epochColors = zeros(obj.epochCap, 3);
    end

    if obj.plotStim
      m = 2 * obj.epochCap + 1;
    else
      m = 2 * obj.epochCap; %n = 1:obj.epochCap;
    end

    % create axes
    obj.axesHandle(1) = subplot(m, 1, 1:2,...
      'Parent', obj.figureHandle,...
      'FontName', 'Roboto',...
      'FontSize',9,...
      'XTickMode', 'auto');
    obj.axesHandle(2) = subplot(m, 1, 3:4,...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize',9,...
        'XTickMode', 'auto');
    obj.axesHandle(3) = subplot(m, 1, 5:6,...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize',9,...
        'XTickMode', 'auto');
    if obj.epochCap == 4
      obj.axesHandle(4) = subplot(m,1,7:8,...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize', 10,...
        'XTickMode', 'auto');
    end

    if ~isempty(obj.epochNames)
      for ii = 1:obj.epochCap
        title(obj.axesHandle(ii), obj.epochNames{ii});
      end
    end

    if obj.plotStim
      obj.traceHandle = subplot(m,1,m,...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize', 10,...
        'XTickMode', 'auto');
    end

    set(obj.figureHandle, 'Color', 'w',...
      'Name', 'Cone Firing Rate Figure');
  end

  function clear(obj)
    cla(obj.axesHandle(1)); cla(obj.axesHandle(2)); cla(obj.axesHandle(3));
    obj.sweepOne = []; obj.sweepTwo = []; obj.sweepThree = []; obj.stimTrace = [];
    obj.sweepFour = [];
  end

  function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end
    response = epoch.getResponse(obj.device);
    [quantities, ~] = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    obj.epochSort = obj.epochSort + 1;
    if obj.epochSort > obj.epochCap
      obj.epochSort = 1;
    end

    if numel(quantities) > 0
      x = (1:numel(quantities)) / sampleRate;
      y = quantities;
      y = getResponseByType(y, obj.onlineAnalysis);
      y = getInstFt(y, sampleRate);
    else
      x = []; y = [];
    end

    % plot sweep
    %% TRACE ONE
    if obj.epochSort == 1
      if isempty(obj.sweepOne)
        obj.sweepOne = line(x, y, 'Parent', obj.axesHandle(1), 'Color', obj.epochColors(1,:));
      else
        set(obj.sweepOne, 'XData', x, 'YData', y);
      end
      set(obj.axesHandle(1), 'XColor', 'w', 'XTickLabel', {});
    %% TRACE TWO
    elseif obj.epochSort == 2
      if isempty(obj.sweepTwo)
        obj.sweepTwo = line(x, y, 'Parent', obj.axesHandle(2), 'Color', obj.epochColors(2,:));
      else
        set(obj.sweepTwo, 'XData', x, 'YData', y);
      end
      set(obj.axesHandle(2), 'XColor', 'w', 'XTickLabel', {});
    %% TRACE THREE
    elseif obj.epochSort == 3
      if isempty(obj.sweepThree)
        obj.sweepThree = line(x, y, 'Parent', obj.axesHandle(3), 'Color', obj.epochColors(3,:));
      else
        set(obj.sweepThree, 'XData', x, 'YData', y);
      end
    %% TRACE FOUR
    elseif obj.epochSort == 4 && obj.epochCap == 4
      if isempty(obj.sweepFour)
        obj.sweepFour = line(x, y, 'Parent', obj.axesHandle(4), 'Color', obj.epochColors(4,:));
      else
        set(obj.sweepFour, 'XData', x, 'YData', y);
      end
    end
    set(obj.axesHandle, 'TickDir', 'Out', 'Box', 'off');

    % plot trace
    if obj.plotStim
      plot(1:length(obj.stimTrace), obj.stimTrace, 'parent', obj.traceHandle, 'color', 'k', 'LineWidth', 1);
      set(obj.traceHandle, 'Box', 'off', 'TickDir', 'out');
      obj.traceHandle.XLim(2) = length(obj.stimTrace);
      set(obj.traceHandle, 'XColor', 'w', 'XTickLabel', {});
    end
  end
end
end
