classdef ContrastResponse < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % 29Aug2017 - SSP - added naka rushton fit to online analysis
    
    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 2500                 % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        contrasts = [3 3 3 7 7 7 13 13 13 26 26 38 38 51 51 64 102 128]/128 % Contrast (0-1)
        temporalFrequency = 4.0         % Modulation frequency (Hz)
        outerRadius = 1500              % Spot radius in pixels.
        innerRadius = 0                 % Set for annulus (pix)
        lightMean = 0.5                 % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        temporalClass = 'sinewave'      % Sinewave or squarewave?
        chromaticity = 'achromatic'     % Spot color
        numberOfAverages = uint16(18)   % Number of epochs
    end
    
    properties (Hidden = true)
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave', 'pulse-positive', 'pulse-negative'})
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso',...
            'red', 'green', 'blue', 'yellow'})
        
        sequence
        contrast
        
        xaxis
        F1Amp
        repsPerX
    end
    
    properties (Hidden = true, Transient = true)
        analysisFigure
    end

    properties (Hidden = true, Constant = true)
        VERSION = 3;
        DISPLAYNAME = 'Contrast Response';
    end
    
    methods        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            obj.assignSpatialType();

            obj.showFigure(...
                'edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp),...
                'stimTrace', getLightStim(obj, 'modulation'));
            
            if ~strcmp(obj.recordingMode, 'none')
                obj.analysisFigure = obj.showFigure( ...
                    'symphonyui.builtin.figures.CustomFigure',...
                    @obj.CRFanalysis);
                f = obj.analysisFigure.getFigureHandle();
                set(f, 'Name', 'Contrast Response Function');
                obj.analysisFigure.userData.axesHandle = axes('Parent', f);
            end
            
            if strcmp(obj.stageClass, 'LightCrafter')
                obj.chromaticity = 'achromatic';
            end
            
            numReps = ceil(double(obj.numberOfAverages) / length(obj.contrasts));
            ct = obj.contrasts(:) * ones(1, numReps);
            obj.sequence = sort( ct(:) );
            
            obj.xaxis = unique( obj.sequence );
            obj.F1Amp = zeros( size( obj.xaxis ) );
            obj.repsPerX = zeros( size( obj.xaxis ) );
            
            obj.setLEDs();
        end
        
        function CRFanalysis(obj, ~, epoch)
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            [y, ~] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            binRate = 60;
            if strcmp(obj.getOnlineAnalysis(),'spikes')
                res = spikeDetectorOnline(y, [], sampleRate);
                y = zeros(size(y));
                y(res.sp) = sampleRate;
            else
                if obj.preTime > 0
                    y = y - median(y(1:obj.preTime));
                else
                    y = y - median(y);
                end
            end
            
            %--------------------------------------------------------------
            % Get the F1 amplitude and phase.
            responseTrace = y(obj.preTime/1000*sampleRate+1 : end);
            
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
            
            % Increment the count.
            obj.repsPerX(index) = obj.repsPerX(index) + 1;
            obj.F1Amp(index) = r / obj.repsPerX(index);
            
            %--------------------------------------------------------------
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            cla(axesHandle);
            
            h1 = axesHandle;
            plot(obj.xaxis, obj.F1Amp, 'Parent', h1,...
                'LineWidth', 1, 'Marker', 'o',...
                'Color', getPlotColor(obj.chromaticity));
            
            if obj.numEpochsCompleted == double(obj.numberOfAverages)
                % Fit Naka-Rushton.
                [~, fitData, str] = fitNakaRushton(obj.xaxis, obj.F1Amp);
                hold(h1, 'on');
                plot(h1, obj.xaxis, fitData,...
                    'Color', getPlotColor(obj.chromaticity, 0.5),...
                    'LineWidth', 1);
                title(h1, str);
            else
                title(h1, ['Epoch ', num2str(obj.numEpochsCompleted),...
                    ' of ', num2str(obj.numberOfAverages)]);
            end
            set(h1, 'TickDir', 'out', 'Box', 'off');
            ylabel(h1, 'F1 amp (spikes/sec)');
            if obj.lightMean == 0
                xlabel(h1, 'Intensity');
            else
                xlabel(h1, 'Contrast');
            end
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
            
            spot = stage.builtin.stimuli.Ellipse();
            if obj.innerRadius > 0
                spot.radiusX = min(obj.canvasSize/2);
                spot.radiusY = min(obj.canvasSize/2);
            else
                spot.radiusX = obj.um2pix(obj.outerRadius);
                spot.radiusY = obj.um2pix(obj.outerRadius);
            end
            spot.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            
            if strcmpi(obj.temporalClass, 'pulse-negative')
                ct = -obj.contrast;
            else
                ct = obj.contrast;
            end
            
            if strcmp(obj.stageClass, 'Video')
                spot.color = ct * obj.ledWeights * obj.lightMean + obj.lightMean;
            else
                spot.color = ct * obj.lightMean + obj.lightMean;
            end
            
            % Add the stimulus to the presentation.
            p.addStimulus(spot);
            
            % Add an center mask if it's an annulus.
            if obj.innerRadius > 0
                mask = stage.builtin.stimuli.Ellipse();
                mask.radiusX = obj.outerRadius;
                mask.radiusY = obj.outerRadius;
                mask.position = obj.canvasSize/2 + obj.centerOffset;
                mask.color = obj.lightMean;
                p.addStimulus(mask);
            end
            
            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            
            if strcmp(obj.stageClass, 'LcrRGB')
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColorLcrRGB(obj, state));
            else
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColorVideo(obj, state.time - obj.preTime * 1e-3));
            end
            p.addController(colorController);
            
            function c = getSpotColorVideo(obj, time)
                if time >= 0
                    if strcmp(obj.temporalClass, 'sinewave')
                        c = obj.contrast * (sin(obj.temporalFrequency * time * 2 * pi) * ...
                            obj.ledWeights) * obj.lightMean + obj.lightMean;
                    else
                        c = obj.contrast * (sign(sin(obj.temporalFrequency * time * 2 * pi)) * ...
                            obj.ledWeights) * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end
            
            function c = getSpotColorLcrRGB(obj, state)
                if state.time - obj.preTime * 1e-3 >= 0
                    v = sin(obj.temporalFrequency * time * 2 * pi);
                    if state.pattern == 0
                        c = obj.contrast * (v * obj.ledWeights(1)) * obj.lightMean + obj.lightMean;
                    elseif state.pattern == 1
                        c = obj.contrast * (v * obj.ledWeights(2)) * obj.lightMean + obj.lightMean;
                    else
                        c = obj.contrast * (v * obj.ledWeights(3)) * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);
            
            obj.contrast = obj.sequence(obj.numEpochsCompleted+1);
            epoch.addParameter('contrast', obj.contrast);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end