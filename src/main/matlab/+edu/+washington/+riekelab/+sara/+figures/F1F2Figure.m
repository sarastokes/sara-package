classdef F1F2Figure < symphonyui.core.FigureHandler

properties
  device
  xvals
  onlineAnalysis
  preTime
  stimTime
  temporalFrequency
  xName
  chromaticClass
  waitTime
  titlestr
  axisType
  showF2
end

properties
  axesHandle
  handles
  repsPerX
  F1
  F2
  P1
  epochNum
end

methods
  function obj = F1F2Figure(device, xvals, onlineAnalysis, preTime, stimTime, varargin)
    obj.device = device;
    obj.xvals = xvals;
    obj.onlineAnalysis = onlineAnalysis;
    obj.preTime = preTime;
    obj.stimTime = stimTime;

    ip = inputParser();
    ip.addParameter('xName', [], @(x)ischar(x));
    ip.addParameter('temporalFrequency', [], @(x)isvector(x));
    ip.addParameter('chromaticClass', 'achromatic', @(x)ischar(x));
    ip.addParameter('waitTime', 0, @(x)isnumeric(x));
    ip.addParameter('titlestr', [], @(x)ischar(x));
    ip.addParameter('axisType', 'linear', @(x)ischar(x));
    ip.addParameter('showF2', false, @(x)islogical(x));
    ip.parse(varargin{:});

    obj.temporalFrequency = ip.Results.temporalFrequency;
    obj.waitTime = ip.Results.waitTime;
    obj.titlestr = ip.Results.titlestr;
    obj.axisType = ip.Results.axisType;
    obj.showF2 = ip.Results.showF2;
    obj.chromaticClass = ip.Results.chromaticClass;
    obj.xName = ip.Results.xName;

    obj.F1 = zeros(size(obj.xvals));
    obj.F2 = zeros(size(obj.xvals));
    obj.P1 = zeros(size(obj.xvals));

    obj.epochNum = 0;

    obj.createUi();
  end % constructor

  function createUi(obj)
    import appbox.*;
    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
    sendSweepButton = uipushtool(...
      'Parent', toolbar,...
      'TooltipString', 'Store Sweep',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedSendSweep);
    setIconImage(sendSweepButton, symphonyui.app.App.getResource('icons/sweep_store.png'));
    switchAxisButton = uipushtool(...
      'Parent', toolbar,...
      'TooltipString', 'Switch axis',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedSwitchAxis);
    setIconImage(switchAxisButton, symphonyui.app.App.getResource('icons/sweep_store.png'));

    obj.axesHandle(1) = subplot(3,1,1:2,...
      'Parent', obj.figureHandle,...
      'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
      'FontSize', get(obj.figureHandle, 'DefaultLegendFontSize'),...
      'XTickMode', 'auto',...
      'XScale', obj.axisType);

    obj.axesHandle(2) = subplot(3,1,3,...
      'Parent', obj.figureHandle,...
      'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
      'FontSize', get(obj.figureHandle, 'DefaultLegendFontSize'),...
      'XTickMode', 'auto',...
      'XScale', obj.axisType);

    set(obj.figureHandle, 'Color', 'w');

    ylabel(obj.axesHandle(1), 'spikes/sec');
    xlabel(obj.axesHandle(2), obj.xName);
    ylabel(obj.axesHandle(2), 'phase');
    if ~isempty(obj.titlestr)
      obj.setTitle(obj.titlestr);
    end
  end % createUi

  function setTitle(obj, t)
    set(obj.figureHandle, 'Name', t);
    title(obj.axesHandle(1), t);
  end

  function clear(obj)
    cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
    obj.F1 = []; obj.P1 = []; obj.F2 = [];

  end

  function handleEpoch(obj, epoch)
    if ~epoch.hasResponse(obj.device)
      error(['Epoch does not contain a response for ' obj.device.name]);
    end

    obj.epochNum = obj.epochNum + 1;

    % for changing temporal frequencies
    if isempty(obj.temporalFrequency)
      tempFreq = epoch.parameters('temporalFrequency')
    else
      tempFreq = obj.temporalFrequency;
    end

    response = epoch.getResponse(obj.device);
    responseTrace = response.getData();
    sampleRate = response.sampleRate.quantityInBaseUnits;

    prePts = obj.preTime * 1e-3 * sampleRate;
    stimFrames = obj.stimTime * 1e-3 * binRate;

    if isempty(obj.xName)
      xval = obj.epochNum;
    else
      xval = epoch.parameters(obj.xName);
    end
    xIndex = obj.xaxis == xval;

    % Get the F1 amplitude and phase.

    if numel(quantities) > 0
      y = quantities;
      if strcmp(obj.recordingType, 'extracellular')
        res = spikeDetectorOnline(y, [], sampleRate);
        y = zeros(size(y));
        y(res.sp) = 1;
        y = BinSpikeRate(y(prePts+1:end), binRate, sampleRate);
      else
        if prePts > 0
          y = y - median(y(1:prePts));
        else
          y = y - median(y);
        end
        y = binData(y(prePts+1:end), binRate, sampleRate);
      end

      % iterate the reps
      obj.repsPerX(xIndex) = obj.repsPerX(xIndex) + 1;
      binRate = 60;
      binSize = binRate / tempFreq;
      numBins = floor(stimFrames/binSize);
      avgCycle = zeros(1, floor(binSize));
      for k = 1:numBins
        index = round((k-1)*binSize) + (1:floor(binSize));
        index(index > length(y)) = [];
        ytmp = y(index);
        avgCycle = avgCycle + ytmp(:)';
      end
      avgCycle = avgCycle / numBins;

      ft = fft(avgCycle);
      obj.F1(xIndex) = (obj.F1(xIndex) * (obj.repsPerX(xIndex)-1) + abs(ft(2)) / length(avgCycle)*2) / obj.repsPerX(xIndex);
      obj.F2(xIndex) = (obj.F2(xIndex) * (obj.repsPerX(xIndex)-1) + abs(ft(3)) / length(avgCycle)*2) / obj.repsPerX(xIndex);
      obj.P1(xIndex) = (obj.P1(xIndex) * (obj.repsPerX(xIndex)-1) + angle(ft(2))) / obj.repsPerX(xIndex);
    end % quantities

    cla(obj.axesHandle(1)); cla(obj.axesHandle(2));

    obj.handles.f1 = line(obj.xaxis, obj.F1, 'Parent', obj.axesHandle(1), 'Color', getPlotColor(obj.chromaticClass), 'Marker', 'o');
    if obj.showF2
      obj.handles.f2 = line(obj.xaxis, obj.F2, 'Parent', obj.axesHandle(1), 'Color', getPlotColor(obj.chromaticClass, 0.5), 'Marker', 'o');
    end
    obj.handles.p1 = line(obj.xaxis, obj.P1, 'Parent', obj.axesHandle(2), 'Color', getPlotColor(obj.chromaticClass), 'Marker', 'o');

    set(obj.axesHandle(1), 'XLim', [min(obj.xaxis) max(obj.xaxis)]);
    set(obj.axesHandle(2), 'XLim', [min(obj.xaxis) max(obj.xaxis)]);

  end % handleEpoch
end % methods

methods (Access = private)
  function onSelectedSendSweep(obj, ~, ~)
    outputStruct.F1 = obj.F1;
    outputStruct.F2 = obj.P1;
    answer = inputdlg('Save to workspace as:', 'save dialog', 1, {'r'});
    fprintf('%s new F1 data named %s\n', datestr(now), answer{1});
    assignin('base', sprintf('%s', answer{1}), outputStruct);
  end

  function onSelectedSwitchAxis(obj,~,~)
    % haven't debugged yet
    if strcmp(get(obj.axesHandle(1), 'YScale'), 'log');
      set(findobj(obj.figureHandle, 'Type', 'axes'),...
      'YScale', 'linear')
    else
      set(findobj(obj.figureHandle, 'Type', 'axes'),...
      'YScale', 'log');
    end
  end
end % methods
end % classdef
