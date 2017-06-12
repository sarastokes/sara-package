classdef ManookinLabStageProtocolSara < edu.washington.riekelab.protocols.RiekeLabStageProtocol

    properties
        interpulseInterval = 0          % Duration between pulses (s)
    end

    properties (Hidden)
        stageClass
        frameRate
        canvasSize
        colorWeights
        quantalCatch
        ndf
        objectiveMag
        muPerPixel
    end

    methods

        function prepareRun(obj)
            prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

            obj.showFigure('edu.washington.riekelab.figures.FrameTimingFigure', obj.rig.getDevice('Stage'), obj.rig.getDevice('Frame Monitor'));

            % Show the progress bar.
            obj.showFigure('edu.washington.riekelab.manookin.figures.ProgressFigure', obj.numberOfAverages);

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
            calibrationDir = 'C:\Users\Public\Documents\GitRepos\Symphony2\sara-package\calibration\';
            q = load([calibrationDir 'QCatch.mat']);


            % Look for a filter wheel device.
            fw = obj.rig.getDevices('FilterWheel');
            if ~isempty(fw)
                filterWheel = fw{1};% Get the microscope objective magnification.
                obj.objectiveMag = filterWheel.getObjective();

                % Get the NDF wheel setting.
                obj.ndf = filterWheel.getNDF();
                ndString = num2str(obj.ndf * 10);
                if length(ndString) == 1
                    ndString = ['0', ndString];
                end
                obj.quantalCatch = q.qCatch.(['ndf', ndString]);
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
            end

            % Get the canvas size.
            obj.canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
        end

        % Set LED weights based on grating type.
        function setColorWeights(obj)
            switch obj.chromaticClass
                case 'red'
                    obj.colorWeights = [1 0 0];
                case 'green'
                    obj.colorWeights = [0 1 0];
                case 'blue'
                    obj.colorWeights = [0 0 1];
                case 'yellow'
                    obj.colorWeights = [1 1 0];
                case 'L-iso'
                    obj.colorWeights = obj.quantalCatch(:,1:3)' \ [1 0 0]';
                    obj.colorWeights = obj.colorWeights/max(abs(obj.colorWeights));
                case 'M-iso'
                    obj.colorWeights = obj.quantalCatch(:,1:3)' \ [0 1 0]';
                    obj.colorWeights = obj.colorWeights/max(abs(obj.colorWeights));
                case 'S-iso'
                    obj.colorWeights = obj.quantalCatch(:,1:3)' \ [0 0 1]';
                    obj.colorWeights = obj.colorWeights/max(abs(obj.colorWeights));
                case 'LM-iso'
                    obj.colorWeights = obj.quantalCatch(:,1:3)' \ [1 1 0]';
                    obj.colorWeights = obj.colorWeights/max(abs(obj.colorWeights));
                case 'LMS-iso'
                    obj.colorWeights = obj.quantalCatch(:,1:3)' \ [1 1 1]';
                    obj.colorWeights = obj.colorWeights / max(abs(obj.colorWeights));
                otherwise
                    obj.colorWeights = [1 1 1];
            end

            obj.colorWeights = obj.colorWeights(:)';
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

            epoch.addParameter('frameRate', obj.frameRate);
            epoch.addParameter('stageClass', obj.stageClass);
            epoch.addParameter('ndf', obj.ndf);
            if obj.muPerPixel > 0
                epoch.addParameter('micronsPerPixel', obj.muPerPixel);
                epoch.addParameter('objectiveMag', obj.objectiveMag);
            end
            epoch.addParameter('maxLCone', sum(obj.quantalCatch(:,1)));
            epoch.addParameter('maxMCone', sum(obj.quantalCatch(:,2)));
            epoch.addParameter('maxSCone', sum(obj.quantalCatch(:,3)));
            epoch.addParameter('maxRod', sum(obj.quantalCatch(:,4)));

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

%         function completeEpoch(obj, epoch)
%             completeEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);
%
%             % Get the frame times and frame rate and append to epoch.
% %             [frameTimes, actualFrameRate] = obj.getFrameTimes(epoch);
% %             epoch.addParameter('frameTimes', frameTimes);
% %             epoch.addParameter('actualFrameRate', actualFrameRate);
%         end

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

        function response = getResponseByType(obj, response, onlineAnalysis)
            % Bin the data based on the type.
            %  'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'
            switch onlineAnalysis
                case 'extracellular'
                    response = wavefilter(response(:)', 6);
                    S = spikeDetectorOnline(response);
                    spikesBinary = zeros(size(response));
                    spikesBinary(S.sp) = 1;
                    response = spikesBinary * obj.sampleRate;
                case 'spikes_CClamp'
                    spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
                    spikesBinary = zeros(size(response));
                    spikesBinary(spikeTimes) = 1;
                    response = spikesBinary * obj.sampleRate;
                case 'subthresh_CClamp'
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
end