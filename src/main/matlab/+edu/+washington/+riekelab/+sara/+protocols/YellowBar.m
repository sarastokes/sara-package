classdef YellowBar < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
    properties
        amp                             % Output amplifier
        preTime = 500                   % Bar leading duration (ms)
        stimTime = 2500                 % Bar duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        orientations = [0:90:270, 90, 0, 270, 180]         % Bar angle (deg)
        speed = 600                     % Bar speed (pix/sec)
        whiteContrast = 1.0             % Max light intensity (0-1)
        yellowContrast = 1.0
        barSize = [1500, 1500]          % Bar size (x,y) in pixels
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in pixels (x,y)
        innerMaskRadius = 0             % Inner mask radius in pixels.
        outerMaskRadius = 570           % Outer mask radius in pixels.
        randomOrder = true              % Random orientation order?
        contrastMode = false
        onlineAnalysis = 'extracellular'         % Online analysis type.
        numberOfAverages = uint16(16)   % Number of epochs
    end
    
    properties (Constant = true, Hidden = true)
        DISPLAYNAME = 'whiteyellow'
    end
    
    properties (Hidden)
        ampType
        onlineAnalysisType = symphonyui.core.PropertyType('char', 'row',... 
            {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
        sequence
        orientation
        orientationRads
        chromaticity
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);
            
            colors = pmkmp(8, 'cubicl');
            obj.chromaticity = 'achromatic';
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('edu.washington.riekelab.manookin.figures.MeanResponseFigure', ...
                obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                'sweepColor',colors,...
                'groupBy',{'chromaticity', 'orientation'});
            
            if ~strcmp(obj.onlineAnalysis, 'none')
                obj.showFigure('edu.washington.riekelab.manookin.figures.DirectionFigure', ...
                    obj.rig.getDevice(obj.amp),'recordingType',obj.onlineAnalysis,...
                    'preTime', obj.preTime, 'stimTime', obj.stimTime, ...
                    'orientations', unique(obj.orientations));
            end
            
            % Get the frame rate. Need to check if it's a LCR rig.
            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                obj.frameRate = obj.rig.getDevice('Stage').getPatternRate();
            else
                obj.frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
            end
            
            % Get the canvas size.
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            % Check the outer mask radius.
            if obj.outerMaskRadius > min(obj.canvasSize/2)
                obj.outerMaskRadius = min(obj.canvasSize/2);
            end
            
            obj.organizeParameters();
        end
        
        function organizeParameters(obj)
            % Calculate the number of repetitions of each annulus type.
            numReps = ceil(double(obj.numberOfAverages) / length(obj.orientations));
            
            % Set the sequence.
            if obj.randomOrder
                obj.sequence = zeros(length(obj.orientations), numReps);
                for k = 1 : numReps
                    obj.sequence(:,k) = obj.orientations(randperm(length(obj.orientations)));
                end
            else
                obj.sequence = obj.orientations(:) * ones(1, numReps);
            end
            obj.sequence = obj.sequence(:)';
            obj.sequence = obj.sequence(1 : obj.numberOfAverages);
        end
        
        function p = createPresentation(obj)
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            rect = stage.builtin.stimuli.Rectangle();
            rect.size = obj.barSize;
            rect.position = obj.canvasSize/2 + obj.centerOffset;
            rect.orientation = obj.orientation;
            switch obj.chromaticity
                case 'yellow'
                    if obj.contrastMode
                        rect.color = obj.whiteContrast * [1 0.81 0] * obj.backgroundIntensity + obj.backgroundIntensity;
                    else
                        rect.color = [1 0.81 0];
                    end
                case 'achromatic'
                    if obj.contrastMode
                        rect.color = obj.yellowContrast * [1 1 1] * obj.backgroundIntensity + obj.backgroundIntensity;
                    else
                        rect.color = [1 1 1];
                    end
            end
            
            
            % Add the stimulus to the presentation.
            p.addStimulus(rect);
            
            barVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(barVisible);
            
            % Bar position controller
            barPosition = stage.builtin.controllers.PropertyController(rect, 'position', ...
                @(state)motionTable(obj, state.time - obj.preTime*1e-3));
            p.addController(barPosition);
            
            function p = motionTable(obj, time)
                % Calculate the increment with time.
                inc = time * obj.speed - obj.outerMaskRadius - obj.barSize(1)/2 ;
                
                p = [cos(obj.orientationRads) sin(obj.orientationRads)] .* (inc*ones(1,2)) + obj.canvasSize/2 + obj.centerOffset;
            end
            
            % Create the inner mask.
            if (obj.innerMaskRadius > 0)
                p.addStimulus(obj.makeInnerMask());
            end
            
            % Create the outer mask.
            if (obj.outerMaskRadius > 0)
                p.addStimulus(obj.makeOuterMask());
            end
        end
        
        function mask = makeOuterMask(obj)
            mask = stage.builtin.stimuli.Rectangle();
            mask.color = obj.backgroundIntensity;
            mask.position = obj.canvasSize/2 + obj.centerOffset;
            mask.orientation = 0;
            mask.size = 2 * max(obj.canvasSize) * ones(1,2);
            sc = obj.outerMaskRadius*2 / (2*max(obj.canvasSize));
            m = stage.core.Mask.createCircularAperture(sc);
            mask.setMask(m);
        end
        
        function mask = makeInnerMask(obj)
            mask = stage.builtin.stimuli.Ellipse();
            mask.radiusX = obj.innerMaskRadius;
            mask.radiusY = obj.innerMaskRadius;
            mask.color = obj.backgroundIntensity;
            mask.position = obj.canvasSize/2 + obj.centerOffset;
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);
            
            % Get the current bar orientation.
            obj.orientation = obj.sequence(obj.numEpochsCompleted+1);
            obj.orientationRads = obj.orientation / 180 * pi;
            
            % Switch between yellow and white
            if strcmp(obj.chromaticity, 'yellow')
                obj.chromaticity = 'achromatic';
            else
                obj.chromaticity = 'yellow';
            end
            
            epoch.addParameter('orientation', obj.orientation);
            epoch.addParameter('chromaticity', obj.chromaticity);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end