classdef ConeGrating < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    properties
        amp
        greenLED = '505nm'
        preTime = 250
        stimTime = 3500
        tailTime = 250
        waitTime = 500
        contrast = 1.0
        orientation = 0
        centerOffset = [0, 0]
        innerRadius = 0												% Set to create a mask
        outerRadius = 0												% Set to use an aperture
        temporalClass = 'drifting'
        spatialClass = 'sinewave'
        spatialPhase = 0
        temporalFrequency = 2
        chromaticClass = 'achromatic'
        onlineAnalysis = 'extracellular'
        defaultFrequencies = true							% Use the default spatial frequencies
        frequencies = 0												% SFs used if defaultFrequencies = false (cpd)
        numberOfAverages = uint16(8)
    end

    properties (Hidden)
        ampType
        greenLEDType = symphonyui.core.PropertyType('char', 'row', {'505nm', '570nm'})
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'drifting', 'reversing'})
        spatialClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        spatialFrequencies
        spatialFreq
        spatialPhaseRad
        coneContrasts
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end % didSetRig

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protcols.SaraStageProtocol(obj);

            if obj.defaultFrequencies
                obj.spatialFrequencies = obj.deg2pix([0.1 0.2 0.5 0.75 1 2 3.5 5]);
            else
                obj.spatialFrequencies = obj.deg2pix(obj.frequencies);
            end

            if double(obj.numberOfAverages) ~= length(obj.spatialFrequencies)
                warndlg('Number of averages should be %u', length(obj.spatialFrequencies));
            end

            obj.coneContrasts = coneContrast(obj.lightMean*obj.quantalCatch, ...
                obj.ledWeights, 'michaelson');
            obj.spatialPhaseRad = obj.spatialPhase / 180 * pi;

            stimColor = getPlotColor(obj.chromaticClass(1));
            stimTrace = 0.5 + zeros(1, obj.preTime);
            if obj.waitTime > 0
                stimTrace = [stimTrace, 1, 0, 0.5 + zeros(1, obj.waitTime-2)];
            end
            x = (1 : (obj.stimTime - obj.waitTime)) / 1e3;
            x = 0.5 * sin(obj.temporalFrequency * x * 2 * pi) + 0.5;
            stimTrace = [stimTrace, x, 0.5 + zeros(1, obj.tailTime)];


            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp), 'stimTrace', stimTrace, 'stimColor', stimColor);
            obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure',...
                obj.rig.getDevice(obj.amp), obj.spatialFrequencies, obj.onlineAnalysis,...
                obj.preTime, obj.stimTime, 'waitTime', obj.waitTime,...
                'plotColor', stimColor, 'temporalFrequency', obj.temporalFrequency);

        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            grate = stage.builtin.stimuli.Image(uint8(0 * obj.rawImage));
            grate.position = obj.canvasSize/2;
            grate.size = ceil(sqrt(obj.canvasSize(1)^2 + obj.canvasSize(2)^2)) * ones(1,2);
            grate.orientation = obj.orientation;
            grate.setMinFunction(GL.NEAREST);
            grate.setMagFunction(GL.NEAREST);
            p.addStimulus(grate);

            grateController = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateController);

            if strcmp(obj.temporalClass, 'drifting')
                imgController = stage.builtin.controllers.PropertyController(grate, 'imageMatrix',...
                    @(state)setDriftingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            else
                imgController = stage.builtin.controllers.PropertyController(grate, 'imageMatrix',...
                    @(state)setReversingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            end
            p.addController(imgController);

            function g = setDriftingGrating(obj, time)
                if time >= 0
                    phase = obj.temporalFrequency * time * 2 * pi;
                else
                    phase = 0;
                end
                g = cos(sfRad + phase + obj.rawImage);
                if strcmp(obj.spatialClass, 'squarewave')
                    g = sign(g);
                end

                g = obj.contrast * g;

                if ~strcmp(obj.chromaticClass, 'achromatic')
                    for m = 1:3
                        g(:,:,m) = obj.colorWeights(m) * g(:,:,m);
                    end
                end
                g = uint8(255*(obj.lightMean * g + obj.lightMean));
            end

            % Set the reversing grating
            function g = setReversingGrating(obj, time)
                if time >= 0
                    phase = round(0.5 * sin(time * 2 * pi * obj.temporalFrequency) + 0.5) * pi;
                else
                    phase = 0;
                end

                g = cos(obj.spatialPhaseRad + phase + obj.rawImage);

                if strcmp(obj.spatialClass, 'squarewave')
                    g = sign(g);
                end

                g = obj.contrast * g;

                % Deal with chromatic gratings.
                if ~strcmp(obj.chromaticClass, 'achromatic')
                    for m = 1 : 3
                        g(:,:,m) = obj.colorWeights(m) * g(:,:,m);
                    end
                end
                g = uint8(255*(obj.lightMean * g + obj.lightMean));
            end
            if obj.outerRadius ~= 0
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.position = obj.canvasSize/2 + obj.centerOffset;
                aperture.color = obj.lightMean;
                aperture.size = [max(obj.canvasSize) max(obj.canvasSize)];
                mask = stage.core.Mask.createCircularAperture(obj.apertureRadius*2/max(obj.canvasSize), 1024);
                aperture.setMask(mask);
                p.addStimulus(aperture);
            elseif obj.innerRadius ~= 0
                mask = stage.builtin.stimuli.Ellipse();
                mask.color = obj.lightMean;
                mask.radiusX = obj.apertureRadius;
                mask.radiusY = obj.apertureRadius;
                mask.position = obj.canvasSize / 2 + obj.centerOffset;
                p.addStimulus(mask);
            end
        end % createPresentation

        function setRawImage(obj)
            downsamp = 3;
            sz = ceil(sqrt(obj.canvasSize(1)^2 + obj.canvasSize(2)^2));
            [x,y] = meshgrid(...
                linspace(-sz/2, sz/2, sz/downsamp), ...
                linspace(-sz/2, sz/2, sz/downsamp));

            % Calculate the orientation in radians.
            rotRads = obj.orientation / 180 * pi;

            % Center the stimulus.
            x = x + obj.centerOffset(1)*cos(rotRads);
            y = y + obj.centerOffset(2)*sin(rotRads);

            x = x / min(obj.canvasSize) * 2 * pi;
            y = y / min(obj.canvasSize) * 2 * pi;

            % Calculate the raw grating image.
            img = (cos(0)*x + sin(0) * y) * obj.spatialFreq;
            obj.rawImage = img(1,:);

            if ~strcmp(obj.chromaticClass, 'achromatic')
                obj.rawImage = repmat(obj.rawImage, [1 1 3]);
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            obj.spatialFreq = obj.spatialFrequencies( obj.numEpochsCompleted+1 );
            obj.setRawImage();

            epoch.addParameter('spatialFreq', obj.spatialFreq);

            if obj.numEpochsCompleted == 0
                epoch.addParameter('lContrast', obj.coneContrasts(1));
                epoch.addParameter('mContrast', obj.coneContrasts(2));
                epoch.addParameter('sContrast', obj.coneContrasts(3));
                epoch.addParameter('rodContrast', obj.coneContrasts(4));
            end
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end

        function cpd = pix2deg(obj, pix)
            micronsPerDegree = 200;
            screenWidth = min(obj.canvasSize); % pixels
            cpd = pix / screenWidth / micronsPerPixel * micronsPerDegree;
        end
    end
end % classdef
