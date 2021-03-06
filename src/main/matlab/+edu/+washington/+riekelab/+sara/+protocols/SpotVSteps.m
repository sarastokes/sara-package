classdef SpotVSteps < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1500                 % Spot trailing duration (ms)
        contrasts = [-1 1 -1 1]         % Contrasts (-1 to 1)
        innerRadius = 0                 % Inner radius in pixels.
        outerRadius = 1500              % Outer radius in pixels.
        chromaticity = 'achromatic'     % Spot color
        lightMean = 0.5                 % Background light intensity (0-1)
        ECl = -55                       % Apparent chloride reversal (mV)
        voltageHolds = [-20 0 20 35 50 65 90 115 0] % Change in Vhold re to ECl (mV)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        numberOfAverages = uint16(45)   % Number of epochs (holds*(contrasts+1))
    end

    properties (Hidden = true)
        displayName = 'IVCurve';
        version = 2;

        ampType
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            {'achromatic','S-iso','M-iso','L-iso','LM-iso',...
            'red', 'green', 'blue', 'yellow'})
        contrast
        intensity
        holdingPotential
        nextHold
        isDummyEpoch
        repsPerHold
        Vh
        allContrasts
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            obj.assignSpatialType();
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp), 'stimTrace', getLightStim(obj, 'pulse'));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp));

            obj.repsPerHold = length(obj.contrasts) + 1;
            obj.Vh = ones(obj.repsPerHold,1)*obj.voltageHolds + obj.ECl;
            obj.Vh = obj.Vh(:)';

            obj.allContrasts = [0, obj.contrasts(:)'];

            % Set the first holding potential.
            device = obj.rig.getDevice(obj.amp);
            device.background = symphonyui.core.Measurement(obj.Vh(1), device.background.displayUnits);
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            % Don't show the spot for dummy epochs.
            if ~obj.isDummyEpoch
                spot = stage.builtin.stimuli.Ellipse();
                spot.radiusX = obj.um2pix(obj.outerRadius);
                spot.radiusY = obj.um2pix(obj.outerRadius);
                spot.position = obj.canvasSize/2 + obj.centerOffset;
                if strcmp(obj.stageClass, 'Video')
                    spot.color = obj.intensity;
                else
                    spot.color = obj.intensity(1);
                end

                % Add the stimulus to the presentation.
                p.addStimulus(spot);

                % Control when the spot is visible.
                spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(spotVisible);

                % center mask for annulus
                if obj.innerRadius > 0
                    mask = stage.builtin.stimuli.Ellipse();
                    mask.radiusX = obj.um2pix(obj.innerRadius);
                    mask.radiusY = obj.um2pix(obj.innerRadius);
                    mask.position = obj.canvasSize/2 + obj.centerOffset;
                    mask.color = obj.lightMean;
                    p.addStimulus(mask);
                end
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Get the current contrast.
            if length(obj.contrasts) > 1
                obj.contrast = obj.allContrasts(mod(obj.numEpochsCompleted,length(obj.allContrasts))+1);
            else
                obj.contrast = obj.contrasts;
            end

            % Get the current holding potential.
            obj.holdingPotential = obj.Vh(mod(obj.numEpochsCompleted,length(obj.Vh))+1);
            if (obj.numEpochsCompleted+1) < obj.numberOfAverages
                obj.nextHold = obj.Vh(mod(obj.numEpochsCompleted+1,length(obj.Vh))+1);
            end

            % Determine whether this is a dummy epoch (i.e. no stimulus).
            obj.isDummyEpoch = (mod(obj.numEpochsCompleted, obj.repsPerHold) == 0);

            % Don't persist dummy epochs.
            if obj.isDummyEpoch
                epoch.shouldBePersisted = false;
            else
                epoch.shouldBePersisted = true;
            end

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

            % Save the epoch-specific parameters
            epoch.addParameter('contrast',obj.contrast);
            epoch.addParameter('holdingPotential',obj.holdingPotential);

            % Set the holding potential.
            device = obj.rig.getDevice(obj.amp);
            device.background = symphonyui.core.Measurement(...
                obj.holdingPotential, device.background.displayUnits);
        end

        function completeEpoch(obj, epoch)
            completeEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Set the Amp background to the next hold.
            if (obj.numEpochsCompleted+1) < obj.numberOfAverages
                device = obj.rig.getDevice(obj.amp);
                device.background = symphonyui.core.Measurement(...
                    obj.nextHold, device.background.displayUnits);
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
