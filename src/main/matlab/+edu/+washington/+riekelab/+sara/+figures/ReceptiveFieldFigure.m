classdef ReceptiveFieldFigure < symphonyui.core.FigureHandler
% TODO - find peaks button

% 20Dec2016 - added RGB analysis
    properties (SetAccess = private)
        device
        recordingType
        numXChecks
        numYChecks
        noiseClass
        chromaticClass
        preTime
        stimTime
        frameRate
        numFrames
        stixelSize
    end

    properties (Access = private)
        axesHandle
        imgHandle
        strf
        spaceFilter
        xaxis
        yaxis
        timeBinSlider
        timeBin
        peakFinder
        peaksFound
        cmap
        RFsign
        showOnOff
    end

    methods

        function obj = ReceptiveFieldFigure(device, varargin)
            ip = inputParser();
            ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
            ip.addParameter('stixelSize', [], @(x)isfloat(x));
            ip.addParameter('numXChecks', [], @(x)isfloat(x));
            ip.addParameter('numYChecks', [], @(x)isfloat(x));
            ip.addParameter('noiseClass', 'binary', @(x)ischar(x));
            ip.addParameter('chromaticClass', 'achromatic', @(x)ischar(x));
            ip.addParameter('preTime',0.0, @(x)isfloat(x));
            ip.addParameter('stimTime',0.0, @(x)isfloat(x));
            ip.addParameter('frameRate',6.0, @(x)isfloat(x));
            ip.addParameter('numFrames',[], @(x)isfloat(x));

            ip.parse(varargin{:});

            obj.device = device;
            obj.recordingType = ip.Results.recordingType;
            obj.stixelSize = ip.Results.stixelSize;
            obj.numXChecks = ip.Results.numXChecks;
            obj.numYChecks = ip.Results.numYChecks;
            obj.noiseClass = ip.Results.noiseClass;
            obj.chromaticClass = ip.Results.chromaticClass;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameRate = ip.Results.frameRate;
            obj.numFrames = ip.Results.numFrames;

            % Set the x/y axes
            obj.xaxis = linspace(-obj.numXChecks/2,obj.numXChecks/2,obj.numXChecks)*obj.stixelSize;
            obj.yaxis = linspace(-obj.numYChecks/2,obj.numYChecks/2,obj.numYChecks)*obj.stixelSize;

            obj.cmap = 'bone';
            obj.RFsign = 'both';

            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;

            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            changeCmapButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Change colormap', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedChangeCmap);
            setIconImage(changeCmapButton, symphonyui.app.App.getResource('icons', 'sweep_store.png'));
            sendToWorkspaceButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Send to workspace',...
                'Separator', 'on',...
                'ClickedCallback', @obj.onSelectedStoreSweep);
            setIconImage(sendToWorkspaceButton, symphonyui.app.App.getResource('icons/sweep_store.png'));

            mainLayout = uix.VBox('Parent', obj.figureHandle, 'Padding', 10, 'Spacing', 5);

            if strcmp(obj.RFsign, 'both')
                obj.axesHandle = axes( ...
                    'Parent', mainLayout, ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto');
                obj.setTitle([obj.device.name 'mean receptive field']);
            else
                axLayout = uix.HBox('Parent', mainLayout, 'Spacing', 5, 'Padding', 10);
                obj.axesHandle(1) = axes('Parent', axLayout,...
                    'FontName', 'Roboto',...
                    'FontSize', 10,...
                    'XTickMode', 'auto');
                obj.axesHandle(2) = axes('Parent', axLayout,...
                    'FontName','Roboto',...
                    'FontSize', 10,...
                    'XTickMode', 'auto');
                obj.setTitle([obj.device.name 'mean receptive field']);
            end


            uiLayout = uix.HBox('Parent', mainLayout, 'Padding', 5, 'Spacing', 10);
            obj.timeBinSlider = uicontrol(uiLayout, 'Style', 'slider',...
                'Min', 0, 'Max', floor(obj.frameRate*0.5), 'Value', 0,...
                'SliderStep', [(1/floor(obj.frameRate*0.5)) 0.2],...
                'Callback', @obj.onChangedTimeBin);
            obj.timeBin = uicontrol(uiLayout, 'Style', 'text',...
                'String', 'mean',...
                'FontSize', 10,...
                'FontName', 'Roboto');
            obj.peakFinder = uicontrol(uiLayout, 'Style', 'push',...
                'String', 'Find peaks',...
                'FontSize', 10,...
                'FontName', 'Roboto',...
                'Callback', @obj.onSelectedFindPeaks);
            obj.showOnOff = uicontrol(uiLayout, 'Style', 'push',...
                'String', 'Show On/Off',...
                'FontSize', 10,...
                'FontName', 'Roboto',...
                'Callback', @obj.onSelectedShowOnOff);


            set(mainLayout, 'Heights', [-10 -1]);
            set(uiLayout, 'Widths', [-4 -1 -1 -1]);

            obj.strf = zeros(obj.numYChecks, obj.numXChecks, floor(obj.frameRate*0.5));
            obj.spaceFilter = [];

        end % createUi

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            if strcmp(obj.RFsign, 'both')
                title(obj.axesHandle, t);
            else
                title(obj.axesHandle(1), t);
                title(obj.axesHandle(2), t);
            end
        end

        function clear(obj)
            cla(obj.axesHandle);
            obj.strf = zeros(obj.numYChecks, obj.numXChecks, floor(obj.frameRate*0.5));
            obj.spaceFilter = [];
            % Set the x/y axes
            obj.xaxis = linspace(-obj.numXChecks/2,obj.numXChecks/2,obj.numXChecks)*obj.stixelSize;
            obj.yaxis = linspace(-obj.numYChecks/2,obj.numYChecks/2,obj.numYChecks)*obj.stixelSize;
        end

        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end

            response = epoch.getResponse(obj.device);
            [quantities, ~] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = obj.preTime*1e-3*sampleRate;

            if numel(quantities) > 0
                % Parse the response by type.
                y = responseByType(quantities, obj.recordingType, obj.preTime, sampleRate);

                if strcmp(obj.recordingType,'extracellular') || strcmp(obj.recordingType, 'spikes_CClamp')
                    y = BinSpikeRate(y(prePts+1:end), obj.frameRate, sampleRate);
                else
                    % Bandpass filter to get rid of drift.
                    y = bandPassFilter(y, 0.2, 500, 1/sampleRate);
                    if prePts > 0
                        y = y - median(y(1:prePts));
                    else
                        y = y - median(y);
                    end
                    y = binData(y(prePts+1:end), obj.frameRate, sampleRate);
                end

                % Make it the same size as the stim frames.
                y = y(1 : obj.numFrames);

                % Columate.
                y = y(:);

                % Pull the seed.
                seed = epoch.parameters('seed');

                % Get the frame/contrast sequence.
                frameValues = getSpatialNoiseFrames(obj.numXChecks, obj.numYChecks, ...
                    obj.numFrames, obj.noiseClass, obj.chromaticClass, seed);

                % Zero out the first second while cell is adapting to
                % stimulus.
                y(1 : floor(obj.frameRate)) = 0;
                if strcmpi(obj.chromaticClass, 'RGB')
                    frameValues(1 : floor(obj.frameRate),:,:,:) = 0;
                else
                    frameValues(1 : floor(obj.frameRate),:,:) = 0;
                end

                filterFrames = floor(obj.frameRate*0.5);
                lobePts = round(0.05*obj.frameRate) : round(0.15*obj.frameRate);

                % Perform reverse correlation.
                if strcmpi(obj.chromaticClass, 'RGB')
                    filterTmpC = zeros(3, obj.numYChecks, obj.numXChecks, filterFrames);
                      for l = 1 : 3
                        filterTmp = zeros(obj.numYChecks, obj.numXChecks,filterFrames);
                        for m = 1 : obj.numYChecks
                          for n = 1 : obj.numXChecks
                            tmp = ifft(fft([responseTrace; zeros(60,1)]) .* conj(fft([squeeze(stimulus(:,m,n,l)); zeros(60,1);])));
                            filterTmp(m,n,:) = tmp(1 : filterFrames);
                            filterTmpC(l,m,n,:) = tmp(1:filterFrames);
                          end
                        end
                    end
                    obj.strf = obj.strf + filterTmpC;
                    obj.spatialRF = squeeze(mean(obj.strf(l,:,:,lobePts),4));
                else
                    filterTmp = zeros(obj.numYChecks, obj.numXChecks, filterFrames);
                    for m = 1 : obj.numYChecks
                        for n = 1 : obj.numXChecks
                            tmp = ifft(fft([y; zeros(60,1)]) .* conj(fft([squeeze(frameValues(:,m,n)); zeros(60,1);])));
                            filterTmp(m,n,:) = tmp(1 : filterFrames);
                        end
                    end
                    obj.strf = obj.strf + filterTmp;
                    obj.spaceFilter = squeeze(mean(obj.strf(:,:,lobePts),3));
                end

                % Display the spatial RF.
                slider_value = get(obj.timeBinSlider, 'Value');
                if slider_value == 0 % mean RF
                    obj.imgHandle = imagesc('XData',obj.xaxis,'YData',obj.yaxis,...
                        'CData', obj.spaceFilter, 'Parent', obj.axesHandle);
                else
                    obj.imgHandle = imagesc('XData', obj.xaxis, 'YData', obj.yaxis,...
                        'CData', squeeze(obj.strf(:,:,slider_value)), 'Parent', obj.axesHandle);
                end
                axis(obj.axesHandle, 'image');
                colormap(obj.axesHandle, obj.cmap);
            end
        end % handleEpoch
    end % methods

    methods (Access = private)
    function onSelectedChangeCmap(obj, ~, ~)
        if strcmp(obj.cmap, 'parula')
            obj.cmap = 'bone';
        elseif strcmp(obj.cmap, 'bone')
            obj.cmap = pmkmp(126,'cubicYF');
        elseif strcmp(obj.cmap, 'cubicYF')
            obj.cmap = pmkmp(126, 'cubicL');
        elseif strcmp(obj.cmap, 'cubicL')
            obj.cmap = 'parula';
        end
        colormap(obj.axesHandle, obj.cmap);
    end

    function onSelectedFindPeaks(obj,~,~)
        fprintf('Debug: the noise class is %s\n', obj.noiseClass);

    end

    function onSelectedShowOnOff(obj,~,~)
        if strcmp(obj.RFsign, 'both')
            obj.RFsign = 'onoff';
        else
            obj.RFsign = 'both';
        end
        % later just on and just off - not too important though
        % won't update until next epoch comes through
    end

    function onChangedTimeBin(obj,~,~)
        slider_value = get(obj.timeBinSlider, 'Value');

        if slider_value > size(obj.strf,3)
            error('slider value exceeds strf time bins');
        end

        if slider_value == 0 % mean spatial RF
            set(obj.imgHandle, 'CData', obj.spaceFilter);
            obj.setTitle([obj.device.name 'mean receptive field']);
            set(obj.timeBin, 'String', 'mean RF');
        else
            tmpSpaceFilter = squeeze(obj.strf(:,:, slider_value));
            set(obj.imgHandle, 'CData', tmpSpaceFilter);
            set(obj.timeBin, 'String', sprintf('t = %u', slider_value));
            obj.setTitle([obj.device.name sprintf('receptive field at t=%u', slider_value)]);
        end
    end

    function onSelectedStoreSweep(obj,~,~)
        strf = obj.strf;
        answer = inputdlg('Save to workspace as:', 'save dialog', 1, {'r'});
        fprintf('%s new grating named %s\n', datestr(now), answer{1});
        assignin('base', sprintf('%s', answer{1}), strf);
    end

end % methods private
end % classdef
