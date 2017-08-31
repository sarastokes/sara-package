classdef GaussianNoise < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 21000                 % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        stdev = 0.3                     % Noise standard dev
        radius = 150                    % Inner radius in pixels.
        lightMean = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        chromaticClass = 'achromatic'   % Spot color
        stimulusClass = 'spot'          % Stimulus class
        onlineAnalysis = 'none'         % Online analysis type.
        randomSeed = true               % Use random noise seed?
        frameDwell = 1                  % Stimuli per frame
        numberOfAverages = uint16(6)   % Number of epochs
    end

    properties (Hidden)
        ampType
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        stimulusClassType = symphonyui.core.PropertyType('char', 'row', {'spot', 'annulus'})
        seed
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            if obj.lightMean == 0
                warndlg('Set lightMean to > 0');
                return;
            end

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.sara.figures.TemporalNoiseFigure', ...
                    obj.rig.getDevice(obj.amp),'recordingType', obj.onlineAnalysis, 'noiseClass', 'gaussian',...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                    'frameRate', obj.frameRate, 'numFrames', floor(obj.stimTime/1000 * obj.frameRate), 'frameDwell', 1, ...
                    'stdev', obj.stdev, 'frequencyCutoff', 0, 'numberOfFilters', 0, ...
                    'correlation', 0, 'stimulusClass', 'Stage');
            end


            if strcmp(obj.stageClass, 'LightCrafter')
                obj.chromaticClass = 'achromatic';
            end

            obj.setLEDs;
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            spot = stage.builtin.stimuli.Ellipse();
            if strcmp(obj.stimulusClass, 'annulus')
                spot.radiusX = min(obj.canvasSize/2);
                spot.radiusY = min(obj.canvasSize/2);
            else
                spot.radiusX = obj.radius;
                spot.radiusY = obj.radius;
            end
            spot.position = obj.canvasSize/2 + obj.centerOffset;
            if strcmp(obj.stageClass, 'Video')
                spot.color = 1*obj.ledWeights*obj.lightMean + obj.lightMean;
            else
                spot.color = obj.ledWeights(1)*obj.lightMean + obj.lightMean;
            end

            % Add the stimulus to the presentation.
            p.addStimulus(spot);

            % Add an center mask if it's an annulus.
            if strcmp(obj.stimulusClass, 'annulus')
                mask = stage.builtin.stimuli.Ellipse();
                mask.radiusX = obj.radius;
                mask.radiusY = obj.radius;
                mask.position = obj.canvasSize/2 + obj.centerOffset;
                mask.color = obj.lightMean;
                p.addStimulus(mask);
            end

            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            % Control the spot color.
            if strcmp(obj.stageClass, 'LcrRGB')
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColorLcrRGB(obj, state));
                p.addController(colorController);
            elseif strcmp(obj.stageClass, 'Video') && ~strcmp(obj.chromaticClass, 'achromatic')
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColorVideo(obj, state.time - obj.preTime * 1e-3));
                p.addController(colorController);
            else
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotAchromatic(obj, state.time - obj.preTime * 1e-3));
                p.addController(colorController);
            end

            function c = getSpotColorVideo(obj, time)
                if time >= 0
                    c = obj.stdev * (obj.noiseStream.randn * obj.ledWeights) * obj.lightMean + obj.lightMean;
                else
                    c = obj.lightMean;
                end
            end

            function c = getSpotAchromatic(obj, time)
                if time >= 0
                    c = obj.stdev * obj.noiseStream.randn * obj.lightMean + obj.lightMean;
                else
                    c = obj.lightMean;
                end
            end

            function c = getSpotColorLcrRGB(obj, state)
                if state.time - obj.preTime * 1e-3 >= 0
                    v = obj.noiseStream.randn;
                    if state.pattern == 0
                        c = obj.stdev * (v * obj.ledWeights(1)) * obj.lightMean + obj.lightMean;
                    elseif state.pattern == 1
                        c = obj.stdev * (v * obj.ledWeights(2)) * obj.lightMean + obj.lightMean;
                    else
                        c = obj.stdev * (v * obj.ledWeights(3)) * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end

        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Deal with the seed.
            if obj.randomSeed
                obj.seed = RandStream.shuffleSeed;
            else
                obj.seed = 1;
            end

            % Seed the random number generator.
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);

            % Save the seed.
            epoch.addParameter('seed', obj.seed);

            % Add the radius to the epoch.
            if strcmp(obj.stimulusClass, 'annulus')
                epoch.addParameter('outerRadius', min(obj.canvasSize/2));
            end
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end

    end

end
