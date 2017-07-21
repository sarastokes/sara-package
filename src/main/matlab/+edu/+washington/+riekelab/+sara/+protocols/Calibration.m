classdef Calibration < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
    % 17Jul2017 - SSP - added cone-iso options, green LED

    properties
        amp                                 % Output amplifier
        preTime = 250                       % leading duration (ms)
        stimTime = 500                      % duration (ms)
        tailTime = 0                        % keep 0 for endless stim
        greenLED = '570nm'                  % green LED used
        chromaticClass = 'white'            % Chromatic type
        stimulusClass = 'increment'         % Which stimulus type?
        intensity = 1                       % ranges from 0-1
        altCal = false                      % switch between qCatch matrices
        numberOfAverages = uint16(256)      % Number of epochs
    end

    properties (Hidden)
        ampType
        greenLEDType = symphonyui.core.PropertyType('char', 'row', {'570nm', '505nm'})
        stimulusClassType = symphonyui.core.PropertyType('char', 'row', {'increment', 'decrement', 'intensity'})
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'white','black','red','green','blue','L-iso', 'M-iso', 'S-iso', 'LM-iso'})
        rectColor
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);
        end % prepareRun

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.rectColor); % Set background intensity

            % Create the stimulus.
            rect = stage.builtin.stimuli.Rectangle();
            rect.color = obj.rectColor;
            rect.position = obj.canvasSize / 2;
            rect.size = obj.canvasSize;

            visibleController = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

            colorController = stage.builtin.controllers.PropertyController(rect, 'color', ...
                @(state)getSpotColor(obj, state));

            p.addStimulus(rect);
            p.addController(visibleController);
            p.addController(colorController);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

            switch obj.chromaticClass
                case 'white'
                    obj.rectColor = obj.intensity * [1 1 1];
                case 'black'
                    obj.rectColor = obj.intensity * [0 0 0];
                case 'red'
                    obj.rectColor = obj.intensity * [1 0 0];
                case 'green'
                    obj.rectColor = obj.intensity * [0 1 0];
                case 'blue'
                    obj.rectColor = obj.intensity * [0 0 1];
                otherwise
                    if obj.altCal
                      cw = getColorWeightsLocal(obj, obj.chromaticClass);
                    else
                      obj.setColorWeights();
                      cw = obj.colorWeights;
                    end
                    switch obj.stimulusClass
                        case 'increment'
                            obj.rectColor = 0.5 * (1 * obj.intensity * obj.colorWeights) + 0.5;
                        case 'decrement'
                            obj.rectColor = 0.5 * (-1 * obj.intensity * obj.colorWeights) + 0.5;
                    end
            end
            epoch.addParameter('rectColor', obj.rectColor);
        end % prepareEpoch

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end
