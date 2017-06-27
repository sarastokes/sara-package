classdef ChromaticityController < symphonyui.ui.Module
 % work with 4 led setup, monitor/validate stimuli online

properties
  handles
  calib
  ledInd

  coneStr = 'lmsp'
  ledStr = 'RGBU'
  showPlot = false
  fourReady = false
end

methods
  function createUI(obj)
    set(figureHandle, 'Color', 'w',...
      'Name', 'ChromaticityController');

    mainLayout = uix.VBox('Parent', figureHandle,...
      'Padding', 10, 'Spacing', 10);

    uiLayout = uix.HBox('Parent', mainLayout,...
      'Padding', 10, 'Spacing', 10);

    chromLayout = uix.VBox('Parent', mainLayout,...
      'Spacing', 10, 'Padding', 10);

    obj.handles.ax = axes('Parent', mainLayout);

    set(mainLayout, 'Heights', [-1 -1 -4]);

    % LED panel
    obj.handles.lst.leds = uicontrol('Parent', uiLayout,...
      'Style', 'listbox',...
      'String', {'RGU', 'RBU'});

    obj.handles.pb.switchLED = uicontrol('Parent', uiLayout,...
      'Style', 'push',...
      'String', 'Switch LED',...
      'Callback', @onSelectedSwitchLED);

    obj.handles.tx.curLED = uicontrol('Parent', uiLayout,...
      'Style', 'text',...
      'String', 'RBU');

    set(uiLayout, 'Widths', [-1 -1 -1]);

    % display panel
    obj.handles.lst.whatPlot = uicontrol('Parent', chromLayout,...
      'Style', 'listbox',...
      'String', {'none', 'CIE', 'LED mod', 'SPD', 'Calib'});

    obj.handles.pb.doPlot = uicontrol('Parent', chromLayout,...
      'Style', 'push',...
      'String', 'plot',...
      'Callback', @onSelectedPlot);
    set(chromLayout, 'Heights', [-4 -1]);

    % pull the SPDs
    load('Spectra.mat');
    load('ConduitCorrection.mat');
    for ii = 1:4
      energySpectra(ii,:) = energySpectra(ii,:) .* c0.correction;
    end
    obj.calib.spd = energySpectra;
    obj.calib.wl = wavelength;
    obj.calib.bkgd = load('EqualEnergy.mat');

    obj.ledInd = [1 2 4];

  end % createUI

  function onSelectedSwitchLED(obj,~,~)
    switch obj.handles.lst.leds.String{obj.handles.lst.leds.Value}
      case 'RBU' % change to 405nm
        set(obj.handles.tx.curLED, 'String', 'RGU');
        obj.ledInd = [1 2 4];
      case 'RGU' % change to 495nm
        if obj.fourReady
          set(obj.handles.tx.curLED, 'String', 'RBU');
          obj.ledInd = [1 3 4];
        else
          warndlg('No 4th spectra yet');
        end
    end
  end % onSelectedSwitchLED

  function onSelectedPlot(obj,~,~)
    % if ~obj.showPlot
    %   obj.showPlot = true;
    %   obj.plotStatus();
    % end

    switch whichPlot
      case 'SPD'
        obj.handles.lines.R = line('Parent', obj.handles.ax,...
          obj.calib.wl, obj.calib.spd(1,:),...
          'LineWidth', 1.5, 'Color', getPlotColor('l'));
          switch get(obj.handles.tx.curLED, 'String')
            case 'RBU'
              obj.handles.lines.G = line('Parent', obj.handles.ax,...
                obj.calib.wl, obj.calib.spd(2,:),...
                'LineWidth', 1.5, 'Color', getPlotColor('m'));
            case 'RGU'
              obj.handles.lines.B = line('Parent', obj.handles.ax,...
                obj.calib.wl, obj.calib.spd(3,:),...
                'LineWidth', 1.5, 'Color', getPlotColor('s'));
          end
        obj.handles.lines.U = line('Parent', obj.handles.ax,...
          obj.calib.wl, obj.calib.spd(4,:),...
          'LineWidth', 1.5, 'Color', getPlotColor('p'));

        xlabel(obj.handles.ax, 'wavelength (nm)');
        ylabel(obj.handles.ax, 'energy');
        title(obj.handles.ax, sprintf('Spectra from %s', datestr(obj.calib.spectDate)));
        set(obj.handles.ax, 'XLim', [380 780]);
      case 'CIE'
        % this borrows heavily from MATLAB for Color Science 2e
        obj.makeCIEdiagram();
      case 'none'
        obj.showPlot = false;
        obj.plotStatus();
      case 'Mod'
        % get protocol
        protocolName = obj.acquisitionService.getSelectedProtocol();
        % get stimTime, preTime, tailTime
        switch protocolNameu
          case {'FullChromaticGrating', 'TestGrating', 'ChromaticGrating'}
            % get spatialFrequency, contrast, spatialClass
            % x-axis will be space
          case {'ChromaticSpot'}
            % get contrast
          case {'ConeSweep'}
            % get temporalClass, temporalFrequency, contrast
          case {'GaussianNoise'}
            % get stdev
            % x-axis will be LED values 0-1
            x = 0:0.001:1;
            for ii = 1:3
              ind = obj.ledInd(ii);
              if isempty(obj.handles.lines.(obj.ledStr(ind)))
                obj.handles.lines.(obj.ledStr(ind)) = line('Parent', obj.handles.ax,...
                x, normpdf(x, obj.calib.bkgd(ind), stdev),...
                'Color', getPlotColor(obj.coneStr(ii)), 'LineWidth', 1.5);
              else
                set(obj.handles.lines.(obj.ledStr(ind)),...
                  'XData', x, 'YData', normpdf(x, obj.calib.bkgd(ind), stdev));
              end
            end
        end % switch protocolName
        % TODO: get chromaticClass, temporal/spatial class, frequency, amplitude

        switch modType
          case 'sinewave'
          case 'squarewave'
          case 'pulse'
        end % switch modType

        if isempty(obj.handles.lines.R)
          obj.handles.lines.R = line('Parent', obj.handles.ax,...
            'LineWidth', 1.5, 'Color', getPlotColor('l'));
        else
          set(obj.handles.lines.R, 'XData', x, 'YData', y);
        end

        switch whichLED
          case 'RBU'
            if isempty(obj.handles.lines.G)
              obj.handles.lines.G = line('Parent', obj.handles.ax,...
                'LineWidth', 1.5, 'Color', getPlotColor('m'));
            else
              set(obj.handles.lines.G, 'XData', x, 'YData', y);
            end
          case 'RGU'
            if isempty(obj.handles.lines.B)
              obj.handles.lines.B = line('Parent', obj.handles.ax, x, y,...
              'LineWidth', 1.5, 'Color', getPlotColor('s'));
            else
              set(obj.handles.lines.B, 'XData', x, 'YData', y);
            end
        end

        if isempty(obj.handles.lines.U)
          obj.handles.lines.U = line('Parent', obj.handles.ax, x, y,...
            'LineWidth', 1.5, 'Color', getPlotColor('p'));
        else
          set(obj.handles.lines.U, 'XData', x, 'YData', y);
        end

    end % switch whichPlot
  end % onSelectedPlot


%  function makeCIEdiagram(obj,~,~)

%  end % makeCIEdiagram

  function addConfusion(obj,~,~)
    if ~strcmp(obj.currentPlot, 'CIE')
      warndlg('Set plot to CIE');
      return;
    end

    copunct = getConstant(obj.confusionLine);

  end % addConfusion

  function plotStatus(obj,~,~)
  end % make the entire figure bigger
end % methods
end % classdef
