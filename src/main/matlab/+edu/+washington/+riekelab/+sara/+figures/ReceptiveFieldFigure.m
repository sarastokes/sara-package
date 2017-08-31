classdef ReceptiveFieldFigure < symphonyui.core.FigureHandler
    % 20Dec2016 - added RGB analysis
    % 24Aug2017 - code cleanup, added strfViewer.m code
    properties (SetAccess = private)
        device
        preTime
        stimTime
        recordingType
        stixelSize
        canvasSize
        noiseClass
        chromaticClass
        frameRate
        frameDwell
        aperture
    end
    
    properties (Access = private)
        handles
        data
        things
        
        strf
    end
    
    methods
        
        function obj = ReceptiveFieldFigure(device, preTime, stimTime, varargin)
            obj.device = device;
            obj.preTime = preTime;
            obj.stimTime = stimTime;
            
            ip = inputParser();
            ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
            ip.addParameter('stixelSize', [], @(x)isnumeric(x));
            ip.addParameter('canvasSize', [], @(x)isvector(x));
            ip.addParameter('noiseClass', 'binary', @(x)ischar(x));
            ip.addParameter('chromaticClass', 'achromatic', @(x)ischar(x));
            ip.addParameter('frameRate', 60, @(x)isnumeric(x));
            ip.addParameter('frameDwell',[], @(x)isnumeric(x));
            ip.addParameter('aperture', 0, @(x)isnumeric(x));
            
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.recordingType = ip.Results.recordingType;
            obj.stixelSize = ip.Results.stixelSize;            
            obj.noiseClass = ip.Results.noiseClass;
            obj.chromaticClass = ip.Results.chromaticClass;
            obj.frameRate = ip.Results.frameRate;
            obj.frameDwell = ip.Results.frameDwell;
            obj.aperture = ip.Results.aperture;
            
            % Initialize variables
            obj.things.stixels = ceil(obj.canvasSize / obj.stixelSize);
            obj.things.xaxis = linspace(-obj.things.stixels(1)/2,... 
                obj.things.stixels(1)/2,...
                obj.things.stixels(1)) * obj.stixelSize;
            obj.things.yaxis = linspace(-obj.things.stixels(2)/2,... 
                obj.things.stixels(2)/2,...
                obj.things.stixels(2)) * obj.stixelSize;
            obj.things.numFrames = floor(obj.stimTime/1000 ... 
                * obj.frameRate/obj.frameDwell);

            
            obj.strf = zeros(obj.stixels(2), obj.stixels(1),... 
                floor(obj.frameRate*0.5));
            
            obj.things.cmap = 'bone';
            obj.flags.avg = true;
            obj.flags.filt = false;
                        
            obj.createUi();
        end
        
        function createUi(obj)
            import appbox.*;
            
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            
            workspaceButton = uipushtool(...
                'Parent', toolbar,...
                'TooltipString', 'Send to workspace',...
                'Separator', 'on',...
                'ClickedCallback', @obj.sendData);
            setIconImage(workspaceButton,...
                symphonyui.app.App.getResource('icons/sweep_store.png'));
            
            mainLayout = uix.VBox('Parent', obj.figureHandle,...
                'Padding', 10, 'Spacing', 5);
            
            obj.handles.ax = axes( ...
                'Parent', mainLayout, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            obj.setTitle([obj.device.name 'mean receptive field']);
            
            uiLayout = uix.HBox('Parent', mainLayout,...
                'Padding', 5, 'Spacing', 10);
            obj.handles.sl.timeBin = uicontrol(uiLayout,...
                'Style', 'slider',...
                'Min', 0, 'Max', floor(obj.frameRate*0.5), 'Value', 0,...
                'SliderStep', [(1/floor(obj.frameRate*0.5)) 0.2]);
            obj.handles.sl.timeBinJ = findjobj(obj.handles.sl.azimuth);
            set(obj.handles.sl.timeBinJ,...
                'AdjustmentValueChangedCallback', @obj.changeTimeBin);
            obj.handles.tx.timeBin = uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'mean');
            
            avgLayout = uix.VBox('Parent', uiLayout);
            obj.handles.tbl.avg = uitable(avgLayout,...
                'Data', [3 5],...
                'ColumnEditable', true,...
                'RowName', [],...
                'ColumnName', []);
            obj.handles.pb.avg = uicontrol(avgLayout,...
                'Style', 'push',...
                'Callback', @obj.strfType);
            obj.handles.pb.pks = uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Find peaks',...
                'Callback', @obj.findPeaks);
            filtLayout = uix.VBox('Parent', uiLayout);
            obj.handles.pb.filt = uicontrol(filtLayout,...
                'Style', 'push',...
                'String', 'gauss filter',...
                'Callback', @obj.gaussFilt);
            obj.handles.ed.filt = uicontrol(filtLayout,...
                'Style', 'edit',...
                'String', 'sigma',...
                'TooltipString', 'Sigma for gaussian filter');
            obj.handles.pb.units = uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Change units',...
                'TooltipString', 'Change units to microns',...
                'Callback', @obj.changeUnits);
            
            set(mainLayout, 'Heights', [-10 -1]);
            set(uiLayout, 'Widths', [-4 -1 -1 -1]);
            set(findall(obj.figureHandle, 'Type', 'uicontrol'),...
                'BackgroundColor', 'w',...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'));
        end % createUi
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.handles.ax, t);
        end
        
        function clear(obj)
            cla(obj.handles.ax);
            obj.strf = zeros(obj.stixels(2), obj.stixels(1),... 
                floor(obj.frameRate*0.5));
            % Set the x/y axes
            obj.xaxis = linspace(-obj.things.stixels(1)/2,... 
                obj.things.stixels(1)/2,...
                obj.things.stixels(1)) * obj.stixelSize;
            obj.yaxis = linspace(-obj.things.stixels(2)/2,... 
                obj.things.stixels(2)/2,...
                obj.things.stixels(2)) * obj.things.stixelSize;
        end
        
        function handleEpoch(obj, epoch)
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            response = epoch.getResponse(obj.device);
            [quantities, ~] = response.getData();
            sampleRate = response.sampleRate.quantityInBaseUnits;
            prePts = obj.preTime * 1e-3 * sampleRate;
            seed = epoch.parameters('seed');
            
            y = responseByType(quantities, obj.recordingType,...
                obj.preTime, sampleRate);
            switch obj.recordingType
                case {'extracellular', 'spikes_CClamp'}
                    y = BinSpikeRate(y(prePts+1:end), obj.frameRate, sampleRate);
                otherwise
                    y = bandPassFilter(y, 0.2, 500, 1/sampleRate);
                    if prePts > 0
                        y = y - median(y(1:prePts));
                    else
                        y = y - median(y);
                    end
                    y = binData(y(prePts+1:end), obj.frameRate, sampleRate);
            end
            
            y = y(1 : obj.things.numFrames);
            y = y(:);
            y(1:floor(obj.frameRate)) = 0;
            
            frameValues = getSpatialNoiseFrames(obj.stixels(1), obj.stixels(2),...
                obj.things.numFrames, obj.noiseClass, obj.chromaticClass, seed);
            
            if strcmpi(obj.chromaticClass, 'RGB')
                frameValues(1 : floor(obj.frameRate),:,:,:) = 0;
            else
                frameValues(1 : floor(obj.frameRate),:,:) = 0;
            end
            
            filterFrames = floor(obj.frameRate*0.5);
            %lobePts = round(0.05*obj.frameRate):round(0.15*obj.frameRate);
            lobePts = [3 5] * obj.frameRate/obj.frameDwell;
            
            if strcmpi(obj.chromaticClass, 'RGB')
                filterTmpC = zeros(3, obj.stixels(2), obj.stixels(1), filterFrames);
                for l = 1 : 3
                    filterTmp = zeros(obj.stixels(2), obj.stixels(1),filterFrames);
                    for m = 1 : obj.stixels(2)
                        for n = 1 : obj.stixels(1)
                            tmp = ifft(fft([responseTrace; zeros(60,1)]) .* ... 
                                conj(fft([squeeze(stimulus(:,m,n,l)); zeros(60,1);])));
                            filterTmp(m,n,:) = tmp(1 : filterFrames);
                            filterTmpC(l,m,n,:) = tmp(1:filterFrames);
                        end
                    end
                end
                obj.strf = obj.strf + filterTmpC;
                spatialRF = squeeze(mean(obj.strf(l,:,:,lobePts),4));
            else
                filterTmp = zeros(obj.stixels(2), obj.stixels(1), filterFrames);
                for m = 1 : obj.stixels(2)
                    for n = 1 : obj.stixels(1)
                        tmp = ifft(fft([y; zeros(60,1)]) .* ... 
                            conj(fft([squeeze(frameValues(:,m,n)); zeros(60,1);])));
                        filterTmp(m,n,:) = tmp(1 : filterFrames);
                    end
                end
                obj.strf = obj.strf + filterTmp;
                spatialRF = squeeze(mean(obj.strf(:,:,lobePts),3));
            end
            
            if obj.flags.avg
                obj.handles.im = imagesc('Parent', obj.handles.ax,...
                    'XData', obj.things.xaxis, 'YData', obj.things.yaxis,...
                    'CData', spatialRF);
            else
                % t = get(obj.handles.sl.timeBin, 'Value');
                obj.handles.im = imagesc('Parent', obj.handles.ax,...
                    'XData', obj.things.xaxis, 'YData', obj.things.yaxis,...
                    'CData', squeeze(obj.strf(:,:,obj.handles.sl.timeBin.Value)));
            end
            axis(obj.handles.ax, 'image');
            colormap(obj.handles.ax, obj.things.cmap);
        end % handleEpoch
    end % methods
    
    methods (Access = private)
        function gaussFilt(obj, ~, ~)
            % GAUSSFILT  Filter displayed strf with gaussian
            if obj.flags.filt
                obj.flags.filt = false;
                return;
            else
                obj.flags.filt = true;
            end
            
            if isletter(get(obj.handles.ed.filt, 'String'))
                warndlg('Set sigma to a number');
                return;
            else
                obj.things.filtFac = str2double(obj.handles.ed.filt.String);
            end
            
            set(obj.handles.im, 'CData',...
                imgaussfilt(obj.handles.im.CData, obj.things.filtFac));
        end % gaussfilt
        
        function changeCmap(obj, ~, ~)
            % CHANGECMAP  Switch colormap
            cmapList = {'Bone', 'CubicL', 'Viridis', 'RedBlue', 'Parula'};
            ind = find(ismember(obj.things.cmap, cmapList));
            switch obj.things.cmap
                case 'CubicL'
                    colormap(obj.handles.ax, pmkmp(256, 'CubicL'));
                case 'Viridis'
                    colormap(obj.handles.ax, viridis(256));
                case 'RedBlue'
                    colormap(obj.handles.ax, lbmap(256, 'RedBlue'));
                otherwise
                    colormap(obj.handles.ax, obj.things.cmap);
            end
        end % changeCmap
        
        function findPeaks(obj, ~, ~)
            fprintf('Debug: the noise class is %s\n', obj.noiseClass);
        end
        
        function changeTimeBin(obj,~,~)
            t = get(obj.handles.sl.timeBin, 'Value');
            
            if t > size(obj.strf, 3)
                return;
            end
            set(obj.handles.im, 'CData', squeeze(obj.strf(:,:,t)));
            set(obj.handles.tx.timeBin, 'String', sprintf('bin = %u', t));
        end
        
        function avgStrf(obj, ~, ~)
            % AVGSTRF  Get timebin average or return to a single bin
            if obj.flags.avg
                obj.flags.avg = false;
                t = get(obj.handles.sl.timeBin, 'Value');
                set(obj.handles.im, 'CData', squeeze(obj.strf(:,:,t)));
            else
                obj.flags.avg = true;
            end
        end % avgStrf
        
        function changeUnits(obj, src, ~)
            % CHANGEUNITS  Switch between pixels and microns
            switch src.String(5:end)
                case 'microns'
                    obj.xaxis = obj.xaxis / obj.pix2micron;
                    obj.yaxis = obj.yaxis / obj.pix2micron;
                case 'pixels'
                    obj.xaxis = obj.xaxis * obj.pix2micron;
                    obj.yaxis = obj.yaxis * obj.pix2micron;
            end
            set(obj.handles.im, 'XData', obj.xaxis, 'YData', obj.yaxis);
        end % changeUnits
        
        function sendData(obj,~,~)
            strf = obj.strf;
            answer = inputdlg('Save to workspace as:',...
                'save dialog', 1, {'r'});
            fprintf('%s new grating named %s\n',...
                datestr(now), answer{1});
            assignin('base', sprintf('%s', answer{1}), strf);
        end
        
    end % methods private
end % classdef
