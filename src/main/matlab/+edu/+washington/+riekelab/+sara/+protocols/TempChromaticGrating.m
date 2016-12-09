classdef TempChromaticGrating < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
% Chromatic grating but with my response figures and option for mask

% 12Sep2016 - copied mike's ChromaticGrating protocol, added working online analysis & response w/ stim figure
% 7Dec2016 - new F1Figure test

    properties
        amp                             % Output amplifier
        preTime = 250                   % Grating leading duration (ms)
        stimTime = 4000                 % Grating duration (ms)
        tailTime = 250                  % Grating trailing duration (ms)
        waitTime = 1000                 % Grating wait duration (ms)
        contrast = 0.7                  % Grating contrast (0-1)
        orientations = [0 90]           % Grating orientation (deg)
        spatialFreqs = [0.5 2 8]        % Spatial frequency (cyc/short axis of screen)
        temporalFrequency = 2.0         % Temporal frequency (Hz)
        spatialPhase = 0.0              % Spatial phase of grating (deg)
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        apertureRadius = 0              % Aperture radius in pixels.
        apertureClass = 'spot'          % Spot or annulus?
        maskRadius = 0                  % Mask radius in pixels
        spatialClass = 'sinewave'       % Spatial type (sinewave or squarewave)
        temporalClass = 'drifting'      % Temporal type (drifting or reversing)
        chromaticClass = 'achromatic'   % Chromatic type
        onlineAnalysis = 'extracellular' % Type of online analysis
        randomOrder = false             % Run the sequence in random order?
        checkSpikes = false             % Show SpikeDetectionFigure
        demoMode = true                 % use earlier grating data
        newFigure = false
        numberOfAverages = uint16(18)   % spatialFreqs * orientations
    end

    properties (Hidden)
        ampType
        apertureClassType = symphonyui.core.PropertyType('char', 'row', {'spot', 'annulus'})
        spatialClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
        temporalClassType = symphonyui.core.PropertyType('char', 'row', {'drifting', 'reversing'})
        chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic','S-iso','M-iso','L-iso', 'LM-iso', 'custom'})
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        rawImage
        spatialPhaseRad % The spatial phase in radians.
        spatialFrequencies
        spatialFreq % The current spatial frequency for the epoch
        orientation % The current orientation
    end

    % Analysis properties
    properties (Hidden) % SSP 12Sep2016
        coneContrasts
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

            if double(obj.numberOfAverages) ~= (length(obj.spatialFreqs)*length(obj.orientations))
                warndlg('number of averages might be an issue');
            end

            % trace for response figure
            x = 0:0.001:((obj.stimTime - 1) * 1e-3);
            stimValues = zeros(1, length(x));
            for ii = 1:length(x)
              if strcmp(obj.spatialClass, 'sinewave')
                stimValues(1,ii) = obj.contrast * sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
              elseif strcmp(obj.spatialClass, 'squarewave')
                stimValues(1,ii) = obj.contrast * sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
              end
            end
            obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

            [obj.colorWeights, obj.stimColor, ~] = setColorWeightsLocal(obj, obj.chromaticClass);

            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp),...
                obj.stimTrace, 'stimColor', obj.stimColor);

            % Calculate the spatial phase in radians.
            obj.spatialPhaseRad = obj.spatialPhase / 180 * pi;

            % Calculate the cone contrasts.
            obj.coneContrasts = coneContrast(obj.backgroundIntensity*obj.quantalCatch, ...
                obj.colorWeights, 'michaelson');

            % Organize stimulus and analysis parameters.
            obj.organizeParameters();
            if length(obj.orientations) > 1
                numReps = length(obj.orientations);
            elseif length(obj.spatialPhase)>1
                numReps = length(obj.spatialPhase);
            else
                numReps = double(obj.numberOfAverages/length(obj.spatialFreqs));
            end

            if ~strcmp(obj.onlineAnalysis,'none')
                if obj.newFigure
                    obj.showFigure('edu.washington.riekelab.sara.figures.FullF1Figure', obj.rig.getDevice(obj.amp),...
                        obj.spatialFreqs, obj.onlineAnalysis, obj.preTime, obj.stimTime, obj.temporalFrequency,... 
                        'plotColor', obj.stimColor, 'waitTime', obj.waitTime, 'numReps', numReps, 'demoMode', obj.demoMode);
                else
                    obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure', obj.rig.getDevice(obj.amp),...
                        obj.spatialFreqs, obj.onlineAnalysis, obj.preTime, obj.stimTime,...
                        'temporalFrequency', obj.temporalFrequency, 'plotColor', obj.stimColor, 'waitTime', obj.waitTime);
                end
            end

            if obj.checkSpikes
                obj.showFigure('edu.washington.riekelab.sara.figures.SpikeDetectionFigure', obj.rig.getDevice(obj.amp));
            end
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity

            % Create the grating.
            grate = stage.builtin.stimuli.Image(uint8(0 * obj.rawImage));
            grate.position = obj.canvasSize / 2;
            grate.size = ceil(sqrt(obj.canvasSize(1)^2 + obj.canvasSize(2)^2))*ones(1,2);
            grate.orientation = obj.orientation;

            % Set the minifying and magnifying functions.
            grate.setMinFunction(GL.NEAREST);
            grate.setMagFunction(GL.NEAREST);

            % Add the grating.
            p.addStimulus(grate);

            % Make the grating visible only during the stimulus time.
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);

            %--------------------------------------------------------------
            % Generate the grating.
            if strcmp(obj.temporalClass, 'drifting')
                imgController = stage.builtin.controllers.PropertyController(grate, 'imageMatrix',...
                    @(state)setDriftingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            else
                imgController = stage.builtin.controllers.PropertyController(grate, 'imageMatrix',...
                    @(state)setReversingGrating(obj, state.time - (obj.preTime + obj.waitTime) * 1e-3));
            end
            p.addController(imgController);

            % Set the drifting grating.
            function g = setDriftingGrating(obj, time)
                if time >= 0
                    phase = obj.temporalFrequency * time * 2 * pi;
                else
                    phase = 0;
                end

                g = cos(obj.spatialPhaseRad + phase + obj.rawImage);

                if strcmp(obj.spatialClass, 'squarewave')
                    g = sign(g);
                end

                g = obj.contrast * g;

                % Deal with chromatic gratings.
                if ~strcmp(obj.chromaticClass, 'achromatic')
                    for m = 1 : 3
                        g(:,:,m) = obj.colorWeights(m) * g(:,:,m);
                    end
                end
                g = uint8(255*(obj.backgroundIntensity * g + obj.backgroundIntensity));
            end

            % Set the reversing grating
            function g = setReversingGrating(obj, time)
                if time >= 0
                    phase = round(0.5 * sin(time * 2 * pi * obj.temporalFrequency) + 0.5) * pi;
                else
                    phase = 0;
                end

                g = cos(obj.spatialPhaseRad + phase + obj.rawImage);

                if strcmp(obj.spatialClass, 'squarewave')
                    g = sign(g);
                end

                g = obj.contrast * g;

                % Deal with chromatic gratings.
                if ~strcmp(obj.chromaticClass, 'achromatic')
                    for m = 1 : 3
                        g(:,:,m) = obj.colorWeights(m) * g(:,:,m);
                    end
                end
                g = uint8(255*(obj.backgroundIntensity * g + obj.backgroundIntensity));
            end
        end

        function setRawImage(obj)
            downsamp = 3;
            sz = ceil(sqrt(obj.canvasSize(1)^2 + obj.canvasSize(2)^2));
            [x,y] = meshgrid(...
                linspace(-sz/2, sz/2, sz/downsamp), ...
                linspace(-sz/2, sz/2, sz/downsamp));

            % Center the stimulus.
            x = x + obj.centerOffset(1);
            y = y + obj.centerOffset(2);

            % Get the radial calculation.
            r = sqrt(x.^2 + y.^2);

            x = x / min(obj.canvasSize) * 2 * pi;
            y = y / min(obj.canvasSize) * 2 * pi;

            % Calculate the orientation in radians.
            rotRads = obj.orientation / 180 * pi;

            % Calculate the raw grating image.
            img = (cos(0)*x + sin(0) * y) * obj.spatialFreq;
            obj.rawImage = img(1,:);
%             obj.rawImage = (cos(rotRads) * x + sin(rotRads) * y) * obj.spatialFreq;

            if ~strcmp(obj.chromaticClass, 'achromatic')
                obj.rawImage = repmat(obj.rawImage, [1 1 3]);
            end
        end

        % This is a method of organizing stimulus parameters.
        function organizeParameters(obj)

            % Create the matrix of bar positions.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.spatialFreqs));

            % Get the array of radii.
            freqs = obj.spatialFreqs(:) * ones(1, numReps);
            freqs = freqs(:)';

            % Deal with the parameter order if it is random order.
            if ( obj.randomOrder )
                epochSyntax = randperm( obj.numberOfAverages );
            else
                epochSyntax = 1 : obj.numberOfAverages;
            end

            % Copy the radii in the correct order.
            freqs = freqs( epochSyntax );

            % Copy to spatial frequencies.
            obj.spatialFrequencies = freqs;

        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

            % Set the current spatial frequency.
            obj.spatialFreq = obj.spatialFrequencies( obj.numEpochsCompleted+1 );

            % Set the current orientation
            if length(obj.orientations) == 1
                obj.orientation = obj.orientations;
            else%
                obj.orientation = obj.orientations(ceil((obj.numEpochsCompleted + 1) / length(obj.spatialFreqs)));
            end

            % Set up the raw image.
            obj.setRawImage();

            % Add the spatial frequency to the epoch.
            epoch.addParameter('spatialFreq', obj.spatialFreq);
            epoch.addParameter('orientation', obj.orientation);

            % Save out the cone/rod contrasts.
            epoch.addParameter('lContrast', obj.coneContrasts(1));
            epoch.addParameter('mContrast', obj.coneContrasts(2));
            epoch.addParameter('sContrast', obj.coneContrasts(3));
            epoch.addParameter('rodContrast', obj.coneContrasts(4));
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end
