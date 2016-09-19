classdef F1Figure < symphonyui.core.FigureHandler

properties
  device
  xvals                 % this is bar positions, spatialFreqs, radii, etc...
  onlineAnalysis
  preTime
  stimTime
  temporalFrequency
  plotColor
  numReps   % pass if numReps would ever be >1, otherwise numReps = 1
end

properties
  axesHandle
  sweep
  xaxis
  xpt
  sequence
  F1amp
  F1phase
  repsPerX
  meanf1amp
  meanf1phase
  epochNum
  fa
  pa
end

methods
function obj = F1Figure(device, xvals, onlineAnalysis, preTime, stimTime, temporalFrequency, varargin)
  obj.device = device;
  obj.xvals = xvals; xvals
  obj.onlineAnalysis = onlineAnalysis;
  obj.preTime = preTime;
  obj.stimTime = stimTime;
  obj.temporalFrequency = temporalFrequency;

  ip = inputParser();
  ip.addParameter('plotColor', [0 0 0], @(x)ischar(x) || isvector(x));
  ip.addParameter('numReps', 1, @(x)isnumeric(x) || isvector(x));
  ip.parse(varargin{:});

  obj.numReps = ip.Results.numReps;
  obj.plotColor = zeros(2,3);
  obj.plotColor(1,:) = ip.Results.plotColor;
  obj.plotColor(2,:) = obj.plotColor(1,:) + (0.5 * (1-obj.plotColor(1,:)));

  obj.plotColor
  ct = obj.xvals(:) * ones(1, obj.numReps);
  obj.sequence = sort(ct(:));

  obj.xaxis = unique(obj.sequence);
  % init f1 params
  obj.F1amp = zeros(size(obj.xvals));
  obj.F1phase = zeros(size(obj.xvals));

  obj.meanf1amp = zeros(size(obj.xaxis));
  obj.meanf1phase = zeros(size(obj.xaxis));
  obj.repsPerX = zeros(size(obj.xaxis));

  % epoch counter
  obj.epochNum = 0;

  obj.createUi();
end

function createUi(obj)
  import appbox.*;

  %toolbar = finall(obj.figureHandle, 'Type', 'uitoolbar');
  obj.axesHandle(1) = subplot(3,1,1:2,...
    'Parent', obj.figureHandle,...
    'FontName', 'roboto',...
    'FontSize', 10,...
    'XTickMode', 'auto',...
    'XScale', 'log');
  ylabel(obj.axesHandle(1), 'f1 amp');

% set title stuff

  obj.axesHandle(2) = subplot(4,1,4,...
    'Parent', obj.figureHandle,...
    'FontName', 'Roboto',...
    'FontSize', 10,...
    'XTickMode', 'auto',...
    'XScale', 'log');
  ylabel(obj.axesHandle(2), 'f1 phase');

  set(obj.figureHandle, 'Color', 'w');
end

function setTitle(obj, t)
  set(obj.figureHandle, 'Name', t);
  title(obj.axesHandle(1), t);
end

function clear(obj)
  cla(obj.axesHandle(1)); cla(obj.axesHandle(2));
  obj.F1amp = []; obj.F1phase = [];
end

function handleEpoch(obj, epoch)
  if ~epoch.hasResponse(obj.device)
    error(['Epoch does not contain a response for ' obj.device.name]);
  end

  obj.epochNum = obj.epochNum + 1;

  response = epoch.getResponse(obj.device);
  responseTrace = response.getData();
  sampleRate = response.sampleRate.quantityInBaseUnits;

  responseTrace = getResponseByType(responseTrace, obj.onlineAnalysis);

  % Get the F1 amplitude and phase.
  responseTrace = responseTrace(obj.preTime/1000*sampleRate+1 : end);
  binRate = 60;
  binWidth = sampleRate / binRate; % Bin at 60 Hz.
  numBins = floor(obj.stimTime/1000 * binRate);
  binData = zeros(1, numBins);
  for k = 1 : numBins
      index = round((k-1)*binWidth+1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
  end
  binsPerCycle = binRate / obj.temporalFrequency;
  numCycles = floor(length(binData)/binsPerCycle);
  cycleData = zeros(1, floor(binsPerCycle));
  for k = 1 : numCycles
      index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
      cycleData = cycleData + binData(index);
  end
  cycleData = cycleData / k;

  ft = fft(cycleData);

  f1amp = abs(ft(2))/length(ft)*2;
  f1phase = angle(ft(2)) * 180/pi;

  obj.F1amp(obj.epochNum) = f1amp;
  obj.F1phase(obj.epochNum) = f1phase;

  if isempty(obj.fa)
    obj.fa = line(obj.xaxis, obj.F1amp, 'parent', obj.axesHandle(1));
    set(obj.fa, 'Color', obj.plotColor(1,:), 'linewidth', 1, 'marker', 'o');
  else
    set(obj.fa, 'XData', obj.xaxis, 'YData', obj.F1amp);
    set(obj.axesHandle, 'XLim', [floor(min(obj.xaxis)) ceil(max(obj.xaxis))]);
  end

  if isempty(obj.pa)
    obj.pa = line(obj.xaxis, obj.F1phase, 'parent', obj.axesHandle(2));
    set(obj.pa, 'Color', obj.plotColor(1,:), 'linewidth', 1, 'marker', 'o');
  else
    set(obj.pa, 'XData', obj.xaxis, 'YData', obj.F1phase);
  end
end
end
end
