classdef ConeSweep < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % ~Jun2016 - SSP - created
    % 24Jul2017 - SSP - much needed improvements, greenLED specific stimuli

    properties
        amp
        preTime = 200
        stimTime = 1000
        tailTime = 200
        contrast = 1
        lightMean = 0.5
        outerRadius = 0
        innerRadius = 0
        temporalClass = 'SINEWAVE'
        temporalFrequency = 2
        centerOffset = [0,0]
        numberOfAverages = uint16(6)
    end

    properties (Hidden = true)
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
            'edu.washington.riekelab.sara.types.ModulationType'))
        chromaticity
        stimList
        outerRadiusPix
    end

    properties (Constant = true, Hidden = true)
        DISPLAYNAME = 'Cone Sweep';
        VERSION = 3;
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            % define stimuli by filter wheel setting
            switch obj.greenLED
                case '505nm'
                    obj.stimList = 'alms';
                case '570nm'
                    obj.stimList = 'ams';
            end

            if obj.outerRadius == 0
                obj.outerRadiusPix = 1500;
            else
                obj.outerRadiusPix = obj.um2pix(obj.outerRadius);
            end

            % get the stimulus class and trace
            obj.assignSpatialType();
            stimTrace = getLightStim(obj, 'modulation');
            
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    'stimTrace', stimTrace);
            else
                obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
            end

            if ~strcmp(obj.analysisMode, 'none')
                obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure',...
                    obj.rig.getDevice(obj.amp), obj.stimList, 'stimTrace', stimTrace);
            end
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = obj.outerRadiusPix;
            spot.radiusY = obj.outerRadiusPix;
            spot.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);

            visibleController = stage.builtin.controllers.PropertyController(...
                spot, 'visible', @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);

            colorController = stage.builtin.controllers.PropertyController(...
                spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

            p.addStimulus(spot);
            p.addController(visibleController);
            p.addController(colorController);

            % center mask for annulus
            if obj.innerRadius > 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end

            function c = getSpotColor(obj, time)
                if time >= 0
                    if strcmp(obj.temporalClass, 'SINEWAVE')
                        c = obj.contrast * obj.ledWeights...
                            * sin(obj.temporalFrequency * time * 2 * pi)...
                            * obj.lightMean + obj.lightMean;
                    elseif strcmp(obj.temporalClass, 'SQUAREWAVE')
                        c = obj.contrast * obj.ledWeights...
                            * sign(sin(obj.temporalFrequency * time * 2*pi))...
                            * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end % getSpotColor
        end % createPresentation

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Get the current stimulus
            lst = circshift(obj.stimList, [0, -1 * obj.numEpochsCompleted]);
            obj.chromaticity = obj.extendName(lst(1));
            obj.setLEDs();

            % Add extra properties to epoch
            epoch.addParameter('chromaticity', obj.chromaticity);
        end % prepareEpoch

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end % methods
end % classdef
