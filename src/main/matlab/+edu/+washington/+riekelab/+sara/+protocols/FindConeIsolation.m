classdef FindConeIsolation < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocolSara

    properties
        amp                             % Output amplifier
        preTime = 250                   % Spot leading duration (ms)
        stimTime = 1500                 % Spot duration (ms)
        tailTime = 250                  % Spot trailing duration (ms)
        temporalFrequency = 4.0         % Modulation frequency (Hz)
        stimulusClass = 'spot'          % Spot or grating
        targetCone = 'sCone'            % Which cone iso
        radius = 1500                   % Spot radius (pix)
        minStepBits = 2                 % Min step size (bits)
        maxStepBits = 3                 % Max step size (bits)
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        temporalClass = 'sinewave'      % Sinewave or squarewave?
        onlineAnalysis = 'extracellular' % Online analysis type.
        numberOfAverages = uint16(78)   % Number of epochs
    end

    properties (Hidden)
        ampType
        targetConeType = symphonyui.core.PropertyType('char', 'row', {'sCone', 'mCone', 'lCone'});
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'pulse'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        ledContrasts
        ledIndex
        oneAxis
        oneF1
        twoAxis
        twoF1
        foundMinimum
        foundMinOne
        foundMinTwo
        minOne
        minTwo
        searchValues
        minStep
        maxStep
        searchAxis
        theoreticalMins
    end

    properties (Hidden, Transient)
        analysisFigure
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.MTFanalysis);
                f = obj.analysisFigure.getFigureHandle();
                set(f, 'Name', sprintf('%s-iso search', obj.targetCone(1)));
                obj.analysisFigure.userData.axesHandle = axes('Parent', f);
            end

            if strcmp(obj.stageClass, 'LightCrafter')
            end

            % Calculate the theoretical iso point.
            switch obj.targetCone
            case 'sCone'
                obj.theoreticalMins = obj.quantalCatch(:,1:3)' \ [0 0 1]';
            case 'mCone'
                obj.theoreticalMins = obj.quantalCatch(:,1:3)'\[0 1 0]';
            case 'lCone'
                obj.theoreticalMins = obj.quantalCatch(:,1:3)'\[1 0 0]';
            end
            obj.theoreticalMins = obj.theoreticalMins/obj.theoreticalMins(3);
            obj.theoreticalMins = obj.theoreticalMins(:)';

            % Init the red and green mins.
            obj.minOne = 0;
            obj.minTwo = 0;

            obj.organizeParameters();
        end

        function MTFanalysis(obj, ~, epoch)
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            responseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;

            % Analyze response by type.
            responseTrace = obj.getResponseByType(responseTrace, obj.onlineAnalysis);

            %--------------------------------------------------------------
            % Get the F1 amplitude and phase.
            responseTrace = responseTrace(obj.preTime/1000*sampleRate+1 : end);
            binRate = 60;
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

            if strcmp(obj.searchAxis, 'red') && strcmp(obj.targetCone, 'sCone')
                if isempty(obj.twoAxis)
                    index = 1;
                else
                    index = length(obj.twoAxis) + 1;
                end
                obj.twoAxis(index) = obj.ledContrasts(obj.ledIndex);
                obj.twoF1(index) = abs(ft(2)) / length(ft)*2;
                obj.minTwo = obj.searchValues(find(obj.twoF1==min(obj.twoF1), 1));
            elseif strcmp(obj.searchAxis, 'blue')
                if isempty(obj.twoAxis)
                    index = 1;
                else
                    index = length(obj.twoAxis) + 1;
                end
                obj.twoAxis(index) = obj.ledContrasts(obj.ledIndex);
                obj.twoF1(index) = abs(ft(2)) / length(ft)*2;
                obj.minTwo = obj.searchValues(find(obj.twoF1==min(obj.twoF1), 1));
            else
                obj.oneAxis(obj.numEpochsCompleted) = obj.ledContrasts(obj.ledIndex);
                obj.oneF1(obj.numEpochsCompleted) = abs(ft(2)) / length(ft)*2;
            end
            %--------------------------------------------------------------

            axesHandle = obj.analysisFigure.userData.axesHandle;
            cla(axesHandle);
            hold(axesHandle, 'on');
            if ~strcmp(obj.targetCone, 'mCone')
              plot(obj.oneAxis, obj.oneF1, 'go-', 'Parent', axesHandle);
            else
              plot(obj.oneAxis, obj.oneF1, 'ro-', 'Parent', axesHandle);
            end
            if strcmp(obj.searchAxis, 'red') && ~strcmp(obj.targetCone, 'mCone')
                plot(obj.twoAxis, obj.twoF1, 'ro-', 'Parent', axesHandle);
            elseif strcmp(obj.searchAxis, 'blue')
                plot(obj.twoAxis, obj.twoF1, 'bo-', 'Parent', axesHandle);
            end
            hold(axesHandle, 'off');
            set(axesHandle, 'TickDir', 'out');
            ylabel(axesHandle, 'F1 amp');

            switch obj.targetCone
              case 'sCone'
                tmin = obj.theoreticalMins(1:2);
              case 'mCone'
                tmin = [obj.theoreticalMins(1) obj.theoreticalMins(3)];
              case 'lCone'
                tmin = obj.theoreticalMins(2:3);
            end
            title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages), ...
                ' theor: ', num2str(tmin), '; actual: ', num2str([obj.minTwo obj.minOne])], 'Parent', axesHandle);
        end

        function organizeParameters(obj)
            % Initialize variables.
            obj.foundMinimum = false;

            if strcmp(obj.stageClass, 'LcrRGB')
                obj.minStep = 2^obj.minStepBits / 64 * 2;
                obj.maxStep = 2^obj.maxStepBits / 64 * 2;
            else
                obj.minStep = 2^obj.minStepBits / 256 * 2;
                obj.maxStep = 2^obj.maxStepBits / 256 * 2;
            end

            % Initialize the search axis with the max step.
            obj.searchValues = [(-1 : obj.maxStep : 1), (-0.4375 : obj.minStep : -0.2031), (0 : obj.minStep : 0.125)];
            obj.searchValues = unique(obj.searchValues);

            if ~strcmp(obj.targetCone, 'mCone')
              obj.searchAxis = 'green';
              obj.ledIndex = 2;
            else
              obj.searchAxis = 'red';
              obj.ledIndex = 1;
            end
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = obj.radius;
            spot.radiusY = obj.radius;
            spot.position = obj.canvasSize/2 + obj.centerOffset;
            if strcmp(obj.stageClass, 'Video')
                spot.color = obj.ledContrasts*obj.backgroundIntensity + obj.backgroundIntensity;
            else
                spot.color = obj.ledContrasts(1)*obj.backgroundIntensity + obj.backgroundIntensity;
            end

            % Add the stimulus to the presentation.
            p.addStimulus(spot);

            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            % Control the spot color.
            if strcmp(obj.stageClass, 'LcrRGB')
                if strcmp(obj.temporalClass, 'sinewave')
                    colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColorLcrRGB(obj, state));
                p.addController(colorController);
                elseif strcmp(obj.temporalClass, 'squarewave')
                    colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColorLcrRGBSqwv(obj, state));
                p.addController(colorController);
                end
            elseif strcmp(obj.stageClass, 'Video')
                if strcmp(obj.temporalClass, 'sinewave')
                    colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                        @(state)getSpotColorVideo(obj, state.time - obj.preTime * 1e-3));
                    p.addController(colorController);
                elseif strcmp(obj.temporalClass, 'squarewave')
                    colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                        @(state)getSpotColorVideoSqwv(obj, state.time - obj.preTime * 1e-3));
                    p.addController(colorController);
                end
            else
            end

            function c = getSpotColorVideo(obj, time)
                c = obj.ledContrasts * sin(obj.temporalFrequency*time*2*pi) * obj.backgroundIntensity + obj.backgroundIntensity;
            end

            function c = getSpotColorVideoSqwv(obj, time)
                c = obj.ledContrasts * sign(sin(obj.temporalFrequency*time*2*pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
            end


            function c = getSpotColorLcrRGB(obj, state)
                if state.pattern == 0
                    c = obj.ledContrasts(1) * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi) * obj.backgroundIntensity + obj.backgroundIntensity;
                elseif state.pattern == 1
                    c = obj.ledContrasts(2) * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi) * obj.backgroundIntensity + obj.backgroundIntensity;
                else
                    c = obj.ledContrasts(3) * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi) * obj.backgroundIntensity + obj.backgroundIntensity;
                end
            end

            function c = getSpotColorLcrRGBSqwv(obj, state)
                if state.pattern == 0
                    c = obj.ledContrasts(1) * sign(sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
                elseif state.pattern == 1
                    c = obj.ledContrasts(2) * sign(sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
                else
                    c = obj.ledContrasts(3) * sign(sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
                end
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

            if (obj.numEpochsCompleted-length(obj.searchValues)) == 0
                if strcmp(obj.targetCone, 'sCone')
                    disp('Searching red');
                    obj.searchAxis = 'red';
                else%if strcmp(obj.targetCone, 'lCone')
                    disp('Searching blue');
                    obj.searchAxis = 'blue';
                end
                if strcmp(obj.onlineAnalysis, 'none')
                    obj.minOne = 0;
                else
                    obj.minOne = obj.searchValues(find(obj.oneF1==min(obj.oneF1), 1));
                end
            elseif (obj.numEpochsCompleted+1) > length(obj.searchValues)
                if strcmp(obj.targetCone, 'sCone')
                    obj.searchAxis = 'red';
                else%if strcmp(obj.targetCone, 'lCone') || strcmp(obj.targetCone, 'mCone')
                    obj.searchAxis = 'blue';
                end
            else %
                if strcmp(obj.targetCone, 'mCone')
                    obj.searchAxis = 'red';
                else
                    obj.searchAxis = 'green';
                end
            end

            switch obj.searchAxis
                case 'red'
                    if strcmp(obj.targetCone, 'mCone')
                      obj.ledContrasts = [obj.searchValues(obj.numEpochsCompleted+1) 0 1];
                    else
                      index = (obj.numEpochsCompleted+1)-length(obj.searchValues);
                      obj.ledContrasts = [obj.searchValues(index) obj.minOne 1];
                      obj.ledIndex = 1;
                    end
                case 'green' % always first
                    obj.ledContrasts = [0 obj.searchValues(obj.numEpochsCompleted+1) 1];
                    obj.ledIndex = 2;
                case 'blue' % always last
                    index = (obj.numEpochsCompleted+1)-length(obj.searchValues);
                    obj.ledContrasts = [1 obj.minOne obj.searchValues(index)];
                    obj.ledIndex = 3;
            end
            epoch.addParameter('ledContrasts', obj.ledContrasts);
            epoch.addParameter('searchAxis', obj.searchAxis);
            obj.ledContrasts
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end

end
