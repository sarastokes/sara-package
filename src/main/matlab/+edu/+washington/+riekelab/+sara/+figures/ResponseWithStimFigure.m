classdef ResponseWithStimFigure < symphonyui.core.FigureHandler
  % Plots the response of a specified device in the most recent epoch
  % and plots the stim trace yayayayay

  properties
    device
    preTime
    stimTime
    tailTime
    bkgdi           % backgroundIntensity (used for preTime and tailTime)
    stimValue       % for constant stimColor
    stimTrace       % for changing stim
    sweepColor
    stimColor
    storedSweepColor
  end

  properties (Access = private)
    axesHandle
    sweep
    stim
    storedSweep
  end
  

  methods
  function obj = ResponseWithStimFigure(device, varargin)
    obj.device = device;
    ip = inputParser();

    ip.addParameter('preTime', [], @(x)isvector(x));
    ip.addParameter('stimTime', [], @(x)isvector(x));
    ip.addParameter('tailTime', [], @(x)isvector(x));
    ip.addParameter('bkgdi', [], @(x)isvector(x));
    ip.addParameter('stimValue', [], @(x)isvector(x));
    ip.addParameter('stimTrace', [], @(x)isvector(x));
    ip.addParameter('sweepColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('stimColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
    ip.parse(varargin{:});

    obj.sweepColor = ip.Results.sweepColor;
    obj.storedSweepColor = ip.Results.storedSweepColor;
    obj.preTime = ip.Results.preTime;
    obj.stimTime = ip.Results.stimTime;
    obj.tailTime = ip.Results.tailTime;
    obj.bkgdi = ip.Results.bkgdi;
    obj.stimTrace = ip.Results.stimTrace;
%    obj.chromaticClass = ip.Results.chromaticClass;
    obj.stimColor = ip.Results.stimColor;
    obj.stimValue = ip.Results.stimValue;

    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;

    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
    storeSweepButton = uipushtool(...
      'Parent', toolbar,...
      'TooltipString', 'Store Sweep',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedStoreSweep);
    setIconImage(storeSweepButton, symphonyui.app.App.getResource('icons', 'sweep_store.png'));

    obj.axesHandle(1) = subplot(4,1,1:3,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
    xlabel(obj.axesHandle(1), 'sec');

    obj.setTitle([obj.device.name ' Response and Stimulus']);

    obj.axesHandle(2) = subplot(4,1,4,...
      'Parent', obj.figureHandle,...
      'FontName', 'Roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto',...
      'YLim', [-0.1 1.1]);
%    xlabel(obj.axesHandle(2), 'sec');

  end

  function setTitle(obj, t)
    set(obj.figureHandle, 'Name', t);
    title(obj.axesHandle(1), t);
  end

  function clear(obj)
    cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
    obj.sweep = [];
  end

  function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end

    response = epoch.getResponse(obj.device);
    [quantities, units] = response.getData();

    if isempty(obj.sweepColor)
      obj.sweepColor = [0 0 0];
    end

    if numel(quantities) > 0
      x = (1:numel(quantities)) / response.sampleRate.quantityInBaseUnits;
      y = quantities;
    else
      x = [];
      y = [];
    end

    % plot sweep
    if isempty(obj.sweep)
      obj.sweep = line(x, y, 'Parent', obj.axesHandle(1), 'Color', obj.sweepColor);
    else
      set(obj.sweep, 'XData', x, 'YData', y);
    end
    ylabel(obj.axesHandle(1), units, 'Interpreter', 'none');

    % plot stim
    if isempty(obj.stimTrace) && ~isempty(obj.stimValue)
      for ii = 1:length(obj.stimValue)
          obj.stimTrace(ii,:) = obj.stimValue(ii) * ones(1,obj.stimTime);
      end
    end
    if ~isempty(obj.stimTrace)
      n = length(obj.stimValue);
      b = [(obj.bkgdi * ones(n, obj.preTime)) obj.stimTrace (obj.bkgdi * ones(n,obj.tailTime))];
      plot(b', 'Parent', obj.axesHandle(2));
    end
  end
end

  methods (Access = private)

  function onSelectedStoreSweep(obj, ~, ~)
    if ~isempty(obj.storedSweep)
      delete(obj.storedSweep);
    end
    obj.storedSweep = copyobj(obj.sweep, obj.axesHandle);
    set(obj.storedSweep,...
      'color', obj.storedSweepColor,...
      'HandleVisibility', 'off');
    end
  end
end
