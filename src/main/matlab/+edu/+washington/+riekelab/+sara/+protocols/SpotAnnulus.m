classdef SpotAnnulus < edu.washington.riekelab.sara.protocols.SaraStageProtocol
% TODO cleanup
    
    properties
        amp                             % Output amplifier
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 2500                 % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        contrast = 0.5                  % Contrast (0-1; -1-1 for pulse)
        temporalFrequency = 2.0         % Modulation frequency (Hz)
        radii = round(17.9596 * 10.^(-0.301:0.301/3:1.4047)) % Inner radius in pixels.
        lightMean = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y) 
        temporalClass = 'SINEWAVE'      % Sinewave or squarewave?
        chromaticity = 'ACHROMATIC'   % Spot color
        stimulusClass = 'spot'          % Stimulus class
        numberOfAverages = uint16(18)   % Number of epochs
    end
    
    properties (Hidden = true)
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
                'edu.washington.riekelab.sara.types.ModulationType'))
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
                'edu.washington.riekelab.sara.types.ChromaticityType'))
        stimulusClassType = symphonyui.core.PropertyType('char', 'row',...
            {'spot', 'annulus'})
        currentRadius
        sequence
    end
    
     % Analysis properties
    properties (Hidden = true)
        xaxis
        F1Amp
        F1Phase
        repsPerX
    end
    
    properties (Hidden = true, Transient = true)
        analysisFigure
    end

    properties (Constant = true, Hidden = true)
        DISPLAYNAME = 'SpotAnnulus'
        VERSION = 2
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp),...
                'stimTrace', getLightStim(obj, 'modulation'));
            
            if ~strcmp(obj.analysisMode, 'none')
                obj.showFigure('edu.washington.riekelab.sara.figures.sMTFFigure', ...
                    obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime,...
                    'onlineAnalysis',obj.getOnlineAnalysis,...
                    'temporalType', obj.temporalClass,...
                    'spatialType', obj.stimulusClass, ...
                    'xName', 'radius', 'xaxis', unique(obj.radii), ...
                    'temporalFrequency', obj.temporalFrequency);
            end
            
            if strcmp(obj.stageClass, 'LightCrafter')
                obj.chromaticity = 'achromatic';
            end
            
            obj.organizeParameters();
            
            obj.setLEDs();
        end

        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
            
            spot = stage.builtin.stimuli.Ellipse();
            if strcmp(obj.stimulusClass, 'annulus')
                spot.radiusX = min(obj.canvasSize/2);
                spot.radiusY = min(obj.canvasSize/2);
            else
                spot.radiusX = obj.um2pix(obj.currentRadius);
                spot.radiusY = obj.um2pix(obj.currentRadius);
            end
            spot.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            if obj.lightMean == 0
                spot.color = obj.contrast;
            end
            
            % Add the stimulus to the presentation.
            p.addStimulus(spot);
            
            % Add an center mask if it's an annulus.
            if strcmp(obj.stimulusClass, 'annulus')
                mask = stage.builtin.stimuli.Ellipse();
                mask.radiusX = obj.um2pix(obj.currentRadius);
                mask.radiusY = obj.um2pix(obj.currentRadius);
                mask.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
                mask.color = obj.lightMean; 
                p.addStimulus(mask);
            end
            
            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);

            % Control the spot color.
            if obj.lightMean > 0
                if strcmp(obj.stageClass, 'LcrRGB')
                    if strcmp(obj.temporalClass, 'SINEWAVE')
                        colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                        @(state)getSpotColorLcrRGB(obj, state));
                    p.addController(colorController);
                    elseif strcmp(obj.temporalClass, 'SQUAREWAVE')
                        colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                        @(state)getSpotColorLcrRGBSqwv(obj, state));
                    p.addController(colorController);
                    end
                elseif strcmp(obj.stageClass, 'Video') && ~strcmp(obj.chromaticity, 'ACHROMATIC')
                    if strcmp(obj.temporalClass, 'SINEWAVE')
                        colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                            @(state)getSpotColorVideo(obj, state.time - obj.preTime * 1e-3));
                        p.addController(colorController);
                    elseif strcmp(obj.temporalClass, 'SQUAREWAVE')
                        colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                            @(state)getSpotColorVideoSqwv(obj, state.time - obj.preTime * 1e-3));
                        p.addController(colorController);
                    end
                else
                    if strcmp(obj.temporalClass, 'SINEWAVE')
                        colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                            @(state)getSpotAchromatic(obj, state.time - obj.preTime * 1e-3));
                        p.addController(colorController);
                    elseif strcmp(obj.temporalClass, 'SQUAREWAVE')
                        colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                            @(state)getSpotAchromaticSqwv(obj, state.time - obj.preTime * 1e-3));
                        p.addController(colorController);
                    end
                end
            end
            
            function c = getSpotColorVideo(obj, time)
                c = obj.contrast * obj.ledWeights * sin(obj.temporalFrequency*time*2*pi) * obj.lightMean + obj.lightMean;
            end
            
            function c = getSpotColorVideoSqwv(obj, time)
                c = obj.contrast * obj.ledWeights * sign(sin(obj.temporalFrequency*time*2*pi)) * obj.lightMean + obj.lightMean;
            end
            
            function c = getSpotAchromatic(obj, time)
                c = obj.contrast * sin(obj.temporalFrequency*time*2*pi) * obj.lightMean + obj.lightMean;
            end
            
            function c = getSpotAchromaticSqwv(obj, time)
                c = obj.contrast * sign(sin(obj.temporalFrequency*time*2*pi)) * obj.lightMean + obj.lightMean;
            end
            
            function c = getSpotColorLcrRGB(obj, state)
                if state.pattern == 0
                    c = obj.contrast * obj.ledWeights(1) * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi) * obj.lightMean + obj.lightMean;
                elseif state.pattern == 1
                    c = obj.contrast * obj.ledWeights(2) * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi) * obj.lightMean + obj.lightMean;
                else
                    c = obj.contrast * obj.ledWeights(3) * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi) * obj.lightMean + obj.lightMean;
                end
            end
            
            function c = getSpotColorLcrRGBSqwv(obj, state)
                if state.pattern == 0
                    c = obj.contrast * obj.ledWeights(1) * sign(sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)) * obj.lightMean + obj.lightMean;
                elseif state.pattern == 1
                    c = obj.contrast * obj.ledWeights(2) * sign(sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)) * obj.lightMean + obj.lightMean;
                else
                    c = obj.contrast * obj.ledWeights(3) * sign(sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)) * obj.lightMean + obj.lightMean;
                end
            end
        end
        
        % This is a method of organizing stimulus parameters.
        function organizeParameters(obj)
            
            % Create the matrix of bar positions.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.radii));
            
            % Get the array of radii.
            rads = obj.radii(:) * ones(1, numReps);
            rads = rads(:)';
            
            % Copy the radii in the correct order.
            rads = rads( 1 : obj.numberOfAverages );
            
            % Copy to spatial frequencies.
            obj.sequence = rads;
            
            obj.xaxis = unique(obj.radii);
            obj.F1Amp = zeros(size(obj.xaxis));
            obj.F1Phase = zeros(size(obj.xaxis));
            obj.repsPerX = zeros(size(obj.xaxis));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);
            
            
            % Set the current radius
            obj.currentRadius = obj.sequence( obj.numEpochsCompleted+1 );

            % Add the radius to the epoch.
            if strcmp(obj.stimulusClass, 'annulus')
                epoch.addParameter('outerRadius', min(obj.canvasSize/2));
            end
            epoch.addParameter('radius', obj.currentRadius);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
end