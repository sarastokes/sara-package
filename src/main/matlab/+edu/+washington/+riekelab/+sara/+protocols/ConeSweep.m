classdef ConeSweep < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % ~Jun2016 - SSP - created
    % 24Jul2017 - SSP - much needed improvements, greenLED specific stimuli

    properties
        amp
        greenLED = '570nm'
        preTime = 200
        stimTime = 1000
        tailTime = 200
        contrast = 1
        lightMean = 0.5
        radius = 1500
        innerRadius = 0
        temporalClass = 'sinewave'
        temporalFrequency = 2
        centerOffset = [0,0]
        checkSpikes = false
        onlineAnalysis = 'extracellular'
        numberOfAverages = uint16(6)
    end

    properties (Hidden)
        ampType
        greenLEDType = symphonyui.core.PropertyType('char', 'row', {'570nm','505nm'})
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        chromaticClass
        stimulusClass
        stimList
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            % define stimuli by filter wheel setting
            switch obj.greenLEDName
                case 'Green_505nm'
                    obj.stimList = 'alm';
                case 'Green_570nm'
                    obj.stimList = 'as';
            end

            % get the stimulus class
            if obj.innerRadius == 0
                obj.stimulusClass = 'spot';
            else
                obj.stimulusClass = 'annulus';
            end

            % get stimulus trace for response figure
            x = 1:(obj.sampleRate*obj.stimTime * 1e-3);
            switch obj.temporalClass
                case 'sinewave'
                    stimValues = sin(obj.temporalFrequency * x * 2 * pi) * obj.lightMean + obj.lightMean;
                case 'squarewave'
                    stimValues = sign(sin(obj.temporalFrequency * x * 2 * pi)) * obj.lightMean + obj.lightMean;
            end
            stimTrace = [(obj.lightMean * ones(1, obj.sampleRate * obj.preTime * 1e-3)) stimValues (obj.lightMean * ones(1, obj.sampleRate * obj.tailTime * 1e-3))];

            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                    obj.rig.getDevice(obj.amp), 'stimTrace', stimTrace);
            else
                obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
            end

            obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure',...
                obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', stimTrace);
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = obj.radius;
            spot.radiusY = obj.radius;
            spot.position = obj.canvasSize/2 + obj.centerOffset;

            spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

            spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

            p.addStimulus(spot);
            p.addController(spotVisibleController);
            p.addController(spotColorController);

            % center mask for annulus
            if obj.maskRadius > 0
                mask = stage.builtin.stimuli.Ellipse();
                mask.radiusX = obj.maskRadius;
                mask.radiusY = obj.maskRadius;
                mask.position = obj.canvasSize/2 + obj.centerOffset;
                mask.color = obj.lightMean;

                maskVisibleController = stage.builtin.controllers.PropertyController(mask, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

                p.addStimulus(mask);
                p.addController(maskVisibleController);
            end

            function c = getSpotColor(obj, time)
                if time >= 0
                    if strcmp(obj.temporalClass, 'sinewave')
                        c = obj.contrast * obj.ledValues * sin(obj.temporalFrequency * time * 2 * pi) * obj.lightMean + obj.lightMean;
                    elseif strcmp(obj.temporalClass, 'squarewave')
                        c = obj.contrast * obj.ledValues * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end % getSpotColor
        end % createPresentation

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % get the current stimulus
            lst = circshift(obj.stimList, [0, -1 * obj.numEpochsCompleted]);
            obj.chromaticClass = obj.extendName(lst(1));
            obj.setLEDs();

            % add properties to epoch
            epoch.addParameter('chromaticClass', obj.chromaticClass);
            epoch.addParameter('greenLED', obj.greenLED(7:end));
            epoch.addParameter('ledWeights', obj.ledWeights);
        end % prepareEpoch

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end % methods

%     methods (Static)
%         function fullName = extendName(abbrev)
%             switch abbrev
%                 case 'a'
%                     fullName = 'achromatic';
%                 case 'l'
%                     fullName = 'l-iso';
%                 case 'm'
%                     fullName = 'm-iso';
%                 case 's'
%                     fullName = 's-iso';
%             end
%         end % extendName
%     end % static methods
end % classdef
