classdef FullChromaticGrating < edu.washington.riekelab.sara.protocols.SaraStageProtocol
% Chromatic grating but with my response figures and option for mask

% 12Sep2016 - copied mike's ChromaticGrating protocol, added working online analysis & response w/ stim figure
% 7Dec2016 - new F1Figure test
% 20Dec2016 - changed to protocol focused on running and analyzing multiple orientations (CRF later)

    properties
        amp                             % Output amplifier
        preTime = 250                   % Grating leading duration (ms)
        stimTime = 4000                 % Grating duration (ms)
        tailTime = 250                  % Grating trailing duration (ms)
        waitTime = 1000                 % Grating wait duration (ms)
        contrast = 0.7                 % Grating contrast (0-1)
        orientations = [0 90 45 135 270 180 225 315]           % Grating orientation (deg)
        spatialFreqs = 10.^(-0.301:0.301/3:1.4047)        % Spatial frequency (cyc/short axis of screen)
        temporalFrequency = 2.0         % Temporal frequency (Hz)
        spatialPhase = 0.0              % Spatial phase of grating (deg)
        lightMean = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        innerRadius = 0              % Aperture radius in pixels.
        outerRadius = 0                  % Mask radius in pixels
        spatialClass = 'sinewave'       % Spatial type (sinewave or squarewave)
        temporalClass = 'drifting'      % Temporal type (drifting or reversing)
        chromaticClass = 'achromatic'   % Chromatic type
        randomOrder = false             % Run the sequence in random order?
        numberOfAverages = uint16(144)   % spatialFreqs * orientations
    end

    properties (Hidden)
        ampType
        spatialClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave'})
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'drifting', 'reversing'})
        chromaticClassType = symphonyui.core.PropertyType('char', 'row',...
            {'achromatic', 'S-iso','M-iso','L-iso', 'LM-iso', 'yellow'})
        rawImage
        params
        spatialPhaseRad % The spatial phase in radians.
        spatialFrequencies
        spatialFreq % The current spatial frequency for the epoch
        orientation % The current orientation
        coneContrasts
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            obj.assignSpatialType();

            if length(obj.orientations)>1
                if double(obj.numberOfAverages) ~= (length(obj.spatialFreqs)*length(obj.orientations))
                    warndlg(sprintf('number of averages might be an issue - should be %u',...
                        length(obj.spatialFreqs)*length(obj.orientations)));
                end
            % elseif length(obj.contrasts) > 1
            %     if double(obj.numberOfAverages) ~= (length(obj.spatialFreqs)* length(obj.contrasts))
            %         warndlg(sprintf('number of averages might be an issue - should be %u',...
            %             length(obj.spatialFreqs)* length(obj.orientations)));
            %     end
            end

            obj.setLEDs();

            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp),...
                'stimTrace', getLightStim(obj, 'modulation'),...
                'stimColor', stimColor);

            % Calculate the spatial phase in radians.
            obj.spatialPhaseRad = obj.spatialPhase / 180 * pi;

            % Organize stimulus and analysis parameters.
            obj.organizeParameters();

            if ~strcmp(obj.onlineAnalysis,'none')
                if length(obj.orientations) > 1
                    obj.showFigure('edu.washington.riekelab.sara.figures.GratingOrientationFigure',...
                        obj.rig.getDevice(obj.amp), obj.getOnlineAnalysis(),...
                        obj.preTime, obj.stimTime, obj.temporalFrequency,...
                        obj.spatialFreqs,  obj.chromaticClass,...
                        'waitTime', obj.waitTime, 'orientations', obj.orientations);
                else
                    obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure',...
                        obj.rig.getDevice(obj.amp),...
                        obj.spatialFreqs, obj.onlineAnalysis, obj.preTime, obj.stimTime,...
                        'temporalFrequency', obj.temporalFrequency,...
                        'plotColor', stimColor, 'waitTime', obj.waitTime);
                end
            end
        end % prepareRun

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            % Create the grating.
            grate = stage.builtin.stimuli.Image(uint8(0 * obj.rawImage));
            grate.position = obj.canvasSize / 2;
            grate.size = ceil(sqrt(obj.canvasSize(1)^2 + obj.canvasSize(2)^2))*ones(1,2);
            grate.orientation = obj.orientation;
            grate.setMinFunction(GL.NEAREST);
            grate.setMagFunction(GL.NEAREST);
            p.addStimulus(grate);

            % Make the grating visible only during the stimulus time.
            grateVisible = stage.builtin.controllers.PropertyController(grate, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(grateVisible);

            % Create center mask
            if obj.innerRadius > 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end

            % Create aperture
            if obj.outerRadius > 0
                aperture = obj.makeAperture();
                p.addStimulus(aperture);
            end

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
                        g(:,:,m) = obj.ledWeights(m) * g(:,:,m);
                    end
                end
                g = uint8(255*(obj.lightMean * g + obj.lightMean));
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
                        g(:,:,m) = obj.ledWeights(m) * g(:,:,m);
                    end
                end
                g = uint8(255*(obj.lightMean * g + obj.lightMean));
            end
        end

        function setRawImage(obj)
            downsamp = 3;
            sz = ceil(sqrt(obj.canvasSize(1)^2 + obj.canvasSize(2)^2));
            [x,y] = meshgrid(...
                linspace(-sz/2, sz/2, sz/downsamp), ...
                linspace(-sz/2, sz/2, sz/downsamp));

            % Center the stimulus.
            x = x + obj.um2pix(obj.centerOffset(1));
            y = y + obj.um2pix(obj.centerOffset(2));

            x = x / min(obj.canvasSize) * 2 * pi;
            y = y / min(obj.canvasSize) * 2 * pi;

            % Calculate the raw grating image.
            img = (cos(0)*x + sin(0) * y) * obj.spatialFreq;
            obj.rawImage = img(1,:);

            if ~strcmp(obj.chromaticClass, 'achromatic')
                obj.rawImage = repmat(obj.rawImage, [1 1 3]);
            end
        end

        % This is a method of organizing stimulus parameters.
        function organizeParameters(obj)

            % Create the matrix of bar positions.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.spatialFreqs));

            % Get the array of spatial frequencies
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
            obj.params.spatialFrequencies = freqs;

            % orientation matrix
            obj.params.orientations = repelem(obj.orientations, length(obj.spatialFreqs));

            % contrast matrix
            % obj.params.contrasts = repelem(obj.contrasts, length(obj.spatialFreqs));
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Set the current spatial frequency.
            obj.spatialFreq = obj.params.spatialFrequencies(obj.numEpochsCompleted+1);

            % Set the current orientation
            obj.orientation = obj.params.orientations(obj.numEpochsCompleted+1);

            % Set the current contrast
            % obj.contrast = obj.params.contrasts(obj.numEpochsCompleted+1);

            % Set up the raw image.
            obj.setRawImage();

            % Add the spatial frequency to the epoch.
            epoch.addParameter('spatialFreq', obj.spatialFreq);
            epoch.addParameter('orientation', obj.orientation);
            epoch.addParameter('contrast', obj.contrast);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end
