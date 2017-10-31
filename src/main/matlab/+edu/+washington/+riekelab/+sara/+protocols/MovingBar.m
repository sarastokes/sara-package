classdef MovingBar < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    properties
        amp                             % Output amplifier
        preTime = 500                   % Bar leading duration (ms)
        stimTime = 2500                 % Bar duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        directions = 0:30:330           % Bar angle (deg)
        speed = 600                     % Bar speed (pix/sec)
        contrast = 1.0                  % Max light intensity (0-1)
        barSize = [120, 240]            % Bar size (x,y) in microns
        lightMean = 0.0       % Background light intensity (0-1)
        chromaticity = 'achromatic'
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        innerRadius = 0                 % Inner mask radius in pixels.
        outerRadius = 570               % Outer mask radius in pixels.
        randomOrder = true              % Random direction order?
        numberOfAverages = uint16(36)   % Number of epochs
    end
    
    properties (Hidden = true)
        ampType
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
        sequence
        direction
        directionRads
        intensity
    end

    properties (Constant = true, Hidden = true)
        DISPLAYNAME = 'Moving Bar'
        VERSION = 2
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            colors = pmkmp(length(obj.directions), 'CubicYF');
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',... 
                obj.rig.getDevice(obj.amp), 'stimTrace', getLightStim(obj, 'pulse'));
            
            obj.showFigure('edu.washington.riekelab.sara.figures.MeanResponseFigure', ...
                obj.rig.getDevice(obj.amp), 'onlineAnalysis', obj.getOnlineAnalysis(),...
                'sweepColor', colors, 'groupBy',{'direction'});
            
            if ~strcmp(obj.getOnlineAnalysis(), 'none')
                obj.showFigure('edu.washington.riekelab.sara.figures.DirectionFigure', ...
                    obj.rig.getDevice(obj.amp), 'recordingMode', obj.getOnlineAnalysis(),...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                    'directions', unique(obj.directions));
            end
                       
            % Check the outer mask radius.
            if obj.um2pix(obj.outerRadius) > min(obj.canvasSize/2)
                obj.outerRadius = min(obj.canvasSize/2) * obj.muPerPixel;
            end
            
            obj.organizeParameters();
            
            if strcmp(obj.stageClass, 'Video')
                % Set the LED weights.
                obj.setLEDs();
                if obj.lightMean > 0
                    obj.intensity = obj.lightMean * (obj.contrast * obj.ledWeights) + obj.lightMean;
                else
                    if isempty(strfind(obj.chromaticity, 'iso'))
                        obj.intensity = obj.ledWeights * obj.contrast;
                    else
                        obj.intensity = obj.contrast * (0.5 * obj.ledWeights + 0.5);
                    end
                end
            else
                if obj.lightMean > 0
                    obj.intensity = obj.lightMean * obj.contrast + obj.lightMean;
                else
                    obj.intensity = obj.contrast;
                end
            end
        end
        
        function organizeParameters(obj)
            % Calculate the number of repetitions of each annulus type.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.directions));
            
            % Set the sequence.
            if obj.randomOrder
                obj.sequence = zeros(length(obj.directions), numReps);
                for k = 1 : numReps
                    obj.sequence(:,k) = obj.directions(randperm(length(obj.directions)));
                end
            else
                obj.sequence = obj.directions(:) * ones(1, numReps);
            end
            obj.sequence = obj.sequence(:)';
            obj.sequence = obj.sequence(1 : obj.numberOfAverages);
        end
        
        function p = createPresentation(obj)

            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
            
            rect = stage.builtin.stimuli.Rectangle();
            rect.size = obj.um2pix(obj.barSize);
            rect.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            rect.orientation = obj.direction;
            if strcmp(obj.stageClass, 'Video')
                rect.color = obj.intensity;
            else
                rect.color = obj.intensity(1);
            end
            
            % Add the stimulus to the presentation.
            p.addStimulus(rect);
            
            barVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(barVisible);
            
            % Bar position controller
            barPosition = stage.builtin.controllers.PropertyController(rect, 'position', ...
                @(state)motionTable(obj, state.time - obj.preTime*1e-3));
            p.addController(barPosition);
            
            if strcmp(obj.stageClass, 'LcrRGB')
                % Control the spot color.
                colorController = stage.builtin.controllers.PropertyController(rect, 'color', ...
                    @(state)getSpotColor(obj, state));
                p.addController(colorController);
            end

            % Create the inner mask.
            if (obj.innerRadius > 0)
                p.addStimulus(obj.makeInnerMask());
            end
            
            % Create the outer mask.
            if (obj.outerRadius > 0)
                p.addStimulus(obj.makeOuterMask());
            end
            
            function p = motionTable(obj, time)
                % Calculate the increment with time.  
                inc = time * obj.speed - obj.outerRadius - obj.barSize(1)/2 ;
                
                p = [cos(obj.directionRads) sin(obj.directionRads)]...
                .* (inc*ones(1,2)) + obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            end
            
            function c = getSpotColor(obj, state)
                if state.pattern == 0
                    c = obj.intensity(1);
                elseif state.pattern == 1
                    c = obj.intensity(2);
                else
                    c = obj.intensity(3);
                end
            end
        end
        
        function mask = makeOuterMask(obj)
            mask = stage.builtin.stimuli.Rectangle();
            mask.color = obj.lightMean;
            mask.position = obj.canvasSize/2 + obj.centerOffset;
            mask.orientation = 0;
            mask.size = 2 * max(obj.canvasSize) * ones(1,2);
            sc = obj.outerRadius*2 / (2*max(obj.canvasSize));
            m = stage.core.Mask.createCircularAperture(sc);
            mask.setMask(m);
        end
        
        function mask = makeInnerMask(obj)
            mask = stage.builtin.stimuli.Ellipse();
            mask.radiusX = obj.innerRadius;
            mask.radiusY = obj.innerRadius;
            mask.color = obj.lightMean;
            mask.position = obj.canvasSize/2 + obj.centerOffset;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);
            
            % Get the current bar direction.
            obj.direction = obj.sequence(obj.numEpochsCompleted+1);
            obj.directionRads = obj.direction / 180 * pi;
            
            epoch.addParameter('direction', obj.direction);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end