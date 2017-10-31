classdef TemporalNoiseFigure < edu.washington.riekelab.sara.figures.FigureHandler

    properties (SetAccess = private)
        % Required
        preTime
        stimTime
        numFrames

        % Optional
        onlineAnalysis
        frameRate
        frameDwell
        stdev
        frequencyCutoff
        numberOfFilters
        noiseClass
        stimulusClass
        chromaticity
    end

    properties (Access = private)
        axesHandle
        nlAxesHandle
        lineHandle
        nlHandle
        linearFilter
        xaxis
        yaxis
        stimColor
    end

    properties (Constant = true, Access = private)
        NONLINEARITYBINS = 200;
    end

    methods

        function obj = TemporalNoiseFigure(device, preTime, stimTime, numFrames, varargin)
            obj@edu.washington.riekelab.sara.figures.FigureHandler(device);

            obj.preTime = preTime;
            obj.stimTime = stimTime;
            obj.numFrames = numFrames;

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.addParameter('noiseClass', 'gaussian', @(x)ischar(x));
            ip.addParameter('frameRate', 60, @(x)isfloat(x));
            ip.addParameter('numFrames', [], @(x)isfloat(x));
            ip.addParameter('frameDwell', 1, @(x)isfloat(x));
            ip.addParameter('stdev', 0.3, @(x)isfloat(x));
            ip.addParameter('frequencyCutoff', 1, @(x)isfloat(x));
            ip.addParameter('numberOfFilters', 0, @(x)isfloat(x));
            ip.addParameter('stimulusClass','Stage',@(x)ischar(x));
            ip.addParameter('chromaticity', 'achromatic', @(x)ischar(x));
            addParameter(ip, 'onlineAnalysis', 'spikes', @(x)ischar(x));

            ip.parse(varargin{:});


            obj.onlineAnalysis = ip.Results.onlineAnalysis;
            obj.noiseClass = ip.Results.noiseClass;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameRate = ip.Results.frameRate;
            obj.frameDwell = ip.Results.frameDwell;
            obj.stdev = ip.Results.stdev;
            obj.frequencyCutoff = ip.Results.frequencyCutoff;
            obj.numberOfFilters = ip.Results.numberOfFilters;
            obj.stimulusClass = ip.Results.stimulusClass;
            obj.chromaticity = ip.Results.chromaticity;

            try
              obj.plotColor = getPlotColor(obj.chromaticity);
            catch
              obj.plotColor = [0 0 0];
            end

            % Check the stimulus class.
            if strcmpi(obj.stimulusClass, 'Stage') || strcmpi(obj.stimulusClass, 'spatial')
                obj.stimulusClass = 'Stage';
            else
                obj.stimulusClass = 'Injection';
            end
            
            obj.createUi();
        end

        function createUi(obj)
            createUi@edu.washington.riekelab.sara.figures.FigureHandler(obj);
            import appbox.*;

            obj.axesHandle = subplot(1, 3, 1:2, ...
                'Parent', obj.figureHandle, ...
                'XTickMode', 'auto');

            obj.nlAxesHandle = subplot(1, 3, 3, ...
                'Parent', obj.figureHandle, ...
                'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');

            obj.linearFilter = [];
            obj.xaxis = [];
            obj.yaxis = [];

            obj.setTitle([obj.device.name ': temporal filter']);

        end

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
        end

        function clear(obj)
            clear@edu.washington.riekelab.sara.figures.FigureHandler(obj);
            obj.linearFilter = [];
            % Set the x/y axes
            obj.xaxis = [];
            obj.yaxis = [];
        end

        function handleEpoch(obj, epoch)
            handleEpoch@edu.washington.riekelab.sara.figures.FigureHandler(obj, epoch);

            prePts = obj.preTime * 1e-3 * obj.sampleRate;
            stimPts = obj.stimTime * 1e-3 * obj.sampleRate;

            if strcmpi(obj.stimulusClass, 'Stage')
                binRate = 10000;
            else
                binRate = 480;
            end

            if numel(obj.lastResponse) > 0
                % Parse the response by type.
                y = responseByType(obj.lastResponse, obj.onlineAnalysis,...
                    'preTime', obj.preTime, 'sampleRate', obj.sampleRate);

                if strcmp(obj.onlineAnalysis,'extracellular') || strcmp(obj.onlineAnalysis, 'spikes_CClamp')
                    if obj.sampleRate > binRate
                        y = BinSpikeRate(y(prePts+1:end), binRate, obj.sampleRate);
                    else
                        y = y(prePts+1:end)*obj.sampleRate;
                    end
                else
                    % High-pass filter to get rid of drift.
                    y = highPassFilter(y, 0.5, 1/obj.sampleRate);
                    if prePts > 0
                        y = y - median(y(1:prePts));
                    else
                        y = y - median(y);
                    end
                    y = binData(y(prePts+1:end), binRate, obj.sampleRate);
                end

                % Make sure it's a row.
                y = y(:)';

                % Pull the seed.
                seed = epoch.parameters('seed');

                % Get the frame/current sequence.
                if strcmpi(obj.stimulusClass, 'Stage')
                    frameValues = getGaussianNoiseFrames(obj.numFrames, obj.frameDwell, obj.stdev, seed);

                    if binRate > obj.frameRate
                        n = round(binRate / obj.frameRate);
                        frameValues = ones(n,1)*frameValues(:)';
                        frameValues = frameValues(:);
                    end
                    plotLngth = round(binRate*0.5);
                else
                    frameValues = obj.generateCurrentStim(obj.sampleRate, seed);
                    frameValues = frameValues(prePts+1:stimPts);
                    if obj.sampleRate > binRate
                        frameValues = decimate(frameValues, round(obj.sampleRate/binRate));
                    end
                    plotLngth = round(binRate*0.025);
                end
                % Make it the same size as the stim frames.
                y = y(1 : length(frameValues));

                % Zero out the first half-second while cell is adapting to
                % stimulus.
                y(1 : floor(binRate/2)) = 0;
                frameValues(1 : floor(binRate/2)) = 0;

                % Reverse correlation.
                lf = real(ifft( fft([y(:)' zeros(1,100)]) .* conj(fft([frameValues(:)' zeros(1,100)])) ));

                if isempty(obj.linearFilter)
                    obj.linearFilter = lf;
                else
                    obj.linearFilter = (obj.linearFilter*(obj.epochCount-1) + lf)/obj.epochCount;
                end

                % Re-bin the response for the nonlinearity.
                resp = binData(y, 60, binRate);
                obj.yaxis = [obj.yaxis, resp(:)'];

                % Convolve stimulus with filter to get generator signal.
                pred = ifft(fft([frameValues(:)' zeros(1,100)]) .* fft(obj.linearFilter(:)'));

                pred = binData(pred, 60, binRate); pred=pred(:)';
                obj.xaxis = [obj.xaxis, pred(1 : length(resp))];

                % Get the binned nonlinearity.
                [xBin, yBin] = obj.getNL(obj.xaxis, obj.yaxis);

                % Plot the data.
                cla(obj.axesHandle);
                obj.lineHandle = line((1:plotLngth)/binRate, obj.linearFilter(1:plotLngth),...
                    'Parent', obj.axesHandle, 'Color', 'k');
                if ~strcmpi(obj.stimulusClass, 'Stage')
                    hold(obj.axesHandle, 'on');
                    line((1:round(binRate*0.25))/binRate/10, obj.linearFilter(1:round(binRate*0.25)),...
                        'Parent', obj.axesHandle, 'Color', 'r');
                    hold(obj.axesHandle, 'off');
                end
                axis(obj.axesHandle, 'tight');

                % get filter peak and trough, send to title
                [xmin, xmax] = getFilterPeaks((1:plotLngth)/binRate, obj.linearFilter(1:plotLngth));
                title(obj.axesHandle, ['Min = ', num2str(100*xmin) ', Max =' num2str(100*xmax)]);

                cla(obj.nlAxesHandle);
                obj.nlHandle = line(xBin, yBin, ...
                    'Parent', obj.nlAxesHandle, 'Color', 'k', 'Marker', '.');
                axis(obj.nlAxesHandle, 'tight');
            end
        end

        function stimValues = generateCurrentStim(obj, sampleRate, seed)
            gen = edu.washington.riekelab.sara.stimuli.GaussianNoiseGeneratorV2();

            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = 100;
            gen.stDev = obj.stdev;
            gen.freqCutoff = obj.frequencyCutoff;
            gen.numFilters = obj.numberOfFilters;
            gen.mean = 0;
            gen.seed = seed;
            gen.sampleRate = sampleRate;
            gen.units = 'pA';

            stim = gen.generate();
            stimValues = stim.getData();
        end

        function [xBin, yBin] = getNL(obj, P, R)
            % Sort the data; xaxis = prediction; yaxis = response;
            [a, b] = sort(P(:));
            xSort = a;
            ySort = R(b);

            % Bin the data.
            valsPerBin = floor(length(xSort) / obj.NONLINEARITYBINS);
            xBin = mean(reshape(xSort(1 : obj.NONLINEARITYBINS*valsPerBin),valsPerBin,obj.NONLINEARITYBINS));
            yBin = mean(reshape(ySort(1 : obj.NONLINEARITYBINS*valsPerBin),valsPerBin,obj.NONLINEARITYBINS));
        end

        function [xmin, xmax] = getFilterPeaks(xpts, linfilter)
          [~, ind] = peakfinder(linfilter, [], [], -1);
          xmin = xpts(min(ind));
          [~, ind] = peakfinder(linfilter);
          xmax = xpts(max(ind));
        end
    end
end
