classdef Edge < edu.washington.riekelab.sara.protocols.SaraStageProtocol

    properties
        amp
        preTime = 250
        stimTime = 2500
        tailTime = 250
        centerOffset = [0, 0]
        contrast = 1
        outerRadius = 0
        innerRadius = 0
        lightMean = 0.5
        direction = 'east'
        chromaticity = 'achromatic'
        numberOfAverages = uint16(3)
    end

    properties (Hidden = true)
    	ampType
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso', 'yellow', 'red', 'green', 'blue'})
        directionType = symphonyui.core.PropertyType('char', 'row',...
        	{'north', 'south', 'east', 'west'})
        speed
    end

    properties (Constant = true, Hidden = true)
        DISPLAYNAME = 'Moving Edge';
        VERSION = 1;
    end

    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end % didSetRig

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            % Return the stimulus speeds in pix/sec
            obj.speed = [obj.canvasSize(1)/(obj.stimTime * 1e-3),...
                obj.canvasSize(2)/(obj.stimTime * 1e-3)];
            fprintf('stimulus speeds are %.2f %.2f\n', obj.speed);

            obj.assignSpatialType();
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp));

        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean); 
            
            rect = stage.builtin.stimuli.Rectangle();
            p.addStimulus(rect);     
             
            visibleController = stage.builtin.controllers.PropertyController(rect, 'visible',...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);    
            colorController = stage.builtin.controllers.PropertyController(rect, 'color',...
                @(state)getRectColor(obj, state.time - obj.preTime * 1e-3));
            sizeController = stage.builtin.controllers.PropertyController(rect, 'size',...
                @(state)getRectSize(obj, state.time - obj.preTime * 1e-3));
            positionController = stage.builtin.controllers.PropertyController(rect, 'position',...
                @(state)getRectPosition(obj, state.time - obj.preTime * 1e-3));   

            p.addController(visibleController);
            p.addController(colorController);
            p.addController(sizeController);
            p.addController(positionController);

            if obj.innerRadius > 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end
            

            if obj.outerRadius > 0
                aperture = obj.makeAperture();
                p.addStimulus(aperture);
            end
            
            % Property controller functions
            function c = getRectColor(obj, ~)
                c = obj.contrast *  obj.ledWeights * obj.lightMean * obj.contrast + obj.lightMean;
            end
            
            function p = getRectPosition(obj, time)
                switch obj.direction
                    case 'north'
                        p = [obj.canvasSize(1)/2, (obj.speed(2) * time)/2];
                    case 'south'
                        p = [obj.canvasSize(1)/2, obj.canvasSize(2) - (obj.speed(2) * time)/2];
                    case 'east'
                        p = [(obj.speed(1) * time)/2, obj.canvasSize(2)/2];
                    case 'west'
                        p = [obj.canvasSize(1) - (obj.speed(1) * time)/2, obj.canvasSize(2)/2];
                end
            end
            
            function s = getRectSize(obj, time)
                switch obj.direction
                    case {'north', 'south'}
                        s = [obj.canvasSize(1), (obj.speed * time)];
                        if s > obj.canvasSize(2)
                            s = obj.canvasSize(2) - (s - obj.canvasSize(2)-1);
                        end
                    case {'east', 'west'}
                        s = [(obj.speed * time), obj.canvasSize(2)];
                        if s > obj.canvasSize(1)
                            s = obj.canvasSize(1) - (s - obj.canvasSize(1)-1);
                        end
                end
            end
        end

        function prepareEpoch(obj, epoch)
        	prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

            % Save the speed based on direction
            switch obj.direction
                case {'east', 'west'}
                    epoch.addParameter('speed', obj.speed(1));
                case {'north', 'south'}
                    epoch.addParameter('speed', obj.speed(2));
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