classdef ConeInputFigure < symphonyui.core.FigureHandler

properties
  device
  seedList
  onlineAnalysis
  noiseClass
  params
end

properties (Access = private)
  imHandle
  axesHandle
  epochNum
  frameValues
  strf
  spatialRF
  seed
  numXChecks
  numYChecks
  stimTime
  preTime
  frameDwell
  frameRate
  cmap
  lcone
  mcone
  scone
end

methods
  function obj = ConeInputFigure(device, seedList, onlineAnalysis, noiseClass, params, varargin)
    obj.device = device;
    obj.seedList = seedList;
    obj.onlineAnalysis = onlineAnalysis;
    obj.noiseClass = noiseClass;
    obj.preTime = params(1); obj.preTime
    obj.stimTime = params(2); obj.stimTime
    obj.numXChecks = params(3); obj.numXChecks
    obj.numYChecks = params(4); obj.numYChecks
    obj.frameRate = params(5); obj.frameRate
    obj.frameDwell = params(6); obj.frameDwell
%    obj.intensity = intensity;

    % ip = inputParser();
    % ip.addParameter('numReps', 1, @(x)isnumeric(x) || isvector(x));
    % ip.parse(varargin{:});

    obj.epochNum = 0;

    % init strf and spatialRF
    if obj.epochNum == 0
      obj.strf.l = zeros(obj.numYChecks, obj.numXChecks, floor(obj.frameRate*0.5/obj.frameDwell));
      obj.spatialRF.l = zeros(obj.numYChecks, obj.numXChecks);
      obj.strf.m = zeros(size(obj.strf.l));
      obj.spatialRF.m = zeros(size(obj.spatialRF.l));
      obj.strf.s = zeros(size(obj.strf.l));
      obj.spatialRF.s = zeros(size(obj.spatialRF.m));
    end
    obj.cmap = 'parula'; % default
    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;
    toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
    changeCMap = uipushtool('parent', toolbar,....
      'TooltipString', 'Change color map',...
      'Separator', 'on',...
      'ClickedCallback', @obj.onSelectedChangeCMap);

    obj.axesHandle(1) = subplot(3,1,1,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
    obj.axesHandle(2) = subplot(3, 1, 2,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
    obj.axesHandle(3) = subplot(3,1,3,...
      'Parent', obj.figureHandle,...
      'FontName', 'roboto',...
      'FontSize', 10,...
      'XTickMode', 'auto');
  end

  function handleEpoch(obj, epoch)
%% sort epoch
    obj.epochNum = obj.epochNum + 1;
    coneOrder = 'lms';
    index = rem(obj.epochNum,3);
    if index == 0
      index = 3;
    end
    cone = coneOrder(index);

    obj.seed = epoch.parameters('seed');

%% get response
response = epoch.getResponse(obj.device);
responseTrace = response.getData();
sampleRate = response.sampleRate.quantityInBaseUnits;

resp = getResponseByType(responseTrace, obj.onlineAnalysis);

    % bin the response
    resp = resp(obj.preTime/1000*sampleRate+1:end);
    binWidth = sampleRate/obj.frameRate * obj.frameDwell;
    numBins = floor(obj.stimTime/1000 * obj.frameRate / obj.frameDwell);
    binData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1)*binWidth+1:k*binWidth);
      binData(k) = mean(resp(index));
    end

%% get stimulus
    % get the number of frames
    numFrames = floor(obj.stimTime/1000 * obj.frameRate/obj.frameDwell);

    % seed random number generator
    noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);

    % binary vs gaussian
    if strcmp(obj.noiseClass, 'binary')
      M = noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks) > 0.5;
      obj.frameValues = uint8(255 * M);
    else
      obj.frameValues = uint8((0.3 * noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks) * 0.5 + 0.5) * 255);
    end

    % regenerate stimulus
    stimulus = 2*(double(obj.frameValues)/255)-1;

%% get filter
    filterFrames = floor(obj.frameRate * 0.5/obj.frameDwell);
    lobePts = round(0.05 * filterFrames/0.5) : round(0.15*filterFrames/0.5);

    % do the reverse correlation
    filterTmp = zeros(obj.numYChecks, obj.numXChecks, filterFrames);
    for m = 1:obj.numYChecks
      for n = 1:obj.numXChecks
        tmp = ifft(fft(binData') .* conj(fft(squeeze(stimulus(:,m,n)))));
        filterTmp(m,n,:) = tmp(1 : filterFrames);
      end
    end

    % add to strf and spatialRF
    if strcmp(cone, 'l')
      obj.strf.l = obj.strf.l + filterTmp;
      sRF = squeeze(mean(obj.strf.l(:,:,lobePts), 3));
    elseif strcmp(cone, 'm')
      obj.strf.m = obj.strf.m + filterTmp;
      sRF = squeeze(mean(obj.strf.m(:,:,lobePts), 3));
    elseif strcmp(cone, 's')
      obj.strf.s = obj.strf.s + filterTmp;
      sRF = squeeze(mean(obj.strf.s(:,:,lobePts), 3));
    end

%% graph
    if strcmp(cone,'l')
      if isempty(obj.lcone)
        obj.lcone = imagesc(sRF, 'Parent', obj.axesHandle(1));
      else
        set(obj.lcone, 'CData', sRF);
      end
      colormap(obj.axesHandle(1), obj.cmap);
    elseif strcmp(cone,'m')
      if isempty(obj.mcone)
        obj.mcone = imagesc(sRF, 'Parent', obj.axesHandle(2));
      else
        set(obj.mcone, 'CData', sRF);
      end
      colormap(obj.axesHandle(2), obj.cmap);
    elseif strcmp(cone,'s')
      if isempty(obj.scone)
        obj.scone = imagesc(sRF, 'Parent', obj.axesHandle(3));
      else
        set(obj.scone, 'CData', sRF);
      end
      colormap(obj.axesHandle(3), obj.cmap);
    end
  end
end

methods (Access = private)
  function onSelectedChangeCMap(obj,~,~)
    cmaps = {'parula' 'gray' 'cubicYF'};
    cmapIndex = cmapIndex + 1;
    if cmapIndex > length(cmaps)
      cmapIndex = 1;
    end
    obj.cmap = cmaps{cmapIndex};
  end
end
end
