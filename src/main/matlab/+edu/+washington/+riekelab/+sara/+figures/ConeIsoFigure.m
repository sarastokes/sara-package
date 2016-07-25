classdef ConeIsoFigure < symphonyui.core.FigureHandler

properties
  device
  stimClass
  stimTrace
end

properties (Access = private)
  axesHandle
  plotStim
  epochSort
  epochCap
  epochColors
  epochNames
  sweep
end

methods
  function obj = ConeIsoFigure(device, stimClass, varargin)
    obj.device = device;
    obj.stimClass = stimClass;
    obj.epochSort = 0;

    ip = inputParser();
    ip.addParameter('stimTrace', [], @(x)isvector(x));
    ip.parse(varargin{:});

    obj.stimTrace = ip.Results.stimTrace;

    if ~isempty(obj.stimClass)
      obj.epochCap = length(obj.stimClass);
    end

    if isempty(obj.stimTrace)
      obj.plotStim = false;
    end

    obj.epochColors = zeros(length(obj.stimClass),3);
    for ii = 1:length(obj.stimClass)
      colorCall = obj.stimClass(ii);
      switch colorCall
      case 'l'
        obj.epochNames{ii} = 'L-iso';
        obj.epochColors(ii, :) = [0.82353, 0, 0];
      case 'm'
        obj.epochNames{ii} = 'M-iso';
        obj.epochColors(ii, :) = [0, 0.52941, 0.21569];
      case 's'
        obj.epochNames{ii} = 'S-iso';
        obj.epochColors(ii,:) = [0.14118, 0.20784, 0.84314];
      case 'y'
        obj.epochNames{ii} = 'LM-iso';
        obj.epochColors(ii,:) = [0.90588, 0.43529, 0.31765];
      % no reason, just curious:
      case 'c'
        obj.epochNames{ii} = 'MS-iso';
        obj.epochColors(ii,:) = [0, 0.74902, 0.68627];
      case 'p'
        obj.epochNames{ii} = 'LS-iso';
        obj.epochColors(ii,:) = [0.64314, 0.011765, 0.43529];
      otherwise
        obj.epochNames{ii} = [0 0 0];
        obj.epochColors(ii,:) = 'Achromatic';
      end
    end


    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;
    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

    if isempty(obj.epochCap)
      obj.epochCap = 1;
    end
    if isempty(obj.epochColors)
      obj.epochColors = zeros(obj.epochCap, 3);
    end
    %if isempty(obj.epochNames)
  %    obj.epochNames{1:obj.epochCap} = '';
  %  end
    if obj.plotStim
      m = obj.epochCap + 1;
      for ii = 1:obj.epochCap
        n(ii) = [(2*ii - 1) (2*ii)];
      end
    else
      m = obj.epochCap; n = 1:obj.epochCap;
    end

    % create axes
    for ii = 1:obj.epochCap
      obj.axesHandle(ii) = subplot(m,1,n(ii),...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize', 10,...
        'XTickMode', 'auto');
        if ~isempty(obj.epochNames)
          title(sprintf('%s Response', obj.epochNames{ii}));
        end
    end
    if obj.plotStim
      obj.traceHandle = subplot(m,1,m,...
        'Parent', obj.figureHandle,...
        'FontName', 'Roboto',...
        'FontSize', 10,...
        'XTickMode', 'auto');
    end
  end

  function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end
    response = epoch.getResponse(obj.device);
    [quantities, units] = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    obj.epochSort = obj.epochSort + 1;
    if obj.epochSort > obj.epochCap
      obj.epochSort = 1;
    end

    if numel(quantities) > 0
      x = (1:numel(quantities)) / response.sampleRate.quantityInBaseUnits;
      y = quantities;
    else
      x = []; y = [];
    end

    % plot sweep
    if isempty(obj.sweep)
      obj.sweep = line(x, y, 'Parent', obj.axesHandle(obj.epochSort), 'Color', obj.epochColors(obj.epochSort,:));
    else
      set(obj.sweep, 'XData', x, 'YData', y);
    end

    % plot trace
    if obj.plotStim
      if isempty(obj.stimTrace) && ~isempty(obj.stimValue)
        for ii = 1:length(obj.stimValue)
          obj.stimTrace(ii,:) = obj.stimValue(ii) * ones(1, obj.stimTime);
        end
      end
      if ~isempty(obj.stimTrace)
        n = length(obj.stimValue);
        b = [(obj.bkgdMean * ones(n, obj.preTime)) obj.stimTrace (obj.bkgdMean * ones(n, obj.tailTime))];
        plot(b', 'Parent', obj.axesHandle(obj.epochCap + 1));
      end
    end
  end
end
end
