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
    stim
    stim2
    stim3
    storedSweep
    epochNum
  end


  methods
  function obj = ResponseWithStimFigure(device, stimTrace, varargin)
    obj.device = device;
    obj.stimTrace = stimTrace;
    ip = inputParser();

    ip.addParameter('stimPerSweep', 1, @(x)isvector(x) || ischar(x));
    ip.addParameter('sweepColor', 'k', @(x)ischar(x) || isvector(x));
    ip.addParameter('stimColor', [], @(x)ischar(x) || isvector(x));
    ip.addParameter('storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
    ip.addParameter('stimTitle', [], @(x)ischar(x));
    ip.parse(varargin{:});

    obj.sweepColor = ip.Results.sweepColor;
    obj.storedSweepColor = ip.Results.storedSweepColor;
    obj.stimColor = ip.Results.stimColor;
    obj.stimPerSweep = ip.Results.stimPerSweep;
    obj.stimTitle = ip.Results.stimTitle;

    if obj.stimPerSweep == 3
      load stimColors;
      obj.stimColor = [stimColors.L; stimColors.M; stimColors.S];
    end

    obj.epochNum = 0;

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

    if isempty(obj.stimTitle)
      obj.setTitle([obj.device.name ' Response and Stimulus']);
    else
      obj.setTitle(obj.stimTitle);
    end

    obj.axesHandle(2) = subplot(4,1,4,...
      'Parent', obj.figureHandle,...
      'FontName', 'Roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto',...
      'XTick', [], 'XColor', 'w');

    set(obj.figureHandle, 'Color', 'w');
  end

  function setTitle(obj, t)
    set(obj.figureHandle, 'Name', t);
    title(obj.axesHandle(1), t);
  end

  function clear(obj)
    cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
    obj.sweep = []; obj.stim = [];
    obj.stim2 = []; obj.stim3 = [];
  end

  function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end

    obj.epochNum = obj.epochNum + 1;

    response = epoch.getResponse(obj.device);
    [quantities, units] = response.getData();

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

    % plot stimuli
    if ~isempty(obj.stimTrace)
      % multiple stim traces per epoch
      if obj.stimPerSweep == 3 % RGB led weights
        LEDs = epoch.parameter('ledContrasts');
        switch epoch.parameters('searchAxis')
        case 'green'
          obj.stim = line([1 length(obj.stimTrace)], [LEDs(1) LEDs(1)],...
            'Parent', obj.axesHandle(2), 'Color', obj.stimColor(1,:), 'LineWidth', 1);
          obj.stim2 = line(1:length(obj.stimTrace), LEDs(2) * obj.stimTrace,...
            'Parent', obj.axesHandle(2), 'Color', obj.stimColor(2,:), 'LineWidth', 1);
          obj.stim3 = line([1 length(obj.stimTrace)], [LEDs(3) LEDs(3)],...
            'Parent', obj.axesHandle(2), 'Color', obj.stimColor(3,:), 'LineWidth', 1);
        case 'red'
          set(obj.stim, 'XData', 1:length(obj.stimTrace), 'YData', LEDs(1)*obj.stimTrace);
          set(obj.stim2, 'XData', [1 length(obj.stimTrace)], 'YData', [LEDs(2) LEDs(2)]);
          set(obj.stim3, 'XData', [1 length(obj.stimTrace)], 'YData', [LEDs(3) LEDs(3)]);
        case 'blue'
          set(obj.stim, 'XData', [1 length(obj.stimTrace)], 'YData', [LEDs(1) LEDs(1)]);
          set(obj.stim2, 'XData', [1 length(obj.stimTrace)], 'YData', [LEDs(2) LEDs(2)]);
          set(obj.stim3, 'XData', 1:length(obj.stimTrace), 'YData', LEDs(3)*obj.stimTrace);
        end
      elseif obj.stimPerSweep == 2
        plot((obj.stimTrace)', 'Parent', obj.axesHandle(2)); % this works but i'm going to try a better way later
      else % single stim trace per epoch
        if size(obj.stimTrace, 1) > 1
          currentStimTrace = obj.stimTrace(obj.epochNum, :);
        else
          currentStimTrace = obj.stimTrace;
        end
        if isempty(obj.stim)
          obj.stim = line(1:length(currentStimTrace), currentStimTrace, 'Parent', obj.axesHandle(2), 'Color', obj.stimColor);
        else
          set(obj.stim, 'XData', 1:length(currentStimTrace), 'YData', currentStimTrace);
        end
        ylabel(obj.axesHandle(2), 'contrast', 'Interpreter', 'none');
      end
    end
  end % handleEpoch
end % methods

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
  end % methods
end % classdef
