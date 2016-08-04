classdef IsoBarCentering < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

    properties
        amp                             % Output amplifier
        preTime = 250                   % Spot leading duration (ms)
        stimTime = 2000                 % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        contrast = 1.0                  % contrast around mean (-1 to 1)
        temporalFrequency = 1.0         % Modulation frequency (Hz)
        barSize = [50 500]              % Bar size [width, height] (pix)
        searchAxis = 'xaxis'            % Search axis
        positions = -300:50:300         % Bar center position (pix)
        backgroundIntensity = 0.0       % Background light intensity (0-1)
        chromaticClass = 'achromatic'   % Bar color
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        onlineAnalysis = 'none'         % Online analysis type.
        numberOfAverages = uint16(13)   % Number of epochs
    end

    properties (Hidden)
        ampType
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso','S-iso', 'custom', 'red', 'green', 'blue', 'yellow', 'cyan', 'magenta'})
        searchAxisType = symphonyui.core.PropertyType('char', 'row', {'xaxis', 'yaxis'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        position
        orientation
        sequence
        F1
        F2
        xaxis
        stimTrace
        stimColor
        stimValues
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

            % set LED weights
            [obj.colorWeights, obj.stimColor, ~] = setColorWeightsLocal(obj, obj.chromaticClass);

            % get stim trace
            x = 0:0.001:((obj.stimTime - 1) * 1e-3);
            obj.stimValues = zeros(1, length(x));
            for ii = 1:length(x)
              obj.stimValues(1,ii) = obj.contrast * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
            end

            obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace, 'stimColor', obj.stimColor);

            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CTRanalysis);
                f = obj.analysisFigure.getFigureHandle();
                set(f, 'Name', 'bar centering');
                obj.analysisFigure.userData.axesHandle = axes('Parent', f);
            end

            % Create the matrix of bar positions.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.positions));

            % Get the array of radii.
            pos = obj.positions(:) * ones(1, numReps);
            pos = pos(:);
            obj.xaxis = pos';
            obj.F1 = zeros(1,length(pos));
            obj.F2 = zeros(1,length(pos));

            if strcmp(obj.searchAxis, 'xaxis')
                obj.orientation = 0;
                obj.sequence = [pos+obj.centerOffset(1) obj.centerOffset(2)*ones(length(pos),1)];
            else
                obj.orientation = 90;
                obj.sequence = [obj.centerOffset(1)*ones(length(pos),1) pos+obj.centerOffset(2)];
            end
        end

        function CTRanalysis(obj, ~, epoch)
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

            % Get the F1 and F2 responses.
            f = abs(ft(2:3))/length(ft)*2;

            obj.F1(obj.numEpochsCompleted) = f(1);
            obj.F2(obj.numEpochsCompleted) = f(2);
            %--------------------------------------------------------------

            axesHandle = obj.analysisFigure.userData.axesHandle;
            cla(axesHandle);
            hold(axesHandle, 'on');
            plot(obj.xaxis, obj.F1, 'ko-', 'Parent', axesHandle);
            plot(obj.xaxis, obj.F2, 'ro-', 'Parent', axesHandle);
            hold(axesHandle, 'off');
            set(axesHandle, 'TickDir', 'out');
            ylabel(axesHandle, 'F1/F2 amp');
            title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', axesHandle);
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);

            rect = stage.builtin.stimuli.Rectangle();
            rect.size = obj.barSize;
            rect.orientation = obj.orientation;
            rect.position = obj.canvasSize/2 + obj.position;
%            rect.color = obj.intensity;

            % Add the stimulus to the presentation.
            p.addStimulus(rect);

            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

            % Control the bar intensity.
            colorController = stage.builtin.controllers.PropertyController(rect, 'color', ...
                @(state)getSpotColorVideoSqwv(obj, state.time - obj.preTime * 1e-3));
            p.addController(colorController);

            function c = getSpotColorVideoSqwv(obj, time)
                c = obj.contrast * obj.colorWeights * sign(sin(obj.temporalFrequency*time*2*pi)) * 0.5 + 0.5;
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

            obj.position = obj.sequence(obj.numEpochsCompleted+1, :);
            if strcmp(obj.searchAxis, 'xaxis')
                epoch.addParameter('position', obj.position(1));
            else
                epoch.addParameter('position', obj.position(2));
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
