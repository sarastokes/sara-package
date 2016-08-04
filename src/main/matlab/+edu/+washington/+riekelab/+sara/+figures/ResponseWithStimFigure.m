classdef ResponseWithStimFigure < symphonyui.core.FigureHandler
  % Plots the response of a specified device in the most recent epoch
  % and plots the stim trace yayayayay

  properties
    device
    stimTrace
    sweepColor
    stimColor
    storedSweepColor
    stimPerSweep
    stimTitle
  end

  properties (Access = private)
    axesHandle
    sweep
    storedSweep
  end


  methods
  function obj = ResponseWithStimFigure(device, stimTrace, varargin)
    obj.device = device;
    obj.stimTrace = stimTrace;
    ip = inputParser();

    ip.addParameter('stimPerSweep', [], @(x)isvector(x));
    ip.addParameter('sweepColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('stimColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
    ip.addParameter('stimTitle', [], @(x)ischar(x));
    ip.parse(varargin{:});

    obj.sweepColor = ip.Results.sweepColor;
    obj.storedSweepColor = ip.Results.storedSweepColor;
    obj.stimColor = ip.Results.stimColor;
    obj.stimPerSweep = ip.Results.stimPerSweep;
    obj.stimTitle = ip.Results.stimTitle

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
    title(obj.axesHandle(1), obj.stimTitle);

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

    if isempty(obj.stimColor)
      obj.stimColor = [0 0 0];
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

    if ~isempty(obj.stimTrace)
      if obj.stimPerSweep > 1
        plot((obj.stimTrace)', 'Parent', obj.axesHandle(2));
      else
        plot(obj.stimTrace, 'Parent', obj.axesHandle(2), 'color', obj.stimColor);
      end
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
