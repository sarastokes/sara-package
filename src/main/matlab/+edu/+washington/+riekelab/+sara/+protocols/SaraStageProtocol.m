classdef (Abstract) SaraStageProtocol < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        interpulseInterval = 0          % Duration between pulses (s)
        greenLED = '505nm'              % Set automatically by filter wheel module
        recordingMode = 'EXTRACELLULAR' % Recording type
        analysisMode = 'auto'           % Analysis type
    end

    properties (Hidden = true)
        greenLEDType = symphonyui.core.PropertyType('char', 'row',...
            {'570nm', '505nm'})
        recordingModeType = symphonyui.core.PropertyType('char', 'row',...
            edu.washington.riekelab.sara.util.enumStr(...
                'edu.washington.riekelab.sara.types.RecordingModeType'))
        analysisModeType = symphonyui.core.PropertyType('char', 'row',...
            {'auto', 'none', 'excitation', 'inhibition', 'subthreshold', 'spikes', 'analog', 'ic_spikes'})
        stageClass
        frameRate
        canvasSize
        ledWeights
        quantalCatch
        ndf
        objectiveMag
        muPerPixel
        greenLEDName
        spatialType = [];
    end

    methods

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure',...
                obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));

            % Get the frame rate. Need to check if it's a LCR rig.
            if ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LightCrafter'))
                obj.frameRate = obj.rig.getDevice('Stage').getPatternRate();
                obj.stageClass = 'LightCrafter';
            elseif ~isempty(strfind(obj.rig.getDevice('Stage').name, 'LcrRGB'))
                obj.frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
                obj.stageClass = 'LcrRGB';
            else
                obj.frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
                obj.stageClass = 'Video';
            end

            % Get the quantal catch.
            try
                calibrationDir = 'C:\Users\Public\Documents\GitRepos\Symphony2\sara-package\calibration\';
                q = load([calibrationDir 'QCatch.mat']);
            catch
                calibrationDir = 'C:\Users\sarap\Google Drive\MATLAB\Symphony\sara-package\calibration\';
                q = load([calibrationDir 'QCatch.mat']);
            end


            % Look for a filter wheel device.
            fw = obj.rig.getDevices('FilterWheel');
            if ~isempty(fw{1})
                filterWheel = fw{1};
                % Get the microscope objective magnification.
                obj.objectiveMag = filterWheel.getObjective();

                % Get the NDF wheel setting.
                obj.ndf = filterWheel.getNDF();
                ndString = num2str(obj.ndf * 10);
                if length(ndString) == 1
                    ndString = ['0', ndString];
                end
                obj.greenLEDName = filterWheel.getGreenLEDName();
                if strcmp(obj.greenLEDName, 'Green_505nm')
                    obj.quantalCatch = q.qCatch.(['ndf', ndString])([1 2 4],:);
                else
                    obj.quantalCatch = q.qCatch.(['ndf', ndString])([1 3 4],:);
                end

                obj.muPerPixel = filterWheel.getMicronsPerPixel();

                % Adjust the quantal catch depending on the objective.
                if obj.objectiveMag == 4
                    obj.quantalCatch = obj.quantalCatch .* ([0.498627;0.4921139;0.453983]*ones(1,4));
                elseif obj.objectiveMag == 60
                    obj.quantalCatch = obj.quantalCatch .* ([0.664836;0.630064;0.732858]*ones(1,4));
                end
            else
                obj.objectiveMag = 'null';
                obj.ndf = 4;
                ndString = num2str(obj.ndf * 10);
                if length(ndString) == 1
                    ndString = ['0', ndString];
                end
                obj.quantalCatch = q.qCatch.(['ndf', ndString]);
                obj.muPerPixel = 0;
                obj.greenLEDName = 'Green_505nm';
            end

            % Get the canvas size.
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

            % Add LED parameters
            epoch.addParameter('greenLED', obj.greenLEDName);
            epoch.addParameter('ledWeights', obj.ledWeights);
            
            % Add stimulus parameters
            epoch.addParameter('frameRate', obj.frameRate);
            epoch.addParameter('stageClass', obj.stageClass);            
            epoch.addParameter('ndf', obj.ndf);
            if obj.muPerPixel > 0
                epoch.addParameter('micronsPerPixel', obj.muPerPixel);
                epoch.addParameter('objectiveMag', obj.objectiveMag);
            end

            % assign spatial type is called by protocols
            if ~isempty(obj.spatialType)
                epoch.addParameter('spatialType', obj.spatialType);
            end

            % Check for 2P scanning devices.
            obj.checkImaging(epoch);

            %--------------------------------------------------------------
            % Set up the amplifiers for recording.
            duration = (obj.preTime + obj.stimTime + obj.tailTime) * 1e-3;

            % Get the amplfiers.
            mcDevices = obj.rig.getDevices('Amp');

            % Add each amplifier
            for k = 1 : length(mcDevices)
                device = obj.rig.getDevice(mcDevices{k}.name);
                epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
                epoch.addResponse(device);
            end
        end

        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);

            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end

        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Stage'));
                msg = 'No stage';
            end
        end
    end

    %
    % Figure methods
    %
    methods
        function [frameTimes, actualFrameRate] = getFrameTimes(obj, epoch)
            resp = epoch.getResponse(obj.rig.getDevice('Frame Monitor'));
            frameMonitor = resp.getData();

            if sum(frameMonitor) == 0
                frameTimes = [0 0];
                actualFrameRate = 60;
            else
                frameTimes = getFrameTiming(frameMonitor(:)', 1);
                % Take only the frame times during the stimulus.
                frameTimes = frameTimes(frameTimes >= obj.preTime*1e-3*obj.sampleRate & frameTimes <= (obj.preTime+obj.stimTime)*1e-3*obj.sampleRate);
                actualFrameRate = obj.sampleRate / (mean(diff(frameTimes(frameTimes >= obj.preTime/1000*obj.sampleRate))));
            end
        end

        function onlineAnalysis = getOnlineAnalysis(obj)
            % GETANALYSISTYPE  To parse auto analysisMode 
            import edu.washington.riekelab.sara.types.ResponseModeType.*;
            if strcmp(obj.analysisMode, 'auto')
                switch obj.recordingMode
                    case 'extracellular'
                        onlineAnalysis = 'spikes';
                    case 'voltage_clamp'
                        onlineAnalysis = 'analog';
                    case 'current_clamp'
                        onlineAnalysis = 'ic_spikes';
                    otherwise
                        onlineAnalysis = 'none';
                end
            else
                onlineAnalysis = obj.analysisMode;
            end
        end

        function response = getResponseByType(obj, response)
            % GETRESPONSEBYTYPE  Process data by recordingType
            switch obj.getOnlineAnalysis()
                case 'spikes'
                    response = wavefilter(response(:)', 6);
                    S = spikeDetectorOnline(response);
                    spikesBinary = zeros(size(response));
                    spikesBinary(S.sp) = 1;
                    response = spikesBinary * obj.sampleRate;
                case 'ic_spikes'
                    spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
                    spikesBinary = zeros(size(response));
                    spikesBinary(spikeTimes) = 1;
                    response = spikesBinary * obj.sampleRate;
                case 'subthreshold'
                    spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
                    % Get the subthreshold potential.
                    if ~isempty(spikeTimes)
                        response = getSubthreshold(response(:)', spikeTimes);
                    else
                        response = response(:)';
                    end

                    % Subtract the median.
                    if obj.preTime > 0
                        response = response - median(response(1:round(obj.sampleRate*obj.preTime/1000)));
                    else
                        response = response - median(response);
                    end
                case 'analog'
                    % Deal with band-pass filtering analog data here.
                    response = bandPassFilter(response, 0.2, 500, 1/obj.sampleRate);
                    % Subtract the median.
                    if obj.preTime > 0
                        response = response - median(response(1:round(obj.sampleRate*obj.preTime/1000)));
                    else
                        response = response - median(response);
                    end
            end
        end
    end

    %
    % LED management
    %
    methods
        function greenLED = findGreenLEDName(obj)
            fw = obj.rig.getDevices('FilterWheel');
            if ~isempty(fw)
                greenLED = fw.getGreenLEDName();
            else
                greenLED = [];
            end
        end

        function [stimList, greenLED] = getStimuliByLED(obj)
            % GETSTIMULIBYLED  Match the LED to the correct chromaticities
            fw = obj.rig.getDevices('FilterWheel');
            if ~isempty(fw)
                greenLED = fw.getGreenLEDName();
                switch greenLED
                    case 'Green_505nm'
                        stimList = 'alms';
                    case 'Green_570nm'
                        stimList = 'as';
                end
            else
                warndlg('getStimuliByLED - No filter wheel found!');
                greenLED = 'unknown';
                stimList = [];
            end
        end

        function ledFlag = checkGreenLED(obj, colorCall)
            % CHECKGREENLED  Matches green LED to cone-iso stim
            colorCall = lower(colorCall);
            fw = obj.rig.getDevices('FilterWheel');
            ledFlag = false;
            if ~isempty(fw)
                fw = fw{1};
                greenLED = fw.getGreenLEDName();
                if strcmp(greenLED, 'Green_570nm')
                    if strcmp(colorCall(1), 's')
                        ledFlag = false;
                    else
                        ledFlag = true;
                    end
                elseif strcmp(greenLED, 'Green_505nm')
                    if strcmp(colorCall(1), 's')
                        ledFlag = true;
                    else
                        ledFlag = false;
                    end
                end
            end
            if ledFlag
                warndlg('Green LED may be incorrect!');
            end
        end % checkGreenLED

        % Set LED weights based on grating type.
        function setLEDs(obj, colorCall)
            % SETLEDS  LED weights for cone-isolating stimuli
            if nargin < 2
                try
                    colorCall = obj.chromaticity;
                catch % Until the changes are fully implemented
                    colorCall = obj.chromaticClass;
                end
            end
            switch lower(colorCall)
                case {'red', 'r'}
                    obj.ledWeights = [1 0 0];
                case {'green', 'g'}
                    obj.ledWeights = [0 1 0];
                case {'blue', 'b'}
                    obj.ledWeights = [0 0 1];
                case {'yellow', 'x'}
                    % See LuminosityScratch.m in calibration folder
                    obj.ledWeights = [1 0.817 0];
                case {'l-iso', 'l'}
                    obj.ledWeights = obj.quantalCatch(:,1:3)' \ [1 0 0]';
                    obj.ledWeights = obj.ledWeights/max(abs(obj.ledWeights));
                case {'m-iso', 'm'}
                    obj.ledWeights = obj.quantalCatch(:,1:3)' \ [0 1 0]';
                    obj.ledWeights = obj.ledWeights/max(abs(obj.ledWeights));
                case {'s-iso', 's'}
                    obj.ledWeights = obj.quantalCatch(:,1:3)' \ [0 0 1]';
                    obj.ledWeights = obj.ledWeights/max(abs(obj.ledWeights));
                case {'lm-iso', 'y'}
                    obj.ledWeights = obj.quantalCatch(:,1:3)' \ [1 1 0]';
                    obj.ledWeights = obj.ledWeights/max(abs(obj.ledWeights));
                otherwise
                    obj.ledWeights = [1 1 1];
            end

            obj.ledWeights = obj.ledWeights(:)';
        end
    end

    %
    % Controllers
    %
    methods
        function c = getSpotColorLcrRGB(obj, state)
            switch lower(obj.temporalClass)
            case 'sinewave'
                if state.pattern == 0
                    c = obj.contrast * obj.ledWeights(1)...
                        * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)...
                        * obj.lightMean + obj.lightMean;
                elseif state.pattern == 1
                    c = obj.contrast * obj.ledWeights(2)...
                        * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)...
                        * obj.lightMean + obj.lightMean;
                else
                    c = obj.contrast * obj.ledWeights(3)...
                        * sin(obj.temporalFrequency*(state.time - obj.preTime * 1e-3)*2*pi)...
                        * obj.lightMean + obj.lightMean;
                end
            case 'squarewave'
                if state.pattern == 0
                    c = obj.contrast * obj.ledWeights(1)...
                        * sign(sin(obj.temporalFrequency * (state.time - obj.preTime * 1e-3)*2*pi))...
                        * obj.lightMean + obj.lightMean;
                elseif state.pattern == 1
                    c = obj.contrast * obj.ledWeights(2)...
                        * sign(sin(obj.temporalFrequency * (state.time - obj.preTime * 1e-3)*2*pi))...
                        * obj.lightMean + obj.lightMean;
                else
                    c = obj.contrast * obj.ledWeights(3)...
                        * sign(sin(obj.temporalFrequency * (state.time - obj.preTime * 1e-3)*2*pi))...
                        * obj.lightMean + obj.lightMean;
                end
            end
        end
    end
    %
    % Stimulus
    %
    methods
        function spatialType = assignSpatialType(obj, typestr)
            % ASSIGNSTIMULUSCLASS  Auto assign unless included as arg

            % Spatial type is provided
            if nargin == 2
                obj.spatialType = typestr;
                return;
            end

            % Auto-assign spatial type
            if isprop(obj, 'innerRadius') && obj.innerRadius > 0
                spatialType = 'annulus';
            elseif isprop(obj, 'outerRadius')
                if obj.outerRadius > 0 
                    if obj.outerRadius > min(obj.canvasSize)
                        spatialType = 'partial';
                    else
                        spatialType = 'spot';
                    end
                else
                    spatialType = 'fullfield';
                end
            else
                spatialType = 'undefined';
            end
        end

        function pix = um2pix(obj, um)
            pix = um/obj.muPerPixel;
        end

        function mask = makeAnnulus(obj)
            % MAKEANNULUS  Set mask using innerRadius property
            if ~isprop(obj, 'innerRadius')
                warning('make sure to name property innerRadius');
                return;
            end
            
            if obj.innerRadius > 0
                mask = stage.builtin.stimuli.Ellipse();
                mask.radiusX = obj.um2pix(obj.innerRadius);
                mask.radiusY = obj.um2pix(obj.innerRadius);
                mask.position = obj.canvasSize/2 + obj.um2pix(centerOffset);
                mask.color = obj.lightMean;
            end
        end

        function aperture = makeAperture(obj)
            % MAKEAPERTURE  For fullfield stimuli with outerRadius property
            if ~isprop(obj, 'outerRadius')
                warning('make sure to name property outerRadius');
                return;
            end
            
            aperture = stage.builtin.stimuli.Rectangle();
            aperture.position = obj.canvasSize/2 + obj.um2pix(obj.centerOffset);
            aperture.color = obj.lightMean;
            aperture.size = [max(obj.canvasSize) max(obj.canvasSize)];
            mask = stage.core.Mask.createCircularAperture(...
                obj.um2pix(obj.outerRadius) * 2 / max(obj.canvasSize), 1024);
            aperture.setMask(mask);
        end
    end
    % 
    % Imaging
    %
    methods
        function checkImaging(obj, epoch)
            triggers = obj.rig.getDevices('SciScan Trigger');
            if ~isempty(triggers)

                stim = obj.createSciScanTriggerStimulus();
                epoch.addStimulus(triggers{1}, stim);

                % Add the devices you need for imaging.
                devNames = {'Green PMT', 'Red PMT', 'SciScan F Clock', 'SciScan S Clock'};
                % Check for the PMT DAQ devices.
                foo = obj.rig.getDevices('Green PMT');
                if ~isempty(foo)
                    for k = 1 : length(devNames)
                        device = obj.rig.getDevice(devNames{k});
                        if ~isempty(device)
                            epoch.addResponse(device);
                        end
                    end
                end
            end
        end

        function stim = createSciScanTriggerStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();

            gen.preTime = 0;
            gen.stimTime = 10;
            gen.tailTime = obj.preTime + obj.stimTime + obj.tailTime - 10;
            gen.amplitude = 1;
            gen.mean = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = symphonyui.core.Measurement.UNITLESS;

            stim = gen.generate();
        end
    end

    methods (Static)
        function fullName = extendName(abbrev)
            switch abbrev
                case 'a'
                    fullName = 'achromatic';
                case 'l'
                    fullName = 'l-iso';
                case 'm'
                    fullName = 'm-iso';
                case 's'
                    fullName = 's-iso';
                case 'y'
                    fullName = 'lm-iso';
                case 'r'
                    fullName = 'red';
                case 'g'
                    fullName = 'green';
                case 'b'
                    fullName = 'blue';
                case 'x'
                    fullName = 'yellow';
            end
        end % extendName
    end
end
