classdef BarCentering < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % 10Jul2017 - SSP - updated to run x, y together with new figures
    
    properties
        amp                             % Output amplifier
        preTime = 250                   % Spot leading duration (ms)
        stimTime = 2000                 % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        contrast = 1.0                  % Bar contrast (-1:1)
        temporalFrequency = 2.0         % Modulation frequency (Hz)
        barSize = [40 400]              % Bar size [width, height] (um)
        temporalClass = 'squarewave'    % Squarewave or pulse?
        positions = -240:40:240         % Bar positions (um)
        lightMean = 0.5                 % Background light intensity (0-1)
        centerOffset = [0,0]            % Center offset in microns (x,y)
        chromaticity = 'achromatic'     % Chromatic class
        numberOfAverages = uint16(26)   % Number of epochs
    end
    
    properties (Hidden)
        version = 3
        displayName = 'BarCentering';
        
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'squarewave', 'pulse_positive', 'pulse_negative'})
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso',...
            'red', 'green', 'blue', 'yellow'})
        searchAxis
        position
        orientation
        orientations
        sequence
    end
    
    properties (Hidden, Transient)
        fh
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevices('Amp'),...
                'stimTrace', getLightStim(obj, 'modulation'));
            
            if ~strcmp(obj.getOnlineAnalysis(), 'none')
                obj.fh = obj.showFigure('edu.washington.riekelab.sara.figures.BarCenteringFigure',...
                    obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime, obj.temporalFrequency,...
                    'onlineAnalysis', obj.getOnlineAnalysis());
            end
            
            % Begin with x-axis
            obj.searchAxis = 'xaxis';
            
            % Set up the stimulus parameters
            obj.orientations = repmat([0 90], length(obj.positions), 1);
            obj.orientations = obj.orientations(:)';
            
            [~, ind] = sort(abs(obj.positions), 'ascend');
            pos = obj.positions(ind)';
            
            centerOffsetPix = obj.um2pix(obj.centerOffset);
            %x = [pos+centerOffsetPix(1), centerOffsetPix(2)*ones(length(pos),1)];
            %y = [centerOffsetPix(1)*ones(length(pos),1), pos+centerOffsetPix(2)];
            x = [pos+obj.centerOffset(1), obj.centerOffset(2)*ones(length(pos), 1)];
            y = [obj.centerOffset(1)*ones(length(pos), 1), pos+obj.centerOffset(2)];
            obj.sequence = [x; y];
            
            obj.setLEDs;
        end % prepareRun
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
            
            rect = stage.builtin.stimuli.Rectangle();
            rect.size = obj.um2pix(obj.barSize);
            rect.orientation = obj.orientation;
            rect.position = obj.canvasSize/2 + obj.um2pix(obj.position);
            
            if strcmp(obj.stageClass, 'Video')
                rect.color = obj.contrast * obj.ledWeights * obj.lightMean + obj.lightMean;
            else
                rect.color = obj.contrast * obj.lightMean + obj.lightMean;
            end
            
            % Add the stimulus to the presentation.
            p.addStimulus(rect);
            
            % Control when the spot is visible.
            spotVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            
            % Control the bar contrast.
            if ismember(obj.temporalClass, {'squarewave', 'sinewave'})
                colorController = stage.builtin.controllers.PropertyController(rect, 'color', ...
                    @(state)getModColor(obj, state.time - obj.preTime * 1e-3));
            else
                colorController = stage.builtin.controllers.PropertyController(rect, 'color', ...
                    @(state)getPulseColor(obj, state.time - obj.preTime * 1e-3));
            end
            p.addController(colorController);
            
            
            function c = getModColor(obj, time)
                if strcmp(obj.stageClass, 'Video')
                    c = obj.contrast * sign(sin(obj.temporalFrequency*time*2*pi))...
                        * obj.ledWeights * obj.lightMean + obj.lightMean;
                else
                    c = obj.contrast * sign(sin(obj.temporalFrequency*time*2*pi))...
                        * obj.lightMean + obj.lightMean;
                end
            end
            
            function getPulseColor(obj, time)
                c = obj.contrast * sign(sin(obj.temporalFrequency*time*2*pi))...
                    * obj.lightWeights * obj.lightMean + obj.lightMean;
                if strcmp(obj.temporalClass, 'pulse_negative') 
                    if c > obj.lightMean
                        c = obj.lightMean; %#ok
                    end
                else strcmp(obj.temporalClass, 'pulse_positive') 
                    if c < obj.lightMean
                        c = obj.lightMean; %#ok
                    end
                end
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);
            
            obj.position = obj.sequence(obj.numEpochsCompleted+1, :);
            obj.orientation = obj.orientations(obj.numEpochsCompleted+1);
            
            if obj.numEpochsCompleted >= length(obj.positions)
                obj.searchAxis = 'yaxis';
            else
                obj.searchAxis = 'xaxis';
            end
            
            if strcmp(obj.searchAxis, 'xaxis')
                epoch.addParameter('position', obj.position(1));
            else
                epoch.addParameter('position', obj.position(2));
            end
            epoch.addParameter('searchAxis', obj.searchAxis);
            epoch.addParameter('orientation', obj.orientation);
        end
        
        function completeEpoch(obj, epoch)
            completeEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            if obj.numEpochsCompleted == double(obj.numberOfAverages)
                data = containers.Map();
                data('xaxis_f1x') = obj.fh.cellData.F1X .* obj.fh.cellData.P1X;
                data('xaxis_f2x') = obj.fh.cellData.F2X .* obj.fh.cellData.P2X;
                data('xaxis_xpts') = obj.fh.cellData.xpts;
                data('yaxis_f1y') = obj.fh.cellData.F1Y .* obj.fh.cellData.P1Y;
                data('yaxis_f2y') = obj.fh.cellData.F2Y .* obj.fh.cellData.P2Y;
                data('yaxis_xpts') = obj.fh.cellData.ypts;
                epoch.addParameter('figureData') = data;
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end % methods
end % classdef
