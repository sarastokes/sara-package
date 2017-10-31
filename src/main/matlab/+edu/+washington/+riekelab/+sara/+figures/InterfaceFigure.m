classdef InterfaceFigure < symphonyui.core.FigureHandler
    
    properties (Hidden = true)
        epochNum = 0
        ignoreNextEpoch = false
        addNullEpoch = false
        protocolShouldStop = false
    end
    
    properties (SetAccess = private)
        stimTable
        analysisTable
        nextStim = cell(0,1);
    end
    
    properties (Abstract = true, Constant = true)
        % A cellstr of controlled parameters
        % Note: if >1 parameter, order matters
        CONTROLPARAMS
        % A cell of function handles to parse
        PARAM_PROPTYPE
    end
    
    properties (Access = protected)
        mainLayout
        uiLayout
        ui
        dataLayout
    end
    
    methods (Abstract)
        analyzeEpoch(obj, epoch);
    end
    
    methods
        function obj = InterfaceFigure()
            
            % Check the parameters
            if isempty(obj.CONTROLPARAMS) || ~iscellstr(obj.CONTROLPARAMS)
                disp('Set PARAMETERS as a cellstr');
                return;
            end
            
            % Create the empty table for the stimuli
            obj.emptyStimTable();
            
            % Create an empty table for analysis
			obj.analysisTable = table(num2cell(1:numel(obj.CONTROLPARAMS)+numel(obj.ANALYSISPARAMS)),...
				'VariableNames', cat(2, obj.CONTROLPARAMS, obj.ANALYSISPARAMS));
			obj.analysisTable(1,:) = [];
            
            % Each protocol should include 
            % obj.handleStimulus();
        end
        
        function createUi(obj)
            import appbox.*;
            
            obj.mainLayout = uix.HBox('Parent', obj.figureHandle);
            obj.uiLayout = uix.VBox('Parent', obj.mainLayout);
            obj.dataLayout = uix.VBox('Parent', obj.mainLayout);
            
            set(obj.mainLayout, 'Widths', [-1 -4]);
        end
        
        function handleEpoch(obj, epoch)
            if obj.ignoreNextEpoch
                disp('ignoring epoch');
                epoch.shouldBePersisted = false;
                obj.assignNextStimulus();
                obj.ignoreNextEpoch = false;
                return;
            end
            
            obj.epochNum = obj.epochNum + 1;
            obj.analyzeEpoch(obj, epoch);
            obj.handleStimulus();
            obj.updatePlots();
        end
        
        function updateUi(obj)
            set(obj.ui.queue, 'Data', table2cell(obj.stimTable));
        end
        
        %
        % Stimulus control methods
        %
        function handleStimulus(obj)
            % Check whether next stimulus exists
            obj.waitForStim();
            
            if ~isvalid(obj)
                return;
            end
            
            % Set the next epoch's stimulus
            obj.assignNextStimulus();
            % --------- NEXT EPOCH ---------------------------
            % Reflect in UI
            obj.updateUi();
        end
        
        function assignNextStimulus(obj)
            if obj.addNullEpoch
                % A null epoch doesn't change queue
                disp('Adding null epoch');
                obj.ignoreNextEpoch = false;
                obj.addNullEpoch = false;
                % Rather than incrementing the queue,
                % tell protocol not to dequeue
                obj.doubleFirstStim();
            else
                obj.ignoreNextEpoch = false;
                obj.addNullEpoch = false;
            end
            
            % First row is the next stimulus
            obj.nextStim = obj.stimTable(1,:);
            
            % Clear the first row
            obj.stimTable(1,:) = [];
        end
        
        function parseStimuli(obj, newStim)
            if ~isempty(obj.PARAM_PARSE_FCNS)
                for i = 1:numel(obj.CONTROLPARAMS)
                    proptype = obj.PARAM_PARSE_FCNS{1};
                    if strcmp(proptype.primitiveType, 'char')
                        newStim(i) = validatestring(newStim(i), proptype.domain);
                    else
                        validateattributes(newStim(i), obj.PARAM_PARSE_FCNS{i},{});
                    end
                end
            end
        end
        
        function appendToQueue(obj, newStimuli)
            obj.stimTable = [obj.stimTable; newStimuli];
        end
        
        function doubleFirstStim(obj)
            obj.stimTable = [obj.stimTable(1,:); obj.stimTable];
        end
        
        function clearQueue(obj)
            obj.stimTable = obj.emptyStimTable;
            obj.updateUi();
        end
        
        %
        % Protocol control methods
        %
        function resumeProtocol(obj)
            if isempty(obj.stimTable)
                disp('empty stimulus list');
            else
                uiresume(obj.figureHandle);
                set(obj.figureHandle, 'Name', 'Running');
            end
        end
        
        function waitForStim(obj)
            if isempty(obj.stimTable)
                disp('waiting for input');
                set(obj.figureHandle, 'Name', 'PAUSED: waiting for input');
                % obj.addNullEpoch = true;
                uiwait(obj.figureHandle);
            end
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            clearFigure@symphonyui.core.FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.epochNum = 0;
            obj.protocolShouldStop = false;
            obj.stimTable = obj.emptyStimTable();
            % Any others should be set in subclass
        end
    end
    
    methods (Access = protected)
        
        function T = emptyStimTable(obj)
            % Hack, put elsewhere later
            T = table(num2cell(1:numel(obj.CONTROLPARAMS)),...
                'VariableNames', obj.CONTROLPARAMS);
            T(1,:) = [];
        end
        
        function makeControlPanel(obj, parentHandle)
            % STIMULUS CONTROL
            uicontrol(parentHandle,...
                'Style', 'text',...
                'String', 'Stimulus queue:');
            
            if numel(obj.CONTROLPARAMS) == 1
                obj.ui.queue = uicontrol(...
                    'Parent', parentHandle,...
                    'Style', 'text');
            else
                obj.ui.queue = uitable(parentHandle);
                set(obj.ui.queue,...
                    'ColumnName', obj.CONTROLPARAMS,...
                    'ColumnEditable', false,...
                    'RowNames', {});
            end
            uicontrol('Parent', parentHandle,...
                'Style', 'text',...
                'String', 'Add Stimuli:');
            if numel(obj.CONTROLPARAMS) == 1
                obj.ui.newStim = uicontrol(parentHandle,...
                    'Style', 'edit');
            else
                obj.ui.newStim = uitable(parentHandle);
                set(obj.ui.newStim,...
                    'ColumnName', obj.CONTROLPARAMS,...
                    'ColumnEditable', true,...
                    'RowNames', {});
            end
            obj.ui.pb.addToQueue = uicontrol(parentHandle,...
                'Style', 'pushbutton',...
                'String', 'Update Queue',...
                'Callback', @obj.onSelectedUpdateQueue);
            obj.ui.pb.clearQueue = uicontrol(parentHandle,...
                'Style', 'pushbutton',...
                'String', 'Clear Queue',...
                'Callback', @obj.onSelectedClearQueue);
            % PROTOCOL CONTROL
            uicontrol('Parent', parentHandle,...
                'Style', 'push',...
                'String', 'Resume Protocol',...
                'Callback', @(a,b) obj.resumeProtocol());
            
            set(parentHandle, 'Heights', [-2 -1 -1 -1 -1 -1 -1]);
        end
    end
    
    % 
    % Callbacks
    %
    methods (Access = private)
        function onSelectedClearQueue(obj, ~, ~)
            obj.clearQueue();
        end
        
        function onSelectedUpdateQueue(obj, ~, ~)
            obj.parseStimuli();
            obj.appendToQueue();
        end
    end
end