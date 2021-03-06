classdef ConeGaussianNoise < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    
    properties
        amp
        preTime = 250							% Stimulus leading duration (ms)
        stimTime = 10000						% Stimulus duration (ms)
        tailTime = 250							% Stimulus trailing duration (ms)
        outerRadius = 1500					    % Spot radius in pixels
        innerRadius = 0							% For annulus (pix)
        stDev = 0.3								% Noise standard deviation
        randomSeed = true						% Repeating or random
        frameDwell = 1							% Frames per stim
        lightMean = 0.5				            % Mean light level (0-1)
        centerOffset = [0 0]					% Center offset in pixels (x,y)
    end
    
    properties(Hidden = true)
        % protocol properties
        ampType
        
        % epoch properties set by protocol
        seed
        noiseStream
        
        % epoch properties set by figure
        currentCone       
    end
    
    properties (Hidden = true, Dependent = true)
        totalNumEpochs
    end
    
    properties (Hidden = true, Transient = true)
        analysisFigure
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end % didSetRig
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            obj.assignSpatialType();
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp),...
                'stimTrace',  getLightStim(obj, 'pulse'));

            obj.analysisFigure = obj.showFigure(...
                'edu.washington.riekelab.sara.figures.ConeFilterFigure',...
                obj.rig.getDevice(obj.amp), [], obj.rig.getDevice('FilterWheel'),...
                obj.preTime, obj.stimTime,'recordingType', obj.getOnlineAnalysis,... 
                'stDev', obj.stDev, 'frameDwell', obj.frameDwell);
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
            
            spot = stage.builtin.stimuli.Ellipse();
            if obj.innerRadius == 0 % spot
                spot.radiusX = obj.um2pix(obj.outerRadius);
                spot.radiusY = obj.um2pix(obj.outerRadius);
            else % annulus
                spot.radiusX = min(obj.canvasSize/2);
                spot.radiusY = min(obj.canvasSize/2);
            end
            spot.position = obj.canvasSize/2 + obj.um2pix(centerOffset);
            
            % Add the stimulus to the presentation.
            p.addStimulus(spot);
            
            % Add an center mask if it's an annulus.
            if obj.innerRadius ~= 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end
            
            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            % Control the spot color.
            colorController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));
            p.addController(colorController);
            
            function c = getSpotColor(obj, ~)
                c = obj.stDev * (obj.noiseStream.randn * obj.ledWeights) * obj.lightMean + obj.lightMean;
            end % getSpotColor
        end % createPresentation
        
        function prepareEpoch(obj, epoch)
            % pull stimulus info from figure
            obj.currentCone = obj.analysisFigure.nextCone(1);
            
            fprintf('protocol - running %s-iso\n', obj.currentCone);
            coneName = obj.extendName(obj.currentCone);
            epoch.addParameter('chromaticity', coneName);
            
            obj.setLEDs(coneName);
            
            if obj.randomSeed
                obj.seed = RandStream.shuffleSeed;
            else
                obj.seed = 1;
            end
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);           
            epoch.addParameter('seed', obj.seed);
            
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);
        end % prepareEpoch
        
        function totalNumEpochs = get.totalNumEpochs(obj) %#ok<MANU>
            totalNumEpochs = inf;
        end % totalNumEpochs
        
        function tf = shouldContinuePreparingEpochs(obj)
            if ~isvalid(obj.analysisFigure)
                tf = false;
            else
                tf = ~obj.analysisFigure.protocolShouldStop;
            end
        end % shouldContinuePreparingEpochs
        
        function tf = shouldContinueRun(obj)
            if ~isvalid(obj.analysisFigure)
                tf = false;
            else
                tf = ~obj.analysisFigure.protocolShouldStop;
            end
        end % shouldContinueRun
    end % methods
end % classdef
