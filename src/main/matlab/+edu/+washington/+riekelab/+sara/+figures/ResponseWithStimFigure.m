classdef ResponseWithStimFigure < symphonyui.core.FigureHandler
  % Plots the response of a specified device in the most recent epoch
  % and plots the stim trace yayayayay

  properties
    device
    sweepColor
    stimColor
    storedSweepColor
%    chromaticClass
    preTime
    stimTime
    tailTime
    stimValue % for constant stimColor
    stimTrace % for changing stim
    bkgdi   % short version of backgroundIntensity
  end

  properties (Access = private)
    axesHandle
    sweep
    stim
    storedSweep
  end

  methods
  function obj = ResponsePlusTraceFigure(device, varargin)

    ip = inputParser();
    ip.addParameter('sweepColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('stimColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
    ip.addParameter('preTime', [], @(x)isvector(x));
    ip.addParameter('stimTime', [], @(x)isvector(x));
    ip.addParameter('tailTime', [], @(x)isvector(x));
    ip.addParameter('bkgdi', [], @(x)isvector(x));
    ip.addParameter('intensity', [], @(x)isvector(x));
    ip.addParameter('stimTrace', [], @(x)isvector(x));
    ip.addParameter('stimValue', [], @(x)isvector(x));
%    ip.addParameter('chromaticClass', [{'achromatic'}], @(x)iscellstr(x));

    obj.device = device;
    obj.sweepColor = ip.Results.sweepColor;
    obj.storedSweepColor = ip.Results.storedSweepColor;
    obj.preTime = ip.Results.preTime;
    obj.stimTime = ip.Results.stimTime;
    obj.tailTime = ip.Results.tailTime;
    obj.intensity = ip.Results.intensity;
    obj.bkgdi = ip.Results.bkgdi;
    obj.stimTrace = ip.Results.stimTrace;
%    obj.chromaticClass = ip.Results.chromaticClass;
    obj.stimColor = ip.Results.stimColor;
    obj.stimValue = ip.Results.stimValue;

    obj.createUi(obj);
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

    obj.axesHandle = subplot(4,1,1:3,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 12,...
      'XTickMode', 'auto');
    xlabel(obj.axesHandle(1), 'sec');

    obj.setTitle([obj.device.name ' Response']);

    obj.axesHandle = subplot(4,1,4,...
      'Parent', obj.figureHandle,...
      'FontName', 'Roboto',...
      'FontSize', 12,...
      'XTickMode', 'auto');
    xlabel(obj.axesHandle(2), 'sec');

  end

  function setTitle(obj, t)
    set(obj.figureHandle, 'Name', t);
    title(obj.axesHandle(1), t);
  end

  function clear(obj)
    cla(obj.axesHandle);
    obj.sweep = [];
  end

  function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end

    response = epoch.getResponse(obj.device);
    [quantities, units] = response.getData();

    % default LMSR colors
    % if isempty(obj.sweepColor)
    %   if ~isempty(obj.chromaticClass) && isempty(obj.sweepColor)
    %     if strcmp(obj.chromaticClass, 'k')
    %       obj.sweepColor = [0 0 0];
    %     elseif strcmp(obj.chromaticClass, 'S-iso')
    %       obj.sweepColor = [];
    %     elseif strcmp(obj.chromaticClass, 'M-iso')
    %       obj.sweepColor = [];
    %     elseif strcmp(obj.chromaticClass, 'L-iso')
    %       obj.sweepColor = [];
    %     end
    %   else
    %     obj.sweepColor = [0 0 0];
    %   end
    % end
    if isempty(obj.sweepColor)
      obj.sweepColor = [0 0 0];
    end
    co = get(groot, 'defaultAxesColorOrder'); % for stim trace colors


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
      obj.stimTrace = obj.stimValue * ones(size(obj.stimValue));
    end
    if ~isempty(obj.stimTrace)
      n = size(obj.stimTrace);
      obj.stim = [(obj.bkgdi * ones(n(1), length(obj.preTime))) obj.stimTrace (obj.bkgdi * ones(n(1), length(obj.tailTime)))];
      a = length(obj.stim);
      for ii = 1 : n(1)
        obj.stim = line(a, obj.stim(ii,:), 'Parent', obj.axesHandle(2), 'Color', co(ii,:)); hold on;
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
