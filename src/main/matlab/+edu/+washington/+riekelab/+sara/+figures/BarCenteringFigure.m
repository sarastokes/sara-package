classdef BarCenteringFigure < symphonyui.core.FigureHandler
    % 10Jul2017 - SSP - created

properties (SetAccess = private)
    % required
	device
	preTime
	stimTime
	temporalFrequency
    % optional:
    recordingType
end

properties (Access = private)
	handles
	epochNum
	cellData
end

properties (Constant)
	RES = {'F1', 'F2', 'P1', 'P2'}
	BINRATE = 60
end

methods
	function obj = BarCenteringFigure(device, preTime, stimTime, temporalFrequency, varargin)
		obj.device = device;
		obj.preTime = preTime;
		obj.stimTime = stimTime;
		obj.temporalFrequency = temporalFrequency;
        
        ip = inputParser();
        ip.addParameter('recordingType', 'extracellular', @(x)ischar(x));
        ip.parse(varargin{:});
        obj.recordingType = ip.Results.recordingType;
		
		obj.epochNum = 0;

		obj.cellData = struct();
		for ii = 1:length(obj.RES)
			obj.cellData.([obj.RES{ii}, 'X']) = [];
			obj.cellData.([obj.RES{ii}, 'Y']) = [];
		end

		obj.createUi();
	end % constructor
	
	function createUi(obj)
		import appbox.*;

		set(obj.figureHandle, 'Color', 'w',...
			'Name', 'Bar Centering Figure');
		
		toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
		pcolorButton = uipushtool('Parent', toolbar,...
			'TooltipString', 'interpolate & pcolor',...
			'Separator', 'on',...
			'ClickedCallback', @obj.onSelected_interpolate);
		setIconImage(pcolorButton, symphonyui.app.App.getResource('icons', 'modules.png'));

		surfButton = uipushtool('Parent', toolbar,...
			'TooltipString', 'interpolate & surf',...
			'Separator', 'on',...
			'ClickedCallback', @obj.onSelected_interpolate);
		setIconImage(surfButton,... 
            symphonyui.app.App.getResource('icons', 'modules.png'));

		sendButton = uipushtool('Parent', toolbar,...
			'TooltipString', 'send to workspace',...
			'Separator', 'on',...
			'ClickedCallback', @obj.onSelected_sendButton);
		setIconImage(sendButton,... 
            symphonyui.app.App.getResource('icons', 'store_sweep.png'));

		mainLayout = uix.HBox('Parent', obj.figureHandle,...
            'Padding', 5, 'Spacing', 0);
		f1Layout = uix.VBox('Parent', mainLayout,...
			'Padding', 5, 'Spacing', 0);
		f2Layout = uix.VBox('Parent', mainLayout,...
			'Padding', 5, 'Spacing', 0);
	
		obj.handles.F1X = axes('Parent', f1Layout,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XTickMode', 'auto');
		title('X-axis centering');
		ylabel('spikes/sec');
		
		obj.handles.P1X = axes('Parent', f1Layout,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'YLim', [-180 180],...
			'XTickMode', 'auto');
		xlabel('position');
		ylabel('phase');
		set(f1Layout, 'Heights', [-2 -1]);
	
		obj.handles.F1Y = axes('Parent', f2Layout,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XTickMode', 'auto');
		title('Y-axis centering');
		ylabel('spikes/sec');
		obj.handles.P1Y = axes('Parent', f2Layout,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XTickMode', 'auto',...
			'YLim', [-180 180]);
		xlabel('position');
		ylabel('phase');
		set(f2Layout, 'Heights', [-2 -1]);
	
		obj.handles.im = axes('Parent', mainLayout,...
			'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
			'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'),...
			'XTickMode', 'auto');
		xlabel('x-axis'); ylabel('y-axis');
	
		set(mainLayout, 'Widths', [-1 -1 -0.5]);
	end % createUi
	
	function handleEpoch(obj, epoch)

		obj.epochNum = obj.epochNum + 1;

		% get the response
		response = epoch.getResponse(obj.device);
  		epochResponse = response.getData();
  		sampleRate = response.sampleRate.quantityInBaseUnits;

  		epochResponse = getResponseByType(epochResponse, obj.onlineAnalysis);

  		% analyze the response
  		prePts = obj.preTime * 1e-3 * sampleRate;
  		stimFrames = obj.stimTime * 1e-3 * obj.BINRATE;

  		if strcmp(obj.recordingType, 'extracellular')
  			y = BinSpikeRate(epochResponse(obj.epochNum, prePts+1:end), obj.BINRATE, sampleRate);
  		else
  			y = binData(epochResponse(prePts+1 : end), obj.BINRATE, sampleRate);
  		end

  		binSize = obj.BINRATE / obj.temporalFrequency;
  		numBins = floor(stimFrames / binSize);
  		avgCycle = zeros(1, floor(binSize));
  		for ii = 1:numBins
  			index = round((ii-1)*binSize) + (1:floor(binSize));
  			index(index > length(y)) = [];
  			ytmp = y(index);
  			avgCycle = avgCycle + ytmp(:)';
  		end
  		avgCycle = avgCycle / numBins;

  		ft = fft(avgCycle);

		% update the plots and cellData	
		obj.curAxis = epoch.parameters('searchAxis');
		obj.curAxis = obj.curAxis(1);
		switch obj.curAxis
		case 'xaxis'
			obj.cellData.xpts = [obj.cellData.xpts, umPerPix(epoch.parameters('position'))];
			obj.cellData.F1X = cat(2, obj.cellData.F1X, abs(ft(2))/length(avgCycle*2));
			obj.cellData.F2X = cat(2, obj.cellData.F2X, abs(ft(3))/length(avgCycle*2));
			obj.cellData.P1X = cat(2, obj.cellData.P1X, angle(ft(2)) * 180/pi);
			obj.cellData.P2X = cat(2, obj.cellData.P2X, angle(ft(3)) * 180/pi);
			
			for ii = 1:length(obj.RES)
				ind = sprintf('%sX', obj.RES{ii});
				if isempty(obj.handles.(lower(ind)))
					obj.handles.(lower(ind)) = line('Parent', obj.handles.(ind),...
					'XData', obj.cellData.xpts, 'YData', obj.cellData.(ind),...
					'Color', getColor(obj.RES{ii}), 'Marker', 'o',... 
					'LineWidth', getLW(obj.RES{ii}));
				else
					set(obj.handles.(lower(ind)),...
					'XData', obj.cellData.xpts, 'YData', obj.cellData.(ind));
				end
			end
		case 'yaxis'
			obj.cellData.ypts = [obj.cellData.ypts, umPerPix(epoch.parameters('position'))];
			obj.cellData.F1Y = cat(2, obj.cellData.F1Y, abs(ft(2))/length(avgCycle*2));
			obj.cellData.F2Y = cat(2, obj.cellData.F2Y, abs(ft(3))/length(avgCycle*2));
			obj.cellData.P1Y = cat(2, obj.cellData.P1Y, angle(ft(2)) * 180/pi);
			obj.cellData.P2Y = cat(2, obj.cellData.P2Y, angle(ft(3)) * 180/pi);

			for ii = 1:length(obj.RES)
				ind = sprintf('%sY', obj.RES{ii});
				if isempty(obj.handles.(lower(ind)))
					obj.handles.(lower(ind)) = line('Parent', obj.handles.(ind),...
						'XData', obj.cellData.yps, 'YData', obj.cellData.(ind),...
						'Color', getColor(obj.RES{ii}), 'Marker', 'o',...
						'LineWidth', getLW(obj.RES{ii}));
				else
					set(obj.handles.(lower(ind)),...
						'XData', obj.cellData.ypts, 'YData', obj.cellData.(ind));
				end
			end
		end
	end % handleEpoch
end % methods

methods 
	function onSelected_interpolate(obj, src, ~)
		x = [obj.handles.f1x.XData, zeros(length(obj.handles.f1y.XData))];
		y = [zeros(length(obj.handles.F1x.XData)), obj.handles.F1y.XData];
		
		scInt = scatteredInterpolant(x, y,...
		[obj.handles.F1x.YData obj.handles.F1y.YData]);
		
		[newX, newY] = meshgrid(linspace(min(x), max(x), 100),...
			linspace(min(y), max(y), 100));

		newMap = scInt(newX, newY);
		
		switch src.TooltipString
		case 'interpolate & pcolor'
			im = pcolor(obj.handles.im, newMap);
		case 'interpolate & surf'
			im = surf(obj.handles.im, newMap);
			zlabel('spikes/sec');
		end
		shading(im, 'interp'); 
		colormap(im, 'viridis');
	end % onSelected_interpolate

	function onSelected_sendButton(obj, ~, ~)
		outputStruct = obj.cellData;
		answer = inputdlg('Send to workspaces as: ',...
			'Variable name dialog', 1, {'r'});
		assignin('base', sprintf('%s', answer{1}), outputStruct);
		fprintf('%s - figure data sent as %s', datestr(now), answer{1});
	end % onSelected_debugButton
end % methods private

methods (Static)
	function um = umPerPix(pix)
		% assuming it's 10x
		um = 0.8 * pix;
    end % umPerPix
	
	function co = getColor(res)
        switch res
            case {'F1', 'P1'}
                co = 'k';
            otherwise
                co = [0.5 0.5 0.5];
        end
    end % getColor
	
	function lw = getLW(res)
        switch res
            case {'F1', 'P1'}
                lw = 1.5;
            otherwise
                lw = 1;
        end
    end % get LW
		
end % methods static
end % classdef