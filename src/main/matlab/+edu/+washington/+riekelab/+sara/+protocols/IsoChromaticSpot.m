classdef IsoChromaticSpot < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
% adapted from ChromaticSpot

    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        contrast = 1.0                  % Contrast (-1 to 1)
        innerRadius = 0                 % Inner radius in pixels.
        outerRadius = 456               % Outer radius in pixels.
        chromaticClass = 'achromatic'   % Spot color (iso needs bkgd mean)
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        onlineAnalysis = 'none'         % Online analysis type.
        numberOfAverages = uint16(1)    % Number of epochs
    end

    properties (Hidden)
        ampType
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic','L-iso','M-iso','S-iso','LM-iso', 'MS-iso', 'LS-iso',})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        intensity
        stimColor
        stimTrace
    end

    methods

        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

            % Get the canvas size.
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();

                % Set the LED weights.
            [obj.colorWeights, obj.stimColor, ~] = setColorWeightsLocal(obj, obj.chromaticClass);

            stimValues = obj.contrast + zeros(1, obj.stimTime);
            obj.stimTrace = [(obj.backgroundIntensity * ones(1,obj.preTime)) stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace, 'stimColor', obj.stimColor);
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = obj.outerRadius;
            spot.radiusY = obj.outerRadius;
            spot.position = obj.canvasSize/2 + obj.centerOffset;
            spot.color = obj.colorWeights * obj.contrast;

            % Add the stimulus to the presentation.
            p.addStimulus(spot);

            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

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

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

%             device = obj.rig.getDevice(obj.amp);
%             duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
%             epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
%             epoch.addResponse(device);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end

end
