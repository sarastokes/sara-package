classdef ColorExchange < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    
    properties
        amp
        preTime = 250
        stimTime = 2000
        tailTime = 250
        coneOne = 'L'
        coneTwo = 'M'
        contrast = 0.7
        outerRadius = 0
        innerRadius = 0
        temporalClass = 'sinewave'
        temporalFrequency = 2
        centerOffset = [0, 0]
        lightMean = 0.5
        numberOfAverages = uint16(26)
    end
    
    properties (Hidden = true)
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave'})
        coneOneType = symphonyui.core.PropertyType('char', 'row',...
            {'L', 'M', 'S', 'R', 'G', 'B'})
        coneTwoType = symphonyui.core.PropertyType('char', 'row',...
            {'L', 'M', 'S', 'R', 'G', 'B'})
        currentLEDValues
        coneWeights
        outerRadiusPix
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            obj.assignSpatialType();
            if obj.outerRadius == 0
                obj.outerRadiusPix = 1500;
            else
                obj.outerRadiusPix = obj.um2pix(obj.outerRadius);
            end
            
            obj.coneWeights = zeros(double(obj.numberOfAverages), 3);
            
            switch obj.coneOne
                case {'R', 'G', 'B'}
                    ind1 = strfind('RGB', obj.coneOne); ind2 = strfind('RGB', obj.coneTwo);
                otherwise
                    ind1 = strfind('LMS', obj.coneOne); ind2 = strfind('LMS', obj.coneTwo);
            end
            for ii = 1:double(obj.numberOfAverages)
                obj.coneWeights(ii, ind1) = cos((ii-1)*2*pi / ...
                    (double(obj.numberOfAverages)-1)) * obj.contrast;
                obj.coneWeights(ii, ind2) = -sin((ii-1)*2*pi / ...
                    (double(obj.numberOfAverages)-1)) * obj.contrast;
            end
            
            % set up figures
            if numel(obj.rig.getDeviceNames('Amp')) < 2
                obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                    obj.rig.getDevice(obj.amp),...
                    'stimTrace', getLightStim(obj, 'modulation'),...
                    'stimColor', getPlotColor(lower(obj.coneOne)));
            else
                obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure',...
                    obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
            end
            
            if ~strcmp(lower(obj.recordingMode), 'none')
                obj.showFigure('edu.washington.riekelab.sara.figures.F1F2Figure',...
                    obj.rig.getDevice(obj.amp), 1:double(obj.numberOfAverages),...
                    obj.getOnlineAnalysis(), obj.preTime, obj.stimTime,...
                    'temporalFrequency', obj.temporalFrequency, 'showF2', true,...
                    'titlestr', [obj.coneOne ' vs ' obj.coneTwo ' color exchange']);
            end
            
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = obj.outerRadiusPix;
            spot.radiusY = obj.outerRadiusPix;
            spot.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            
            spotVisibleController = stage.builtin.controllers.PropertyController(...
                spot, 'visible', @(state)state.time >= obj.preTime * 1e-3...
                && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            
            spotColorController = stage.builtin.controllers.PropertyController(...
                spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));
            
            p.addStimulus(spot);
            p.addController(spotVisibleController);
            p.addController(spotColorController);
            
            % center mask for annulus
            if obj.innerRadius > 0
                mask = obj.makeAnnulus();
                p.addStimulus(mask);
            end
                  
            function c = getSpotColor(obj, time)
                if time >= 0
                    if strcmp(obj.temporalClass, 'sinewave')
                        c = obj.contrast * obj.currentLEDValues...
                            * sin(obj.temporalFrequency * time * 2 * pi)...
                            * obj.lightMean + obj.lightMean;
                    elseif strcmp(obj.temporalClass, 'squarewave')
                        c = obj.contrast * obj.currentLEDValues...
                            * sign(sin(obj.temporalFrequency * time * 2 * pi))...
                            * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);
            
            switch obj.coneOne
                case {'R', 'G', 'B'}
                    obj.currentLEDValues = obj.coneWeights(obj.numEpochsCompleted+1,ii);
                otherwise
                    w = obj.quantalCatch(:, 1:3)' \ obj.coneWeights(obj.numEpochsCompleted+1,:)';
                    w = w/max(abs(w));
                    obj.currentLEDValues = w(:)';
            end
            
            epoch.addParameter('coneWeights',...
                obj.coneWeights(obj.numEpochsCompleted+1,:));
            epoch.addParameter('ledValues', obj.currentLEDValues);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end
