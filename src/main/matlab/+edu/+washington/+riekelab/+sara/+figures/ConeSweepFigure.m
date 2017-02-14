classdef ConeSweepFigure < symphonyui.core.FigureHandler

properties
  device
  stimClass
  stimTrace
end

properties (Access = private)
  axesHandle
  traceHandle
  plotStim
  trace
  epochSort
  epochColors
  epochNames
  sweepOne
  sweepTwo
  sweepThree
  sweepFour
end

methods
  function obj = ConeSweepFigure(device, stimClass, varargin)
    obj.device = device;
    obj.stimClass = stimClass;
    obj.epochSort = 0;

    ip = inputParser();
    ip.addParameter('stimTrace', [], @(x)isvector(x));
    ip.parse(varargin{:});
    obj.stimTrace = ip.Results.stimTrace;

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

    set(obj.figureHandle, 'Name', 'Cone Response Figure');

    if isempty(obj.epochColors)
      obj.epochColors = zeros(length(obj.stimClass), 3);
    end

    if obj.plotStim
      m = 2 * length(obj.stimClass) + 1;
    else
      m = 2 * length(obj.stimClass);
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
    if length(obj.stimClass) == 4
      obj.axesHandle(4) = subplot(m,1,7:8,...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize', 10,...
        'XTickMode', 'auto');
    end

    if ~isempty(obj.epochNames)
      for ii = 1:length(obj.stimClass)
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
    set(obj.figureHandle, 'Color', 'w');
  end

  function clear(obj)
    cla(obj.axesHandle); cla(obj.traceHandle); 
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
    if obj.epochSort > length(obj.stimClass)
      obj.epochSort = 1;
    end

    if numel(quantities) > 0
      x = (1:numel(quantities)) / sampleRate;
      y = quantities;
    else
      x = []; y = [];
    end

    % plot sweep
    if obj.epochSort == 1
      if isempty(obj.sweepOne)
        obj.sweepOne = line(x, y, 'Parent', obj.axesHandle(1), 'Color', obj.epochColors(1,:));
      else
        set(obj.sweepOne, 'XData', x, 'YData', y);
      end
      set(obj.axesHandle(1), 'XTickLabel', {}, 'XColor', 'w');
    elseif obj.epochSort == 2
      if isempty(obj.sweepTwo)
        obj.sweepTwo = line(x, y, 'Parent', obj.axesHandle(2), 'Color', obj.epochColors(2,:));
      else
        set(obj.sweepTwo, 'XData', x, 'YData', y);
      end
      set(obj.axesHandle(2), 'XColor', 'w', 'XTickLabel', {});
    elseif obj.epochSort == 3
      if isempty(obj.sweepThree)
        obj.sweepThree = line(x, y, 'Parent', obj.axesHandle(3), 'Color', obj.epochColors(3,:));
      else
        set(obj.sweepThree, 'XData', x, 'YData', y);
      end
      % set(obj.axesHandle(3), 'Box', 'off', 'TickDir', 'out');
    elseif obj.epochSort == 4 && length(obj.stimClass) == 4
      if isempty(obj.sweepFour)
        obj.sweepFour = line(x, y, 'Parent', obj.axesHandle(4), 'Color', obj.epochColors(4,:));
      else
        set(obj.sweepFour, 'XData', x, 'YData', y);
      end
    end
    set(obj.axesHandle, 'Box', 'off', 'TickDir', 'out');

    % plot trace
    if obj.plotStim
      if isempty(obj.trace)
        obj.trace = line(1:length(obj.stimTrace), obj.stimTrace,... 
          'Parent', obj.traceHandle, 'Color', 'k', 'LineWidth', 1);
          set(obj.traceHandle, 'Box', 'off', 'XColor', 'w', 'XTickLabel', {},...
              'XLimMode', 'manual', 'XLim', [0 length(obj.stimTrace)]);
        obj.traceHandle.XLim(2) = length(obj.stimTrace);
      else
        set(obj.trace, 'XData', 1:length(obj.stimTrace), 'YData', obj.stimTrace);
        set(obj.traceHandle, 'XLim', [0 length(obj.stimTrace)]);
      end
    end
  end
end
end