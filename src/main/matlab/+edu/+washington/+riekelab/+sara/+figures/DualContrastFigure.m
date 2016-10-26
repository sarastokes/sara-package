classdef DualContrastFigure < symphonyui.core.FigureHandler
	% combined dualresponsefigure and CRF analysis for Ram cone project

	properties (SetAccess = private)
		device1
		device2
		contrasts
		onlineAnalysis
		preTime
		stimTime
		temporalFrequency
	end

	properties
		axesHandle1
		axesHandle2

		repsPerX
		xaxis
		contrast

		f1amp1
		f1amp2

		crf1
		crf2
	end

methods
	function obj = DualContrastFigure(device1, device2, contrasts, onlineAnalysis, preTime, stimTime, temporalFrequency)
		obj.device1 = device1;
		obj.device2 = device2;
		obj.contrasts = contrasts;
		obj.onlineAnalysis = onlineAnalysis;
		obj.preTime = preTime;
		obj.stimTime = stimTime;
		obj.temporalFrequency = temporalFrequency;

		ct = obj.contrasts(:) * ones(1, numReps);
            
        % Sort from lowest to highest.
        sequence = sort( ct(:) );
            
        obj.xaxis = unique(sequence);

		obj.repsPerX = zeros(size(obj.xaxis));
		obj.crf1 = zeros(size(obj.xaxis));
		obj.crf2 = zeros(size(obj.xaxis));

		obj.createUi();
	end

	function createUi(obj)
		import appbox.*;
		toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');

	    obj.axesHandle1 = subplot(2, 1, 1, ...
            'Parent', obj.figureHandle, ...
            'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
            'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
            'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
            'XTickMode', 'auto');
        xlabel(obj.axesHandle1, 'sec');
        title(obj.axesHandle1, [obj.device1.name ' Response']);
        
        obj.axesHandle2 = subplot(2, 1, 2, ...
            'Parent', obj.figureHandle, ...
            'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
            'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
            'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
            'XTickMode', 'auto');
        xlabel(obj.axesHandle2, 'sec');
        title(obj.axesHandle2, [obj.device2.name ' Response']);
        set(obj.figureHandle, 'Color', 'w');

        set(obj.figureHandle, 'Name', [obj.device1.name ' and ' obj.device2.name ' Response']);
    end

	function handleEpoch(obj, epoch)
	    if ~epoch.hasResponse(obj.device1) || ~epoch.hasResponse(obj.device2)
            error(['Epoch does not contain a response for ' obj.device1.name ' or ' obj.device2.name]);
        end

        obj.contrast = epoch.parameter('contrast');

        response1 = epoch.getResponse(obj.device1);
  		responseTrace1 = response.getData();
  		sampleRate = response.sampleRate.quantityInBaseUnits;
  		responseTrace1 = getResponseByType(responseTrace1, obj.onlineAnalysis);
  		r1 = getF1amp(responseTrace1);

        response2 = epoch.getResponse(obj.device2);
  		responseTrace2 = response.getData();
  		sampleRate = response.sampleRate.quantityInBaseUnits;
  		responseTrace2 = getResponseByType(responseTrace2, obj.onlineAnalysis);
  		r2 = getF1amp(responseTrace2);

        
        % Increment the count.
        obj.repsPerX(index) = obj.repsPerX(index) + 1;
        obj.crf1(index) = r1 / obj.repsPerX(index);
        obj.crf2(index) = r2 / obj.repsPerX(index);

        if isempty(obj.f1amp1)
        	obj.f1amp1 = line(obj.xaxis, obj.crf1, 'parent', obj.axesHandle1);
        	set(obj.f1amp1, 'Color', 'k', 'linewidth', 1, 'marker', 'o');
        else
        	set(obj.f1amp1, 'YData', obj.crf1);
        	set(obj.axesHandle1, 'XLim', [floor(min(obj.xaxis)) ceil(max(obj.xaxis))]);
        end
        if isempty(obj.f1amp2)
        	obj.f1amp2 = line(obj.xaxis, obj.crf1, 'parent', obj.axesHandle2);
        	set(obj.f1amp2, 'Color', 'k', 'linewidth', 1, 'marker', 'o');
        else
        	set(obj.f1amp2, 'YData', obj.crf2);
        	set(obj.axesHandle2, 'XLim', [floor(min(obj.xaxis)) ceil(max(obj.xaxis))]);
        end        	


        function r = getF1amp(responseTrace)

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
            
            index = find(obj.xaxis == obj.contrast, 1);
            r = obj.F1Amp(index) * obj.repsPerX(index);
            r = r + abs(ft(2))/length(ft)*2;
        end
    end % handle epoch
end % methods
end % classdef






