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
  epochCap
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

	obj.epochCap = length(obj.stimClass)

	if isempty(obj.stimTrace)
	  obj.plotStim = false;
	else
	  obj.plotStim = true;
	end

	obj.epochColors = zeros(length(obj.stimClass), 3);
	for ii = 1:length(obj.stimClass(ii))
		[obj.epochColors(ii,:), obj.epochNames{ii}, ~] = getPlotColor(colorCall);
	end

	obj.createUi();
end


function createUi(obj)
	import appbox.*;
	toolbar = findall(obj.figureHandle, 'Type', 'toolbar');
	if obj.plotStim
  		m = 2 * obj.epochCap + 1;
	else
	  	m = 2 * obj.epochCap; %n = 1:obj.epochCap;
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
	if obj.epochCap == 4
	  obj.axesHandle(4) = subplot(m,1,7:8,...
	    'Parent', obj.figureHandle,...
	    'FontName', 'Roboto',...
	    'FontSize', 10,...
	    'XTickMode', 'auto');
	end

	if ~isempty(obj.epochNames)
	  for ii = 1:obj.epochCap
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
	obj.sweepMeanOne = []; obj.sweepMeanTwo = []; obj.sweepMeanThree = [];
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
    if obj.epochSort > obj.epochCap
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
        obj.sweepOne = line(x, y, 'Parent', obj.axesHandle(1),...
        	'Color', obj.epochColors(1,:) + (0.6 * (1-obj.epochColors(1,:))), 'LineWidth', 1);
      else
      	oldTrace = get(obj.sweepOne, 'YData');
      	newTrace = [oldTrace; y];
        set(obj.sweepOne, 'YData', newTrace);
        if isempty(obj.sweepOneMean)
        	obj.sweepOneMean = line(x, mean(newTrace), 'Parent', obj.axesHandle(1),... 
        		'Color', obj.epochColors(1,:), 'LineWidth', 1.5);
        else
        	set(obj.sweepOneMean, 'YData', mean(newTrace));
        end
      end
    elseif obj.epochSort == 2
      if isempty(obj.sweepTwo)
        obj.sweepTwo = line(x, y, 'Parent', obj.axesHandle(2),... 
        	'LineWidth',1, 'Color', (obj.epochColors(2,:) + (0.6 * (1-obj.epochColors(2,:)))));
      else
      	oldTrace = get(obj.sweepTwo, 'YData');
      	newTrace = [oldTrace; y];
        set(obj.sweepTwo, 'YData', newTrace);
        if isempty(obj.sweepTwoMean)
        	obj.sweepTwoMean = line(x, mean(newTrace), 'Parent', obj.axesHandle(2),...
        		'LineWidth', 1.5, 'Color', obj.epochColors(2,:));
        else
        	set(obj.sweepTwoMean, 'YData', mean(newTrace));
        end
      end
    elseif obj.epochSort == 3
      if isempty(obj.sweepThree)
        obj.sweepThree = line(x, y, 'Parent', obj.axesHandle(3),...
        	'LineWidth', 1, 'Color', (obj.epochColors(3,:) + (0.6 * (1-obj.epochColors(3,:)))));
      else
      	oldTrace = get(obj.sweepThree, 'YData');
      	newTrace = [oldTrace; y];
        set(obj.sweepThree, 'YData', newTrace);
        if isempty(obj.sweepThreeMean)
        	obj.sweepThreeMean = line(x, mean(newTrace), 'Parent', obj.axesHandle(3),...
        		'Color', obj.epochColors(3,:), 'LineWidth', 1.5);
        else
        	set(obj.sweepThreeMean, 'YData', mean(newTrace));
        end
      end
    elseif obj.epochSort == 4 && obj.epochCap == 4
      if isempty(obj.sweepFour)
        obj.sweepFour = line(x, y, 'Parent', obj.axesHandle(4),...
        	'LineWidth', 1, 'Color', (obj.epochColors(4,:) + (0.6 * (1-obj.epochColors(4,:)))));
      else
      	oldTrace = get(obj.sweepFour, 'YData');
      	newTrace = [oldTrace, y];
        set(obj.sweepFour, 'YData', newTrace);
        if isempty(obj.sweepFourMean)
        	obj.sweepFourMean = line(x, mean(newTrace), 'Parent', obj.axesHandle(4),...
        		'Color', obj.epochColors(3, :), 'LineWidth', 1.5);
        else
        	set(obj.sweepFourMean, 'YData', mean(newTrace));
        end
      end
    end

    % plot trace
    if obj.plotStim
    	if isempty(obj.traceHandle)
      		plot(1:length(obj.stimTrace), obj.stimTrace, 'parent', obj.traceHandle,... 
      			'Color', 'k', 'LineWidth', 1);
      		set(obj.traceHandle, 'Box', off);
      	end
    end
end
end % methods
end % classdef


