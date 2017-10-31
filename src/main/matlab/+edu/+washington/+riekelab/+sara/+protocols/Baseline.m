classdef Baseline < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    
    properties
        amp
        preTime = 500
        stimTime = 1500
        tailTime = 500
        lightMean = 0.0
        numberOfAverages = uint16(1)
    end
    
    properties (Hidden = true)
        ampType
    end
    
    properties (Hidden = true, Transient = true)
        analysisFigure
        spikeFigure
        firingRates = [];
    end
    
    properties (Hidden = true, Constant = true)
        VERSION = 1;
        DISPLAYNAME = 'Baseline';
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            obj.recordingMode
            class(obj.recordingMode)
            
            if strcmp(obj.recordingMode, 'EXTRACELLULAR')
                obj.spikeFigure = obj.showFigure(...
                    'edu.washington.riekelab.sara.figures.SpikeResponseFigure',...
                    obj.rig.getDevice(obj.amp));
                disp('using spike figure');
            else
                obj.showFigure(...
                    'edu.washington.riekelab.sara.figures.ResponseFigure',...
                    obj.rig.getDevice(obj.amp));
            end
            
            if strcmp(obj.getOnlineAnalysis(), 'spikes')
                obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure',...
                    @obj.baselineFiring);
                f = obj.analysisFigure.getFigureHandle();
                set(f, 'Name', 'Baseline Firing Rate');
                obj.analysisFigure.userData.axesHandle = axes('Parent', f);
            end
        end
        
        function baselineFiring(obj, ~, epoch)
            % BASELINEFIRING  Online analysis for extracellular recording
            if double(obj.numberOfAverages) > 1
                co = pmkmp(double(obj.numberOfAverages), 'cubicl');
            else
                co = [0 0 0];
            end
            axesHandle = obj.analysisFigure.userData.axesHandle;
            
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            responseTrace = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            responseTrace = obj.getResponseByType(responseTrace);
            
            % Calculate the instantaneous firing rate
            instft = getInstFt(responseTrace);
            % Firing rates are stored to calculate mean/sem over multiple epochs
            obj.firingRates = cat(1, obj.firingRates, instft);
            
            title(axesHandle, sprintf('firing rate = %.2f /pm %.2f',...
                mean(obj.firingRates(:)), sem(obj.firingRates(:))));
            hold(axesHandle, 'on');
            plot(axesHandle, (1:length(instft))/sampleRate, instft,...
                'Color', co(obj.numEpochsCompleted, :));
            hold(axesHandle, 'off');
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.lightMean);
        end
        
        function completeEpoch(obj, epoch)
            completeEpoch@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, epoch);
            
            size(obj.spikeFigure.spikeMatrix,1)
            disp('found datamatrix!!!');
        end
        
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            
            if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages)
                obj.rig.getDevice('Stage').replay;
            else
                obj.rig.getDevice('Stage').play(obj.createPresentation());
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