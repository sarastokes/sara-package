classdef ChromaticSpot < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        contrast = 1.0                  % Contrast (-1 to 1)
        innerRadius = 0                 % Inner radius in pixels.
        outerRadius = 0              % Outer radius in pixels.
        chromaticity = 'achromatic'     % Spot color
        lightMean = 0.0                 % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        numberOfAverages = uint16(1)    % Number of epochs
    end

    properties (Hidden = true)
        ampType
        chromaticityType = symphonyui.core.PropertyType('char', 'row',... 
            {'achromatic', 'S-iso', 'M-iso', 'L-iso', 'LM-iso',...
            'red', 'green', 'blue', 'yellow', 'cyan', 'magenta'})
        intensity
    end

    properties (Hidden = true, Constant = true)
        DISPLAYNAME = 'Spot';
        VERSION = 2; 
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);


            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp), 'stimTrace', getLightStim(obj, 'pulse'));
            
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp));

            % Check the chromatic type to set the intensity.
            if strcmp(obj.stageClass, 'Video')
                % Set the LED weights.
                obj.setLEDs();
                if obj.lightMean > 0
                    obj.intensity = obj.lightMean * (obj.contrast * obj.ledWeights) + obj.lightMean;
                else
                    if isempty(strfind(obj.chromaticity, 'iso'))
                        obj.intensity = obj.ledWeights * obj.contrast;
                    else
                        obj.intensity = obj.contrast * (0.5 * obj.ledWeights + 0.5);
                    end
                end
            else
                if obj.lightMean > 0
                    obj.intensity = obj.lightMean * obj.contrast + obj.lightMean;
                else
                    obj.intensity = obj.contrast;
                end
            end
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            if obj.outerRadius == 0
                outerRadiusPix = 1500;
            else
                outerRadiusPix = obj.um2pix(obj.outerRadius);
            end

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = outerRadiusPix;
            spot.radiusY = outerRadiusPix;
            spot.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            if strcmp(obj.stageClass, 'Video')
                spot.color = obj.intensity;
            else
                spot.color = obj.intensity(1);
            end

            % Add the stimulus to the presentation.
            p.addStimulus(spot);

            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(...
                spot, 'visible', @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            
            % Create an annulus if innerRadius is specified
            if obj.innerRadius > 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end

            if strcmp(obj.stageClass, 'LcrRGB')
                % Control the spot color.
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColor(obj, state));
                p.addController(colorController);
            end

            function c = getSpotColor(obj, state)
                if state.pattern == 0
                    c = obj.intensity(1);
                elseif state.pattern == 1
                    c = obj.intensity(2);
                else
                    c = obj.intensity(3);
                end
            end
        end

        % Same presentation each epoch in a run. Replay.
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabProtocol(obj);
            if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages)
                obj.rig.getDevice('Stage').replay
            else
                obj.rig.getDevice('Stage').play(obj.createPresentation());
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
