classdef ChromaticContrast < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 2500                 % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        contrasts = [3*ones(1,3) 7*ones(1,3) 13*ones(1,3) 26 26 38 38 51 51 64 102 128]/128 % Contrast (0-1)
        temporalFrequency = 4.0         % Modulation frequency (Hz)
        radius = 200                    % Inner radius in pixels.
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        temporalClass = 'sinewave'      % Sinewave or squarewave?
        chromaticClass = 'achromatic'   % Spot color
        stimulusClass = 'spot'          % Stimulus class
        onlineAnalysis = 'none'         % Online analysis type.
        numberOfAverages = uint16(18)   % Number of epochs
    end

    properties (Hidden)
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'pulse-positive', 'pulse-negative'})
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso', 'MS-iso', 'LS-iso', 'red', 'green', 'blue', 'yellow', 'cyan', 'magenta'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        stimulusClassType = symphonyui.core.PropertyType('char', 'row', {'spot', 'annulus'})
        sequence
        contrast
    end

     % Analysis properties
    properties (Hidden)
        xaxis
        F1Amp
        repsPerX
        stimTrace
        stimValues
        plotColor
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

          % trace for response figure
          x = 0:0.001:((obj.stimTime - 1) * 1e-3);
          fprintf('Length of x is %u\n', length(x));
          obj.stimValues = zeros(size(x));
          n = size(obj.stimValues);
          fprintf('Size of stimValues = %u %u\n', n(1), n(2));
          for ii = 1:length(x)
            if strcmp(obj.temporalClass, 'sinewave')
              obj.stimValues(ii) = obj.contrast * sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
            elseif strcmp(obj.temporalClass, 'squarewave')
              stimValues(ii) = obj.contrast * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
            end
          end

          obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

          obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace);


          if ~strcmp(obj.onlineAnalysis, 'none')
              obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.CRFanalysis);
              f = obj.analysisFigure.getFigureHandle();
              set(f, 'Name', 'Contrast Response Function');
              obj.analysisFigure.userData.axesHandle = axes('Parent', f);
          end

          if strcmp(obj.stageClass, 'LightCrafter')
              error('For LightCrafter use Mikes protocol');
          end

          obj.organizeParameters();

          [obj.colorWeights, obj.plotColor, ~] = setColorWeightsLocal(obj, colorCall);
        end

        function CRFanalysis(obj, ~, epoch)
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            responseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;

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

            index = find(obj.xaxis == obj.contrast, 1);
            r = obj.F1Amp(index) * obj.repsPerX(index);
            r = r + abs(ft(2))/length(ft)*2;

            % Increment the count.
            obj.repsPerX(index) = obj.repsPerX(index) + 1;
            obj.F1Amp(index) = r / obj.repsPerX(index);

            %--------------------------------------------------------------

            axesHandle = obj.analysisFigure.userData.axesHandle;
            cla(axesHandle);

            h1 = axesHandle;
            plot(obj.xaxis, obj.F1Amp, 'o-', 'color', obj.plotColor, 'Parent', h1);
            set(h1, 'TickDir', 'out');
            ylabel(h1, 'F1 amp');
            title(['Epoch ', num2str(obj.numEpochsCompleted), ' of ', num2str(obj.numberOfAverages)], 'Parent', h1);
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);

            spot = stage.builtin.stimuli.Ellipse();
            if strcmp(obj.stimulusClass, 'annulus')
                spot.radiusX = min(obj.canvasSize/2);
                spot.radiusY = min(obj.canvasSize/2);
            else
                spot.radiusX = obj.radius;
                spot.radiusY = obj.radius;
            end
            spot.position = obj.canvasSize/2 + obj.centerOffset;
            spot.color = 1*obj.colorWeights*obj.backgroundIntensity + obj.backgroundIntensity;

            % Add the stimulus to the presentation.
            p.addStimulus(spot);

            % Add an center mask if it's an annulus.
            if strcmp(obj.stimulusClass, 'annulus')
                mask = stage.builtin.stimuli.Ellipse();
                mask.radiusX = obj.radius;
                mask.radiusY = obj.radius;
                mask.position = obj.canvasSize/2 + obj.centerOffset;
                mask.color = obj.backgroundIntensity;
                p.addStimulus(mask);
            end

            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

            % Control the spot color.
            if ~strcmp(obj.chromaticClass, 'achromatic')
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));
                p.addController(colorController);
            else
                colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(state)getSpotAchromatic(obj, state.time - obj.preTime * 1e-3));
                p.addController(colorController);
            end

            function c = getSpotColor(obj, time)
                if time >= 0
                  if strcmp(obj.temporalClass, 'sinewave')
                    c = obj.contrast * (sin(obj.temporalFrequency * time * 2 * pi) * obj.colorWeights) * obj.backgroundIntensity + obj.backgroundIntensity;
                  elseif strcmp(obj.temporalClass, 'squarewave')
                    c = obj.contrast * sign(sin(obj.temporalFrequency * time * 2 * pi) * obj.colorWeights) * obj.backgroundIntensity + obj.backgroundIntensity;
                  end
                else
                    c = obj.backgroundIntensity;
                end
            end

            function c = getSpotAchromatic(obj, time)
                if time >= 0
                    c = obj.contrast * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
                else
                    c = obj.backgroundIntensity;
                end
            end
        end

        % This is a method of organizing stimulus parameters.
        function organizeParameters(obj)

            % Create the matrix of bar positions.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.contrasts));

            % Get the array of radii.
            ct = obj.contrasts(:) * ones(1, numReps);

            % Sort from lowest to highest.
            obj.sequence = sort( ct(:) );

            obj.xaxis = unique( obj.sequence );
            obj.F1Amp = zeros( size( obj.xaxis ) );
            obj.repsPerX = zeros( size( obj.xaxis ) );
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

            % Get the current contrast.
            obj.contrast = obj.sequence( obj.numEpochsCompleted+1 );
            epoch.addParameter('contrast', obj.contrast);

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
