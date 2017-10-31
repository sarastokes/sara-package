classdef Calibration < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % 17Jul2017 - SSP - added cone-iso options, green LED

    properties
        amp                                 % Output amplifier
        preTime = 250                       % Leading duration (ms)
        stimTime = 500                      % Duration (ms)
        tailTime = 0                        % Keep 0 for endless stim
        chromaticity = 'WHITE'              % Chromatic type
        stimulusClass = 'increment'         % Which stimulus type?
        intensity = 1                       % Ranges from 0-1
        numberOfAverages = uint16(256)      % Number of epochs
    end

    properties (Hidden = true)
        ampType
        stimulusClassType = symphonyui.core.PropertyType('char', 'row',...
            {'increment', 'decrement', 'intensity'})
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
                'edu.washington.riekelab.sara.types.ChromaticityType'))
        rectColor
    end

    properties (Hidden = true, Constant = true)
        displayName = 'Calibration';
        version = 2;
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
        end % prepareRun

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.rectColor); % Set background intensity

            % Create the stimulus.
            rect = stage.builtin.stimuli.Rectangle();
            rect.color = obj.rectColor;
            rect.position = obj.canvasSize / 2;
            rect.size = obj.canvasSize;
            p.addStimulus(rect);

            visibleController = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(visibleController);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            switch lower(obj.chromaticity)
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
                    obj.setLEDs;
                    cw = obj.colorWeights;
                    switch obj.stimulusClass
                        case 'increment'
                            obj.rectColor = 0.5 * (1 * obj.intensity * obj.colorWeights) + 0.5;
                        case 'decrement'
                            obj.rectColor = 0.5 * (-1 * obj.intensity * obj.colorWeights) + 0.5;
                    end
            end
            epoch.addParameter('rectColor', obj.rectColor);
        end % prepareEpoch

        function completeEpoch(obj, epoch)
            answer = inputdlg({'Measurement:'}, 'Calibration Dialog', 1, {''});
            if ~isempty(answer{1})
                try
                    answer = str2double(answer{:});
                catch
                    warndlg('Could not convert answer to a number');
                    answer = 0;
                end
                epoch.addParameter('measurement', answer);
            end

            completeEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end
