classdef FilterWheelControl < symphonyui.ui.Module

	properties (Access = private)
		stage
		filterWheel
		ndf
		objectiveMag
		LEDs
		ndfSettingPopupMenu
		objectivePopupMenu
		ledPopupMenu
		quantalCatch
		q
	end

	methods
		function createUi(obj, figureHandle)
			import appbox.*;

			set(figureHandle,...
				'Name', 'ND Wheel Control',...
				'Position', screenCenter(200, 100));

			mainLayout = uix.HBox(...
				'Parent', figureHandle,...
				'Padding', 11,...
				'Spacing', 7);

			filterWheelLayout = uix.Grid(...
				'Parent', mainLayout,...
				'Spacing', 7);
			Label(...
				'Parent', filterWheelLayout,...
				'String', 'NDF');
			Label(...
				'Parent', filterWheelLayout,...
				'String', 'Objective');
			Label(...
				'Parent', filterWheelLayout,...
				'String', 'LEDs');
			obj.ndfSettingPopupMenu = MappedPopupMenu(...
				'Parent', filterWheelLayout,...
				'String', {' '},...
				'HorizontalAlignment', 'left',...
				'Callback', @obj.onSelectedNdfSetting);
			obj.objectivePopupMenu = MappedPopupMenu(...
				'Parent', filterWheelLayout,...
				'String', {' '},...
				'HorizontalAlignment', 'left',...
				'Callback', @obj.onSelectedObjectiveSetting);
			obj.ledPopupMenu = MappedPopupMenu(...
				'Parent', filterWheelLayout,...
				'String', {' '},...
				'HorizontalAlignment', 'left',...
				'Callback', @obj.onSelectedLedSetting);
			set(filterWheelLayout,...
				'Widths', [70 -1],...
				'Heights', 23*ones(1,2));
		end % createUi
	end % methods

	methods (Access = protected)
		function willGo(obj)
			% make sure there's a filter wheel device
			devices = obj.configurationService.getDevices('FilterWheel');
			if isempty(devices)
				error('No filterWheel device found');
			end

			obj.filterWheel = devices{1};
			obj.populateNdfSettingList();
			obj.populateObjectiveList();

			% set the NDF to 4.0 on startup.
			obj.filterWheel.setNDF(4);
			set(obj.ndfSettingPopupMenu, 'Value', 4);

			% still deciding where to put this
			obj.loadQuantalCatch();
			obj.setQuantalCatch();
		end % willGo
	end % methods protected

	methods (Access = private)
		function populateNdfSettingList(obj)
			ndfNums = {0.0, 0.5, 1.0, 2.0, 3.0, 4.0};
			ndfs = {'0.0', '0.5', '1.0', '2.0', '3.0', '4.0'};

			set(obj.ndfSettingPopupMenu, 'String', ndfs);
			set(obj.ndfSettingPopupMenu, 'Values', ndfNums);
		end % populateNdfSettingList

		function onSelectedNdfSetting(obj, ~, ~)
			position = get(obj.ndfSettingPopupMenu, 'Value');
			obj.filterWheel.setNDF(position);
			% obj.setQuantalCatch();
		end % onSelectedNdfSetting

		function populateObjectiveList(obj)
			objectiveNums = {60, 10};
			objectiveStrings = {'60x', '10x'};

			set(obj.objectivePopupMenu, 'String', objectiveStrings);
			set(obj.objectivePopupMenu, 'Values', objectiveNums);
			obj.objectiveMag = 60;
		end % populateObjectiveList

		function onSelectedObjectiveSetting(obj,~,~)
			v = get(obj.objectivePopupMenu, 'Value');
			obj.filterWheel.setObjective(v);
			obj.objectiveMag = v;
			% obj.setQuantalCatch();
		end % onSelectedObjectiveSetting

		function populateLedList(obj)
			ledNums = {134, 124};
			ledStrings = {'RBU', 'RGU'};

			set(obj.ledPopupMenu, 'String', ledStrings);
			set(obj.ledPopupMenu, 'Values', ledValues);
		end

		function onSelectedLedSetting(obj,~,~)
			v = get(obj.ledPopupMenu, 'Value');
			obj.leds = v;

			obj.setQuantalCatch();
		end

		function loadQuantalCatch(obj)
			% Get the quantal catch
			obj.q = load('QCatch.mat');

		function setQuantalCatch(obj)
			obj.objectiveMag = obj.filterWheel.getObjective();
			obj.LEDs = obj.filterWheel.getLEDs();

			% Get the ndf wheel setting
			obj.ndf = obj.filterWheel.getNDF();
			ndString = num2str(obj.ndf * 10);
			if length(ndString) == 1
				ndString = ['0', ndString];
			end

			% Take current LEDs into account
			if obj.LEDs == 134
				obj.quantalCatch = obj.q.qCatch.(['ndf', ndString])([1 2 4], :);
			else
				obj.quantalCatch = obj.q.qCatch.(['ndf', ndString])([1 3 4], :);
			end

			% Adjust the quantal catch depending on the objective.
			if obj.objectiveMag == 4
					obj.quantalCatch = obj.quantalCatch .* ([0.498627; 0.4921139; 0.453983]*ones(1,4));
			elseif obj.objectiveMag == 60
					obj.quantalCatch = obj.quantalCatch .* ([1.867747065682890; 1.849862001274647; 1.767678539504911]*ones(1,4));
			end

			% Set the quantal catch on the filter wheel device.
			obj.filterWheel.setQuantalCatch(obj.quantalCatch);
		end
	end % methods private
end % classdef
