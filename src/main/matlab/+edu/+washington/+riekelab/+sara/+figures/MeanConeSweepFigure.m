classdef MeanConeSweepFigure < symphonyui.core.FigureHandler

properties
  device
  stimClass
  stimTrace
end

properties (Access = private)
  axesHandle
  traceHandle
  plotStim
  epochSort
  epochInd
  respBlock

  epochColors
  epochNames
  sweepOne
  sweepTwo
  sweepThree
  sweepFour
  sweepOneMean
  sweepTwoMean
  sweepThreeMean
  sweepFourMean
end

methods
function obj = MeanConeSweepFigure(device, stimClass, varargin)
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

  obj.epochInd = 1;
  obj.respBlock.one = []; obj.respBlock.two = [];
  obj.respBlock.three = []; obj.respBlock.four = [];

  obj.sweepOne = []; obj.sweepTwo = []; obj.sweepThree = [];
  obj.sweepOneMean = []; obj.sweepTwoMean = []; obj.sweepThreeMean = [];
  obj.stimTrace = [];
  obj.sweepFour = []; obj.sweepFourMean = [];

	obj.createUi();
end


function createUi(obj)
	import appbox.*;
	toolbar = findall(obj.figureHandle, 'Type', 'toolbar');
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
	if length(obj.stimClass)== 4
	  obj.axesHandle(4) = subplot(m,1,7:8,...
	    'Parent', obj.figureHandle,...
	    'FontName', 'Roboto',...
	    'FontSize', 10,...
	    'XTickMode', 'auto');
	end

	if ~isempty(obj.epochNames)
	  for ii = 1
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
	cla(obj.axesHandle(1)); cla(obj.axesHandle(2)); cla(obj.axesHandle(3));
	cla(obj.traceHandle);
	obj.sweepOne = []; obj.sweepTwo = []; obj.sweepThree = [];
	obj.sweepOneMean = []; obj.sweepTwoMean = []; obj.sweepThreeMean = [];
	obj.stimTrace = [];
	obj.sweepFour = []; obj.sweepFourMean = [];
end

function handleEpoch(obj, epoch)
	if ~epoch.hasResponse(obj.device)
		error(['Epoch does not contain a response for ' obj.deviceName]);
	end
	response = epoch.getResponse(obj.device);
	[quantities, units] = response.getData();
	sampleRate = response.sampleRate.quantityInBaseUnits;

    obj.epochSort = obj.epochSort + 1;
    if obj.epochSort > length(obj.stimClass)
      obj.epochSort = 1;
      obj.epochInd = obj.epochInd + 1;
    end

    if numel(quantities) > 0
      x = (1:numel(quantities)) / sampleRate;
      % get the instantaneous firing rate
      y = getInstFt(quantities, sampleRate);
    else
      x = []; y = [];
    end

    c2 = obj.epochColors(obj.epochInd, :) + (0.6 * (1 - obj.epochColors(obj.epochInd, :)))


    % plot sweep
    if obj.epochSort == 1
      obj.respBlock.one(obj.epochInd, :) = y;
      if isempty(obj.sweepOne)
        obj.sweepOne(1) = line(x, y, 'Parent', obj.axesHandle(1),...
        	'Color', c2, 'LineWidth', 1);
      else
        obj.sweepOne(obj.epochInd) = line(x, y, 'Parent', obj.axesHandle(1),...
          'Color', c2, 'LineWidth', 1);
      end
      if isempty(obj.sweepOneMean)
        obj.sweepOneMean = line(x, mean(obj.respBlock.one), 'Parent', obj.axesHandle(1), 'Color', obj.epochColors(1,:), 'LineWidth', 1.5);
      else
      	set(obj.sweepOneMean, 'YData', mean(obj.respBlock.one, 1));
      end
    elseif obj.epochSort == 2
      obj.respBlock.two(obj.epochInd, :) = y;
      if isempty(obj.sweepTwo)
        obj.sweepTwo = line(x, y, 'Parent', obj.axesHandle(2),...
        	'LineWidth',1, 'Color', c2);
      else
        obj.sweepTwo(obj.epochInd) = line(x, y, 'Parent', obj.axesHandle(2),...
          'LineWidth', 1, 'Color', (obj.epochColors))
        if isempty(obj.sweepTwoMean)
        	obj.sweepTwoMean = line(x, mean(obj.respBlock.two), 'Parent', obj.axesHandle(2), 'LineWidth', 1.5, 'Color', obj.epochColors(2,:));
        else
        	set(obj.sweepTwoMean, 'YData', mean(obj.respBlock.two,1));
        end
      end
    elseif obj.epochSort == 3
      obj.respBlock.three(obj.epochInd, :) = y;
      if isempty(obj.sweepThree)
        obj.sweepThree(1) = line(x, y, 'Parent', obj.axesHandle(3),...
        	'LineWidth', 1, 'Color', c2);
      else
        obj.sweepThree(obj.epochInd) = line(x, y, 'Parent', obj.axesHandle(3), 'LineWidth', 1, 'Color', c2);
        if isempty(obj.sweepThreeMean)
        	obj.sweepThreeMean = line(x, mean(obj.respBlock.three, 1), 'Parent', obj.axesHandle(3), 'Color', obj.epochColors(3,:), 'LineWidth', 1.5);
        else
        	set(obj.sweepThreeMean, 'YData', mean(obj.respBlock.three, 1));
        end
      end
    elseif obj.epochSort == 4 && length(obj.stimClass) == 4
      obj.respBlock.four(obj.epochInd, :) = y;
      if isempty(obj.sweepFour)
        obj.sweepFour(1) = line(x, y, 'Parent', obj.axesHandle(4),...
        	'LineWidth', 1, 'Color', c2);
      else
        obj.sweepThree(obj.epochInd) = line(x, y, 'Parent', obj.axesHandle(4), 'LineWidth', 1, 'Color', c2);
        if isempty(obj.sweepFourMean)
        	obj.sweepFourMean = line(x, mean(obj.respBlock.four,1), 'Parent', obj.axesHandle(4),...
        		'Color', obj.epochColors(3, :), 'LineWidth', 1.5);
        else
        	set(obj.sweepFourMean, 'YData', mean(obj.respBlock.four, 1));
        end
      end
    end

    % plot trace
    if obj.plotStim
    	if isempty(obj.traceHandle)
      		plot(1:length(obj.stimTrace), obj.stimTrace, 'parent', obj.traceHandle,...
      			'Color', 'k', 'LineWidth', 1);
      		set(obj.traceHandle, 'Box', 'off');
      	end
    end
end
end % methods
end % classdef
