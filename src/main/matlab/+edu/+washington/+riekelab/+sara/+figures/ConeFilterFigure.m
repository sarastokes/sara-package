classdef ConeFilterFigure < symphonyui.core.FigureHandler
    % 28Aug2017 - SSP - cleaned up, removed demoMode,
    %       frameMonitor issues so removed that code
    properties (SetAccess = private)
        % required:
        device
        filtWheel
        preTime
        stimTime
        stDev
        % optional:
        recordingType
        frameDwell
        frameRate
    end
    
    properties (SetAccess = private)
        handles % contains all UI handles        
        cellData % stores analyzed linear filters and nonlinearities
        nextStimulus % holds future parameters
        nextCone % a list of next chromaticClass
    end
    
    properties (Hidden)
        epochNum % tracks epochs       
        coneInd % current cone as #
  
        % protocol control properties
        ignoreNextEpoch = false
        addNullEpoch = false
        ledNeedsToChange = false
        protocolShouldStop = false
    end
    
    properties (Constant, Hidden)
        CONES = 'lmsa' % cone stim options, may add lm-iso
        
        % not really worth making editable parameters right now
        BINSPERFRAME = 6
        FILTERLENGTH = 1000
        NONLINEARITYBINS = 200

        LEDMONITOR = true % monitor green LED vs cone-iso
 
        DEMOGAUSS = false % use old data for debugging
    end
    
    
    methods
        function obj = ConeFilterFigure(device, filtWheel, preTime, stimTime, varargin)
            obj.device = device;
            obj.filtWheel = filtWheel;
            obj.preTime = preTime;
            obj.stimTime = stimTime;
            
            ip = inputParser();
            ip.addParameter('stDev', 0.3, @(x)isnumeric(x));
            ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
            ip.addParameter('frameDwell', 1, @(x)isnumeric(x));
            ip.addParameter('frameRate', 60, @(x)isnumeric(x));
            ip.parse(varargin{:});
            obj.recordingType = ip.Results.recordingType;
            obj.frameDwell = ip.Results.frameDwell;
            obj.frameRate = ip.Results.frameRate;
            obj.stDev = ip.Results.stDev;
            
            obj.epochNum = 0;
            
            % init some plot flags
            obj.handles.flags.smoothFilt = false;
            obj.handles.flags.normPlot = false;
            
            % create the UI handles
            obj.createUi();
            
            % init the data structures
            obj.cellData.filterMap = containers.Map;
            obj.cellData.xnlMap = containers.Map;
            obj.cellData.ynlMap = containers.Map;
            
            % set to zero which flags a new cone type
            for ii = 1:length(obj.CONES)
                obj.cellData.filterMap(obj.CONES(ii)) = 0;
                obj.cellData.xnlMap(obj.CONES(ii)) = 0;
                obj.cellData.ynlMap(obj.CONES(ii)) = 0;
            end
            
            % this figure controls one protocol parameters:
            obj.nextStimulus.cone = [];
            
            % this waits until more stimuli are added to the queue
            obj.waitForStim();
            
            if ~isvalid(obj)
                fprintf('Not valid object\n');
                return;
            end
            
            % this runs at the very end of each epoch, sets the next epoch
            obj.assignNextStimulus();
            
            % reflect changes in stimulus assignment
            obj.updateUi();
        end % constructor
        
        function createUi(obj)
            import appbox.*;
            
            % FIGURE
            set(obj.figureHandle, 'Name', 'Cone Filter Figure',...
                'Color', 'w',...
                'NumberTitle', 'off');
            
            % TOOLBAR
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            
            debugButton = uipushtool('Parent', toolbar,...
                'TooltipString', 'send obj to wkspace',...
                'Separator', 'on',...
                'ClickedCallback', @obj.sendData);
            setIconImage(debugButton, symphonyui.app.App.getResource( ...
                'icons', 'modules.png'));
            
            % LAYOUTS
            mainLayout = uix.HBox('Parent', obj.figureHandle);
            % This layout contains the plot and data table
            resultLayout = uix.VBox('Parent', mainLayout);
            plotLayout = uix.HBoxFlex('Parent', resultLayout);
            dataLayout = uix.HBox('Parent', resultLayout);
            % This layout contains the protocol control buttons
            uiLayout = uix.VBox('Parent', mainLayout);
            set(mainLayout, 'Widths', [-4 -1]);
            
            % AXES: linear filter and nonlinearity
            obj.handles.ax.lf = axes(plotLayout,...
                'XTickMode', 'auto',...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            xlabel(obj.handles.ax.lf, 'Time (ms)');
            title(obj.handles.ax.lf, 'Linear Filter');
            obj.handles.ax.nl = axes(plotLayout,...
                'XTickMode', 'auto',...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'));
            xlabel(obj.handles.ax.nl, 'Linear prediction');
            ylabel(obj.handles.ax.nl, 'Meaured');
            title(obj.handles.ax.nl, 'Nonlinearity');
            set(plotLayout, 'Widths', [-1.5 -1]);
            
            % DATA TABLE
            obj.handles.dataTable = uitable('Parent', dataLayout);
            set(obj.handles.dataTable, 'Data', zeros(4,4),...
                'ColumnName', {'N','T2P', 'ZC', 'BI'},...
                'RowName', {'L', 'M', 'S', 'A'},...
                'ColumnEditable', false);
            
            % PLOT DISPLAY CONTROLS
            paramLayout = uix.VBox('Parent', dataLayout);
            % Control the linear filter graph XLim
            xlimLayout = uix.HBox('Parent', paramLayout);
            obj.handles.pb.changeXLim = uicontrol(xlimLayout,...
                'Style', 'push',...
                'String', 'Change xlim',...
                'Callback', @obj.changeXLim);
            obj.handles.ed.changeXLim = uicontrol(xlimLayout,...
                'Style', 'edit',...
                'String', '1000');
            set(xlimLayout, 'Widths', [-3 -1]);
            
            % Smooth the data points
            smoothLayout = uix.HBox('Parent', paramLayout);
            obj.handles.cb.smoothFilt = uicontrol(smoothLayout,...
                'String', 'Smooth filters',...
                'Style', 'checkbox',...
                'Callback', @obj.smoothFilters);
            obj.handles.ed.smoothFac = uicontrol(smoothLayout,...
                'Style', 'edit',...
                'String', '0');
            set(smoothLayout, 'Widths', [-3 -1]);
            
            % Normalize the filters for easy comparison
            obj.handles.cb.normPlot = uicontrol(paramLayout,...
                'String', 'Normalize',...
                'Style', 'checkbox',...
                'Callback', @obj.normPlot);
            
            set(paramLayout, 'Heights', [-1 -1 -1]);
            set(resultLayout, 'Heights', [-2 -1]);
            set(dataLayout, 'Widths', [-2 -1]);
            
            % STIMULUS CONTROL
            uicontrol('Parent', uiLayout,...
                'Style', 'text',...
                'String', 'Stimulus queue:');
            obj.handles.tx.queue = uicontrol(uiLayout,...
                'Style', 'text',...
                'String', '');
            obj.handles.ed.queue = uicontrol(uiLayout,...
                'Style', 'edit',...
                'String', '');
            obj.handles.pb.addToQueue = uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'UpdateQueue',...
                'Callback', @obj.updateQueue);
            obj.handles.pb.clearQueue = uicontrol(uiLayout,...
                'Style', 'push',...
                'String', 'Clear queue',...
                'Callback', @obj.clearQueue);
            
            % PROTOCOL DISPLAY
            obj.handles.tx.curEpoch = uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Current Epoch: -');
            obj.handles.tx.nextEpoch = uicontrol(uiLayout,...
                'Style', 'text',...
                'String', 'Next Epoch: -');
            % PROTOCOL CONTROL
            uicontrol('Parent', uiLayout,...
                'Style', 'push',...
                'String', 'Resume Protocol',...
                'Callback', @(a,b) obj.resumeProtocol());
        end % createUi
        
        function handleEpoch(obj, epoch)
            % basic plan: each epoch gets a newFilter (and NL)
            % which is added to existing filters in cellData.
            % after analysis, the next stimulus is assigned
            
            if obj.ignoreNextEpoch
                disp('ignoring epoch');
                epoch.shouldBePersisted = false;
                obj.assignNextStimulus();
                obj.ignoreNextEpoch = false;
                return;
            end
            
            obj.epochNum = obj.epochNum + 1;
            cone = epoch.parameters('coneClass');
            fprintf('figure - handleEpoch - protocol saved %s\n', cone);
            
            %% ANALYSIS ---------------------------------------------
            if obj.DEMOGAUSS
                %load('C:\Users\Sara Patterson\Documents\MATLAB\demoGauss.mat')
                load('C:\Users\sarap\Google Drive\Symphony\sara-package\utils\demoGauss.mat')
                epochResponseTrace = demoGauss.resp(obj.epochNum, :);
                currentNoiseSeed = demoGauss.seed(obj.epochNum);
                sampleRate = 10000;
            else
                % this is where the real linear filter analysis goes
                response = epoch.getResponse(obj.device);
                epochResponseTrace = response.getData();
                sampleRate = response.sampleRate.quantityInBaseUnits;
                currentNoiseSeed = epoch.parameters('seed');
            end
            prePts = sampleRate * obj.preTime/1000;
            
            numFrames = floor(obj.stimTime/1000 * obj.frameRate)/obj.frameDwell;
            
            binRate = obj.BINSPERFRAME * obj.frameRate;
            
            resp = responseByType(epochResponseTrace, obj.recordingType,...
                obj.preTime, sampleRate);
            resp = BinSpikeRate(resp(prePts+1:end), binRate, sampleRate);
            resp = resp(:)';
            
            noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);
            stimulus = obj.stDev * noiseStream.randn(numFrames, 1);
            if obj.frameDwell > 1
                stimulus = ones(obj.frameDwell,1) * stimulus(:)';
            end
            stimulus = stimulus(:);
            
            if binRate > obj.frameRate
                n = round(binRate / obj.frameRate);
                stimulus = ones(n,1)*stimulus(:)';
                stimulus = stimulus(:);
            end
            
            resp = resp(1 : length(stimulus));
            stimulus(1:round(binRate/2)) = 0;
            resp(1:round(binRate/2)) = 0;
            
            % reverse correlation
            newFilter = real(ifft(fft([resp(:)', zeros(1,60)]) .* ...
                conj(fft([stimulus(:)', zeros(1,60)]))));
            
            %% ----------------------------------------- store filter -----
            plotLngth = round(binRate*0.5);
            if obj.cellData.filterMap(cone) == 0
                obj.cellData.filterMap(cone) = newFilter;
                obj.handles.lf(obj.coneInd) = line('Parent', obj.handles.ax.lf,...
                    'XData', (1:plotLngth)/binRate, 'YData', newFilter(1:plotLngth),...
                    'Color', getPlotColor(cone), 'LineWidth', 1);
            else
                tmp = mean(obj.cellData.filterMap(cone), 1);
                obj.cellData.filterMap(cone) = [obj.cellData.filterMap(cone); newFilter];
                set(obj.handles.lf(obj.coneInd), 'YData', tmp(1:plotLngth));
            end
            
            %% ------------------------------------------ nonlinearity ----
            resp = binData(resp, 60, binRate);
            
            % convolve stimulus with filter
            pred = ifft(fft([stimulus(:)' zeros(1,60)]) .* fft(newFilter(:)'));
            pred = binData(pred, 60, binRate);
            pred = pred(:)';
            
            if obj.cellData.ynlMap(cone) == 0
                obj.cellData.ynlMap(cone) = resp(:)';
                obj.cellData.xnlMap(cone)  = pred(1:length(resp));
                [xBin, yBin] = obj.getNL(obj.cellData.xnlMap(cone),...
                    obj.cellData.ynlMap(cone));
                obj.handles.nl(obj.coneInd) = line('Parent', obj.handles.ax.nl,...
                    'XData', xBin, 'YData', yBin,...
                    'Color', getPlotColor(cone),...
                    'LineWidth', 0.5);
                % 'Marker', '.', 'LineStyle', 'none');
            else % existing
                obj.cellData.xnlMap(cone) = cat(2, obj.cellData.xnlMap(cone),...
                    pred(1 : length(resp)));
                obj.cellData.ynlMap(cone) = cat(2, obj.cellData.ynlMap(cone), resp(:)');
                [xBin, yBin] = obj.getNL(obj.cellData.xnlMap(cone),...
                    obj.cellData.ynlMap(cone));
                set(obj.handles.nl(obj.coneInd),...
                    'XData', xBin, 'YData',yBin);
            end
            
            %% ---------------------------------------- filter stats ------
            % calculate time to peak, zero cross, biphasic index
            if abs(min(newFilter)) > max(newFilter)
                filterSign = -1;
                t = (newFilter > 0);
                t(1:find(newFilter == min(newFilter), 1)) = 0;
                t = find(t == 1, 1);
                if ~isempty(t)
                    zc = t/length(newFilter) * obj.FILTERLENGTH;
                else
                    zc = 0;
                end
            else
                filterSign = 1;
                t = (newFilter < 0);
                t(1:find(newFilter == max(newFilter), 1)) = 0;
                t = find(t == 1, 1);
                if ~isempty(t)
                    zc = t/length(newFilter) * obj.FILTERLENGTH;
                else
                    zc = 0;
                end
            end
            
            [loc, pk] = peakfinder(newFilter, [], [], filterSign);
            [~, ind] = max(abs(pk));
            
            try
                t2p = xpts(loc(ind));
            catch
                t2p = 0;
            end
            try
                bi = abs(min(newFilter) / max(newFilter));
            catch
                bi = 0;
            end
            
            % send stats to the data table
            try
                obj.updateDataTable([t2p, zc, bi]);
            catch
                fprintf('%s - Data table did not update\n', datestr(now));
                fprintf('   t2p = %.2f, zc = %.2f, bi = %.2f\n', [t2p, zc, bi]);
            end
            
            %% ------------------------------------------------ stimuli ---
            obj.updateFilterPlots();
            obj.waitForStim();
            
            if ~isempty(obj.nextStimulus.cone) && obj.LEDMONITOR
                obj.checkNextCone();
            end
            
            if ~isvalid(obj)
                return;
            end
            
            % set the next epoch's stimulus
            obj.assignNextStimulus();
            
            % reflect in the ui
            obj.updateUi();
        end % handleEpoch
        
        %% ------------------------------------------------- callbacks ----
        function normPlot(obj,~,~)
            % NORMPLOT  Normalize the linear filters
            if get(obj.handles.cb.normPlot, 'Value') == get(obj.handles.cb.normPlot, 'Max')
                obj.handles.flags.normPlot = true;
            else
                obj.handles.flags.normPlot = false;
            end
            
            obj.updateFilterPlot();
        end % normPlot
        
        function smoothFilters(obj,~,~)
            % SMOOTHFILTERS  Smooth filters by n
            if get(obj.handles.cb.smoothFilt, 'Value') == 1
                obj.handles.flags.smoothFilt = true;
                try
                    obj.handles.values.smoothFac = str2double(get(obj.handles.ed.smoothFac, 'String'));
                catch
                    warndlg('Check smooth factor, setting smoothFilt to false');
                    obj.handles.flags.smoothFilt = false;
                    set(obj.handles.cb.smoothFilt, 'Value', 0);
                    return;
                end
            else
                obj.handles.flags.smoothFilt = false;
            end
            
            obj.updateFilterPlot();
        end % smoothFilters
        
        function changeXLim(obj,~,~)
            % CHANGEXLIM  Change the x-axis of linear filter plot
            set(obj.handles.ax.lf, 'XLim',...
                [0 str2double(get(obj.handles.ed.changeXLim, 'String'))]);
        end % changeXLim
        
        function updateQueue(obj,~,~)
            % UPDATEQUEUE  Appends to existing queue
            x = get(obj.handles.tx.queue, 'String');
            x = [x get(obj.handles.ed.queue, 'String')];
            set(obj.handles.tx.queue, 'String', x);
            obj.addStimuli(get(obj.handles.ed.queue, 'String'));
        end % updateQueue
        
        function clearQueue(obj,~,~)
            % CLEARQUEUE  Clears stimuli in queue
            obj.nextStimulus.cone = [];
            obj.updateUi();
        end % clearQueue
        
        %% ------------------------------------------------ main -----------
        function updateFilterPlot(obj)
            % this method applies smooth, normalize, etc to exisiting plot
            for ii = 1:length(obj.CONES)
                if obj.cellData.filterMap(obj.CONES(ii)) ~=0
                    if obj.handles.flags.smoothFilt
                        set(obj.handles.lf(ii), 'YData',...
                            smooth(obj.handles.lf(ii).YData, obj.smoothFac));
                    end
                    if obj.handles.flags.normPlot
                        set(obj.handles.lf(ii), 'YData',...
                            obj.handles.lf(ii).YData / max(abs(obj.handles.lf(ii).YData)));
                    end
                end
            end
        end % updateFilterPlot
        
        
        function updateDataTable(obj, stats)
            % UPDATEDATATABLE  Add time to peak, biphasic index, zero cross
            tableData = get(obj.handles.dataTable, 'Data');
            if tableData(obj.coneInd, 1) == 0
                for ii = 2:4
                    tableData(obj.coneInd, 2:4) = stats;
                end
            else
                for ii = 2:4
                    tableData(obj.coneInd, ii) = obj.stepMean(tableData(obj.coneInd, ii),...
                        tableData(obj.coneInd, 1), stats(1,ii-1));
                end
            end
            % update count after used for finding new mean
            tableData(obj.coneInd, 1) = tableData(obj.coneInd, 1) + 1;
            
            set(obj.handles.dataTable, 'Data', tableData);
        end % updateDataTable
        
        function updateUi(obj)
            % UPDATEUI  Update user interface to reflect the next epoch
            if obj.ignoreNextEpoch
                obj.handles.tx.curEpoch.String = 'NULL EPOCH';
            else
                obj.handles.tx.curEpoch.String = ['Stim Epoch: ',...
                    obj.nextCone];
            end
            
            % show the next stimulus
            if isempty(obj.nextStimulus.cone)
                obj.handles.tx.nextEpoch.String = 'no next stim!';
            else
                obj.handles.tx.nextEpoch.String = ['Next epoch: ',...
                    obj.nextStimulus.cone(1)];
            end
            
            % update stimulus queue:
            % this will reflect epochNum + 2
            obj.handles.tx.queue.String = obj.nextStimulus.cone;
        end % updateUi
        
        %% ----------------------------------------------- support --------
        function clearFigure(obj)
            obj.resetPlots();
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.cellData = [];
            obj.epochNum = 0;
            obj.protocolShouldStop = false;
            obj.nextStimulus.cone = [];
        end % resetPlots
        
        %% ---------------------------------------------- protocol --------
        function checkNextCone(obj)
            % CHECKNEXTCONE  Reminder of when the green LED needs to change
            obj.ledNeedsToChange = false;
            % get the filter wheel
            fw = obj.filtWheel;
            if ~isempty(fw)
                % get the current green LED setting
                greenLEDName = obj.filtWheel.getGreenLEDName();
                % check to see if it's compatible with currentCone
                if strcmp(greenLEDName, 'Green_570nm')
                    if ~strcmp(obj.nextStimulus.cone(1), 's')
                        obj.ledNeedsToChange = true;
                        msgbox('Change green LED to 505nm', 'LED monitor');
                        obj.waitForLED();
                    end
                elseif strcmp(greenLEDName, 'Green_505nm')
                    if strcmp(obj.nextStimulus.cone(1), 's')
                        obj.ledNeedsToChange = true;
                        msgbox('Change green LED to 570nm', 'LED monitor');
                        obj.waitForLED();
                    end
                end
            end
        end % checkNextCone
        
        function addStimuli(obj, newCones)
            % ADDSTIMULI  Appends stimuli letters to queue
            % TODO: some kind of input validation?
            % add to stimulus queue
            obj.nextStimulus.cone = [obj.nextStimulus.cone newCones];
            % reflect changes in the stimulus queue
            set(obj.handles.tx.queue, 'String', obj.nextStimulus.cone);
        end % addStimuli
        
        
        function assignNextStimulus(obj)
            % ASSIGNNEXTSTIMULUS  Sets up the next epoch after handleEpoch
            if obj.addNullEpoch
                disp('adding null epoch - no stimuli');
                obj.ignoreNextEpoch = false;
                obj.addNullEpoch = false;
                obj.nextStimulus.cone = [obj.nextStimulus.cone(1),...
                    obj.nextStimulus.cone];
            elseif obj.ledNeedsToChange
                % keeping these two apart for now
                disp('adding null epoch - led change');
                obj.ignoreNextEpoch = false;
                obj.addNullEpoch = false;
                obj.nextStimulus.cone = [obj.nextStimulus.cone(1),...
                    obj.nextStimulus.cone];
            else
                disp('adding normal epoch');
                obj.ignoreNextEpoch = false;
                obj.addNullEpoch = false;
            end
            
            % just chromatic class for now
            fprintf('figure - setting next cone to %s\n',... 
                obj.nextStimulus.cone(1));
            obj.nextCone = obj.nextStimulus.cone(1);
            
            % set the coneInd
            obj.coneInd = strfind(obj.CONES, obj.nextCone);
            
            % move queue up
            obj.nextStimulus.cone(1) = [];
        end % assignNextStimulus
        
        function resumeProtocol(obj)
            % RESUMEPROTOCOL  Begin epochs again
            if isempty(obj.nextStimulus.cone)
                disp('empty stimulus list');
            else
                uiresume(obj.figureHandle);
                set(obj.figureHandle, 'Name', 'Cone Filter Figure');
            end
        end % resumeProtocol
        
        function waitForStim(obj)
            % WAITFORSTIM  Pause the protocol for adding new stimuli
            if isempty(obj.nextStimulus.cone)
                disp('waiting for input');
                set(obj.figureHandle, 'Name', 'Cone Filter Figure: PAUSED FOR STIM');
                % obj.addNullEpoch = true;
                uiwait(obj.figureHandle);
            end
        end % waitForStim
        
        function waitForLED(obj)
            % WAITFORLED  Pause the protocol while LED switches
            disp('waiting for LED change');
            set(obj.figureHandle, 'Name', 'Cone Filter Figure: PAUSED FOR LED');
            % obj.addNullEpoch = true;
            uiwait(obj.figureHandle);
        end % waitForLED
    end % methods
    
    methods (Access = private)
        function sendData(obj, ~, ~)
            % SENDDATA  Send data to workspace
            outputStruct = obj;
            answer = inputdlg('Send to workspaces as: ',...
                'Debug Dialog', 1, {'r'});
            assignin('base', sprintf('%s', answer{1}), outputStruct);
            fprintf('%s - figure data sent as %s', datestr(now), answer{1});
        end % sendData
    end % methods private
    
    methods (Static)
        % random methods for convinience. slowly moving elsewhere
        function newMean = stepMean(prevMean, prevN, newValue)
            % STEPMEAN  Uses N of previous mean in new mean calc
            x = prevMean * prevN;
            newMean = (x + newValue)/(prevN + 1);
        end % stepMean
        
        function [xBin, yBin] = getNL(P, R)
            % GETNL  Get the nonlinearity
            [a, b] = sort(P(:));
            xSort = a;
            ySort = R(b);
            
            valsPerBin = floor(length(xSort) / obj.NONLINEARITYBINS);
            xBin = mean(reshape(xSort(1:obj.NONLINEARITYBINS * valsPerBin),...
                valsPerBin, obj.NONLINEARITYBINS));
            yBin = mean(reshape(ySort(1:obj.NONLINEARITYBINS * valsPerBin),...
                valsPerBin, obj.NONLINEARITYBINS));
        end % getNL
    end % methods static
end % classdef
