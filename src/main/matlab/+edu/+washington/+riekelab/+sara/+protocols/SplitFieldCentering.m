classdef SplitFieldCentering < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % Max's SplitFieldCentering protocol with some cone-iso options
    properties
        preTime = 250 % ms
        stimTime = 2000 % ms
        tailTime = 250 % ms
        contrast = 0.9 % relative to mean (0-1)
        chromaticity = 'ACHROMATIC'
        temporalClass = 'squarewave'
        temporalFrequency = 4 % Hz
        outerRadius = 300; % um
        innerRadius = 0 % um
        splitField = true
        rotation = 0;  % deg
        lightMean = 0.5 % (0-1)
        centerOffset = [0, 0] % [x,y] (um)
        numberOfAverages = uint16(1) % number of epochs to queue
        amp % Output amplifier
    end
    
    properties (Hidden = true)
        ampType
        temporalClassType = symphonyui.core.PropertyType('char', 'row',...
            {'sinewave', 'squarewave'})
        chromaticityType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
                'edu.washington.riekelab.sara.types.ChromaticityType'))
            
        onlineAnalysis
        plotColor
    end
    
    properties (Hidden = true, Transient = true)
        analysisFigure
    end

    properties (Constant = true, Hidden = true)
        VERSION = 3; % Max's SplitFieldCentering with cone-iso additions
        DISPLAYNAME = 'Split Field';
    end
    
    methods
        function didSetRig(obj)
            didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
        
        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);
            
            % catch some errors
            if ~isempty(strfind(obj.chromaticity, '-iso'))
                if obj.rotation ~= 90 && obj.rotation ~= 0
                    error('cone iso only works for 0 and 90 degrees right now');
                end
                if strcmp(obj.temporalClass, 'sinewave')
                    warndlg('cone iso only works with squarewave splitfield, use conesweep for uniform spot stuff');
                    return;
                end
            end

            obj.onlineAnalysis = obj.getOnlineAnalysis();            
            obj.setLEDs();
            
            obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',...
                obj.rig.getDevice(obj.amp),...
                'stimTrace', getLightStim(obj, 'modulation'),...
                'stimColor', getPlotColor(obj.chromaticity));
            
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure',...
                obj.rig.getDevice(obj.amp));
            
            if ~strcmp(obj.onlineAnalysis, 'none')
                if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
                    obj.analysisFigure = obj.showFigure(...
                        'symphonyui.builtin.figures.CustomFigure', @obj.F1F2_PTSH);
                    f = obj.analysisFigure.getFigureHandle();
                    set(f, 'Name', 'Cycle avg PTSH');
                    obj.analysisFigure.userData.runningTrace = 0;
                    obj.analysisFigure.userData.axesHandle = axes('Parent', f);
                else
                    obj.analysisFigure.userData.runningTrace = 0;
                end
            end
        end
        
        function F1F2_PTSH(obj, ~, epoch) % online analysis function
            response = epoch.getResponse(obj.rig.getDevice(obj.amp));
            quantities = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            
            axesHandle = obj.analysisFigure.userData.axesHandle;
            runningTrace = obj.analysisFigure.userData.runningTrace;
            
            if strcmp(obj.onlineAnalysis, 'spikes')
                filterSigma = (20/1000) * sampleRate;
                newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);
                res = spikeDetectorOnline(quantities, [], sampleRate);
                epochResponseTrace = zeros(size(quantities));
                epochResponseTrace(res.sp) = 1; %spike binary
                epochResponseTrace = sampleRate*conv(epochResponseTrace,newFilt,'same');
            else
                epochResponseTrace = quantities-mean(quantities(1:sampleRate*obj.preTime/1000));
                if strcmp(obj.onlineAnalysis,'exc') %measuring exc
                    epochResponseTrace = epochResponseTrace./(-60-0); %conductance (nS), ballpark
                elseif strcmp(obj.onlineAnalysis,'inh') %measuring inh
                    epochResponseTrace = epochResponseTrace./(0-(-60)); %conductance (nS), ballpark
                end
            end
            
            noCycles = floor(obj.temporalFrequency*obj.stimTime/1000);
            period = (1/obj.temporalFrequency)*sampleRate;
            epochResponseTrace(1:(sampleRate*obj.preTime/1000)) = [];
            cycleAvgResp = 0;
            for c = 1:noCycles
                cycleAvgResp = cycleAvgResp + epochResponseTrace((c-1) * period+1:c*period);
            end
            cycleAvgResp = cycleAvgResp ./ noCycles;
            timeVector = (1:length(cycleAvgResp))./sampleRate;
            runningTrace = runningTrace + cycleAvgResp;
            cla(axesHandle);
            h = line(timeVector, runningTrace./obj.numEpochsCompleted);
            set(h, 'color', [0 0 0], 'linewidth', 2);
            xlabel(axesHandle, 'Time (s)');
            title(axesHandle, 'Running cycle average...')
            if strcmp(obj.onlineAnalysis,'spikes')
                ylabel(axesHandle, 'spike rate (hz)');
            else
                ylabel(axesHandle, 'resp (ns)');
            end
            obj.analysisFigure.userData.runningTrace = runningTrace;
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.lightMean); % Set background intensity

            outerRadiusPix = obj.um2pix(obj.outerRadius);
            
            if isempty(strfind(obj.chromaticity, '-iso')) % old working code
                % Create grating stimulus.
                grate = stage.builtin.stimuli.Grating('square'); %square wave grating
                grate.orientation = obj.rotation;
                grate.size = [2 * outerRadiusPix, 2 * outerRadiusPix];
                grate.position = obj.canvasSize/2 + obj.centerOffset;
                grate.spatialFreq = 1/(4*outerRadiusPix);
                if (obj.splitField)
                    grate.phase = 90;
                else %full-field
                    grate.phase = 0;
                end
                p.addStimulus(grate); %add grating to the presentation
                
                %make it contrast-reversing
                if (obj.temporalFrequency > 0)
                    if strcmp(obj.chromaticity, 'achromatic')
                        grateContrast = stage.builtin.controllers.PropertyController(...
                            grate, 'contrast', @(state)getGrateContrast(obj, state.time - obj.preTime/1e3));
                        p.addController(grateContrast); %add the controller
                    else
                        grateColor = stage.builtin.controllers.PropertyController(...
                            grate, 'color', @(state)getGrateColor(obj, state.time - obj.preTime/1e3));
                        p.addController(grateColor);
                    end
                end
                
                %hide during pre & post
                grateVisibleController = stage.builtin.controllers.PropertyController(...
                    grate, 'visible', @(state)state.time >= obj.preTime * 1e-3...
                    && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(grateVisibleController);
            end
            
            %% new cone iso code
            if ~isempty(strfind(obj.chromaticity, '-iso'))
                barOne = stage.builtin.stimuli.Rectangle();
                barOne.size = [outerRadiusPix outerRadiusPix];
                
                barTwo = stage.builtin.stimuli.Rectangle();
                barTwo.size = [outerRadiusPix outerRadiusPix];
                
                barOne.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
                barTwo.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
                % the bar position will have to change with rotation
                if obj.rotation == 0 % for now... all orientations if this works
                    barOne.position(1) = barOne.position(1) - outerRadiusPix/2;
                    barTwo.position(1) = barTwo.position(1) + outerRadiusPix/2;
                    barOne.size(2) = barOne.size(2) * 2;
                    barTwo.size(2) = barTwo.size(2) * 2;
                elseif obj.rotation == 90
                    barOne.position(2) = barOne.position(2) - outerRadiusPix/2;
                    barTwo.position(2) = barTwo.position(2) + outerRadiusPix/2;
                    barOne.size(1) = barOne.size(1) * 2;
                    barTwo.size(1) = barTwo.size(1) * 2;
                end
                
                barOneColorController = stage.builtin.controllers.PropertyController(...
                    barOne, 'color', @(state)getBarOneColor(obj, state.time - obj.preTime * 1e-3));
                barTwoColorController = stage.builtin.controllers.PropertyController(...
                    barTwo, 'color', @(state)getBarTwoColor(obj, state.time - obj.preTime * 1e-3));
                barOneVisibleController = stage.builtin.controllers.PropertyController(...
                    barOne, 'visible', @(state)state.time >= obj.preTime * 1e-3...
                    && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                barTwoVisibleController = stage.builtin.controllers.PropertyController(...
                    barTwo, 'visible', @(state)state.time >= obj.preTime * 1e-3...
                    && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                
                % add stimuli and their controllers
                p.addStimulus(barOne);
                p.addController(barOneColorController);
                p.addController(barOneVisibleController);
                p.addStimulus(barTwo);
                p.addController(barTwoColorController);
                p.addController(barTwoVisibleController);
            end
            
            
            % Create aperture
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            aperture.color = obj.lightMean;
            aperture.size = [2*outerRadiusPix, 2*outerRadiusPix];
            mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
            aperture.setMask(mask);
            p.addStimulus(aperture); %add aperture
            
            if (obj.innerRadius > 0) % Create mask
                mask = obj.makeAnnulus();                
                p.addStimulus(mask);
            end
            
            %% controller functions
            function c = getBarOneColor(obj, time)
                if time >= 0
                    c = obj.contrast * obj.ledWeights...
                        * sign(sin(obj.temporalFrequency * time * 2 * pi))...
                        * obj.lightMean + obj.lightMean;
                else
                    c = obj.lightMean;
                end
            end
            
            function c = getBarTwoColor(obj, time)
                if time >= 0
                    c = -1 * obj.contrast * obj.ledWeights... 
                        * sign(sin(obj.temporalFrequency * time * 2 * pi))... 
                        * obj.lightMean + obj.lightMean;
                else
                    c = obj.lightMean;
                end
            end
            
            function c = getGrateContrast(obj, time)
                if strcmp(obj.temporalClass, 'sinewave')
                    c = obj.contrast.*sin(2 * pi * obj.temporalFrequency * time);
                else
                    c = obj.contrast.*sign(sin(2 * pi * obj.temporalFrequency * time));
                end
            end
            
            function c = getGrateColor(obj, time)
                if time >= 0
                    if strcmp(obj.temporalClass, 'sinewave')
                        c = obj.contrast * obj.ledWeights...
                            * sin(obj.temporalFrequency * time * 2 * pi)...
                            * obj.lightMean + obj.lightMean;
                    else
                        c = obj.contrast * obj.ledWeights... 
                            * sign(sin(obj.temporalFrequency * time * 2 * pi))...
                            * obj.lightMean + obj.lightMean;
                    end
                else
                    c = obj.lightMean;
                end
            end
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch)
            epoch.addParameter('plotColor', obj.plotColor);            
        end
        
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages)
                obj.rig.getDevice('Stage').replay
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
