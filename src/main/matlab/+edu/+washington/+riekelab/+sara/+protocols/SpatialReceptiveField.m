classdef SpatialReceptiveField < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    % SSP 6Nov2016 - added aperture to properties, createPresentation lines 312-320
    % SSP 21Feb2017 - added bar noise option, cleaned up protocol

    properties
        amp                              % Output amplifier
        preTime = 500                    % Noise leading duration (ms)
        stimTime = 10000                 % Noise duration (ms)
        tailTime = 500                   % Noise trailing duration (ms)
        stixelSize = 25                  % Edge length of stixel (pix)
        chromaticity = 'achromatic'      % Chromatic type
        noiseClass = 'BINARY'            % Noise class (binary, gaussian, ternary)
        frameDwell = 1                   % Number of frames to display any image
        centerOffset = [0,0]             % Center offset in pixels (x,y)
        outerRadius = 0                  % Mask radius (um).
        innerRadius = 0                  % Aperture radius (um)
        stdev = 0.3                      % SD for Gaussian noise only
        intensity = 1.0                  % Max light intensity (0-1)
        lightMean = 0.5                  % Background light intensity (0-1)
        boardClass = 'checker'           % checkerboard or x/y bar noise
        useRandomSeed = true             % Random seed (bool)
        numberOfAverages = uint16(50)    % Number of epochs
    end

    properties (Hidden = true)      
        ampType
        noiseClassType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
                'edu.washington.riekelab.sara.types.NoiseType'))
        boardClassType = symphonyui.core.PropertyType('char', 'row',...
            {'checker', 'xBar', 'yBar'})
        chromaticityType = symphonyui.core.PropertyType('char','row',...
            {'achromatic', 'RGB', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
        
        noiseStream
        numXChecks
        numYChecks
        correctedIntensity
        correctedMean
        seed
        frameValues
        backgroundFrame
        strf
        spatialRF
    end

    properties (Constant = true, Hidden = true)
        DISPLAYNAME = 'SpatialReceptiveField';
        VERSION = 3;
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                obj.chromaticity = 'achromatic';
            end

            obj.assignSpatialType();

            % Calculate the corrected intensity.
            obj.correctedIntensity = obj.intensity * 255;
            obj.correctedMean = obj.lightMean * 255;

            % Calculate the number of X/Y checks.
            obj.numXChecks = ceil(obj.canvasSize(1)/obj.stixelSize);
            obj.numYChecks = ceil(obj.canvasSize(2)/obj.stixelSize);
            
            % Override check number for bar noise
            switch obj.boardClass
                case 'xBar'
                    obj.numYChecks = 1;
                case 'yBar'
                    obj.numXChecks = 1;
            end

            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp), 'stimTrace', getLightStim(obj, 'pulse'));

            if ~strcmp(obj.recordingMode, 'none')
                obj.showFigure('edu.washington.riekelab.sara.figures.ReceptiveFieldFigure',...
                    obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime, obj.stixelSize,...
                    [obj.numXChecks, obj.numYChecks],...
                    'onlineAnalysis', obj.getOnlineAnalysis(),...
                    'noiseClass', lower(obj.noiseClass),...
                    'chromaticity', obj.chromaticity,...
                    'frameRate', obj.frameRate,...
                    'frameDwell', obj.frameDwell,...
                    'masks', [obj.innerRadius, obj.outerRadius]);
            end

            % Get the frame values for repeating epochs.
            if ~obj.useRandomSeed
                obj.seed = 1;
                obj.getFrameValues();
            end

            obj.setLEDs;
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);

            % Create your noise image.
            if strcmpi(obj.noiseClass, 'binary')
                imageMatrix = uint8((rand(obj.numYChecks, obj.numXChecks)>0.5) * obj.correctedIntensity);
            else
                imageMatrix = uint8((0.3*randn(obj.numYChecks, obj.numXChecks) * obj.lightMean + obj.lightMean)*255);
            end
            checkerboard = stage.builtin.stimuli.Image(imageMatrix);
            checkerboard.position = obj.canvasSize / 2;
            switch obj.boardClass
                case 'checker'
                    checkerboard.size = [obj.numXChecks, obj.numYChecks] * obj.stixelSize;
                case 'xBar'
                    checkerboard.size = [obj.numXChecks, obj.numXChecks] * obj.stixelSize;
                case 'yBar'
                    checkerboard.size = [obj.numYChecks, obj.numYChecks] * obj.stixelSize;
            end

            % Set the minifying and magnifying functions to form discrete
            % stixels.
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);

            % Add the stimulus to the presentation.
            p.addStimulus(checkerboard);

            gridVisible = stage.builtin.controllers.PropertyController(...
                checkerboard, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(gridVisible);

            % Calculate preFrames and stimFrames
            preF = floor(obj.preTime/1000 * obj.frameRate);
            stimF = floor(obj.stimTime/1000 * obj.frameRate);

            if strcmpi(obj.chromaticity, 'achromatic')
                imgController = stage.builtin.controllers.PropertyController(...
                    checkerboard, 'imageMatrix',...
                    @(state)setAchromaticStixels(obj, state.frame - preF, stimF));
            else
                imgController = stage.builtin.controllers.PropertyController(...
                    checkerboard, 'imageMatrix',...
                    @(state)setChromaticStixels(obj, state.frame - preF, stimF));
            end
            p.addController(imgController);

            % Add an center mask if it's an annulus.
            if obj.innerRadius > 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end

            if obj.outerRadius > 0
                aperture = obj.makeAperture();
                p.addStimulus(aperture);
            end
            
            function s = setChromaticStixels(obj, frame, stimFrames)
                if frame > 0 && frame <= stimFrames
                    index = ceil(frame/obj.frameDwell);
                    s = squeeze(obj.frameValues(index,:,:,:));
                else
                    s = obj.backgroundFrame;
                end
            end
            
            function s = setAchromaticStixels(obj, frame, stimFrames)
                if frame > 0 && frame <= stimFrames
                    index = ceil(frame/obj.frameDwell);
                    s = squeeze(obj.frameValues(index,:,:));
                else
                    s = obj.backgroundFrame;
                end
            end
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Deal with the seed.
            if obj.useRandomSeed
                obj.seed = RandStream.shuffleSeed;
                % Get the frame values for the epoch.
                obj.getFrameValues();
            end
            epoch.addParameter('seed', obj.seed);
            epoch.addParameter('numXChecks', obj.numXChecks);
            epoch.addParameter('numYChecks', obj.numYChecks);
        end

        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end

        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
    
    methods (Access = private)
        function getFrameValues(obj)
            % Get the number of frames.
            numFrames = floor(obj.stimTime/1000 * obj.frameRate / obj.frameDwell);

            % Seed the random number generator.
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);

            % Deal with the noise type.
            % {binary, ternary, gaussian}, {RGB, achromatic, cone-iso}
            if strcmpi(obj.noiseClass, 'binary')
                if strcmpi(obj.chromaticity, 'RGB')
                    M = obj.noiseStream.rand(numFrames,obj.numYChecks,obj.numXChecks,3) > 0.5;
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks,3));
                elseif strcmpi(obj.chromaticity, 'achromatic')
                    M = obj.noiseStream.rand(numFrames, obj.numYChecks,obj.numXChecks) > 0.5;
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks));
                else
                    tmp = repmat(obj.noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks) > 0.5,[1 1 1 3]);
                    M = zeros(size(tmp));
                    tmp = 2*tmp-1; % Convert to contrast.
                    for k = 1 : 3
                        M(:,:,:,k) = obj.ledWeights(k)*tmp(:,:,:,1);
                    end
                    M = 0.5*M+0.5;
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks,3));
                end
                obj.frameValues = uint8(obj.intensity*255*M);
            
            elseif strcmpi(obj.noiseClass, 'ternary')
                if strcmpi(obj.chromaticity, 'RGB')
                    eta = double(obj.noiseStream.randn(numFrames,obj.numYChecks, obj.numXChecks,3) > 0)*2 - 1;
                    M = (eta + circshift(eta, [0, 1, 1])) / 2;
                    M = 0.5*M+0.5;
                    obj.backgroundFrame = uint8(obj.lightMean*ones(obj.numYChecks,obj.numXChecks,3));
                elseif strcmpi(obj.chromaticity, 'achromatic')
                    eta = double(obj.noiseStream.randn(numFrames,obj.numYChecks, obj.numXChecks) > 0)*2 - 1;
                    M = (eta + circshift(eta, [0, 1, 1])) / 2;
                    M = 0.5*M+0.5;
                    obj.backgroundFrame = uint8(obj.lightMean*ones(obj.numYChecks,obj.numXChecks));
                else
                    eta = double(obj.noiseStream.randn(numFrames,obj.numYChecks, obj.numXChecks) > 0)*2 - 1;
                    tmp = repmat((eta + circshift(eta, [0, 1, 1])) / 2,[1 1 1 3]);
                    M = zeros(size(tmp));
                    for k = 1 : 3
                        M(:,:,:,k) = obj.ledWeights(k)*tmp(:,:,:,1);
                    end
                    M = obj.lightMean*M+obj.lightMean;
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks,3));
                end
                obj.frameValues = uint8(obj.intensity*255*M);
                
            else % GAUSSIAN
                if strcmpi(obj.chromaticity, 'RGB')
                    M = uint8((obj.stdev * obj.intensity*obj.noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks, 3) * 0.5 + 0.5)*255);
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks,3));
                elseif strcmpi(obj.chromaticity, 'achromatic')
                    M = uint8((obj.stdev * obj.intensity*obj.noiseStream.rand(numFrames, obj.numYChecks, obj.numXChecks) * 0.5 + 0.5)*255);
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks));
                else
                    tmp = repmat(obj.stdev * obj.noiseStream.randn(numFrames, obj.numYChecks, obj.numXChecks),[1 1 1 3]);
                    M = zeros(size(tmp));
                    for k = 1 : 3
                        M(:,:,:,k) = obj.ledWeights(k)*tmp;
                    end
                    M = uint8(255*(0.5*M+0.5));
                    obj.backgroundFrame = uint8(obj.lightMean * ones(obj.numYChecks,obj.numXChecks,3));
                end
                obj.frameValues = M;
            end
        end
    end
end
