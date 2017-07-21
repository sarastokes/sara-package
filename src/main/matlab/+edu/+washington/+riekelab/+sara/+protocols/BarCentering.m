classdef BarCentering < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
  % 10Jul2017 - SSP - updated to run x, y together with new figures

properties
  amp                             % Output amplifier
  greenLED = '570nm'              % Which green LED
  preTime = 250                   % Spot leading duration (ms)
  stimTime = 2000                 % Spot duration (ms)
  tailTime = 1000                 % Spot trailing duration (ms)
  intensity = 1.0                 % Bar intensity (0-1)
  temporalFrequency = 2.0         % Modulation frequency (Hz)
  barSize = [50 500]              % Bar size [width, height] (pix)
  temporalClass = 'squarewave'    % Squarewave or pulse?
  positions = -300:50:300         % Bar center position (pix)
  backgroundIntensity = 0.5       % Background light intensity (0-1)
  centerOffset = [0,0]            % Center offset in pixels (x,y)
  chromaticClass = 'achromatic'   % Chromatic class
  onlineAnalysis = 'extracellular'         % Online analysis type.
  numberOfAverages = uint16(26)   % Number of epochs
end

properties (Hidden)
  ampType
  greenLEDType = symphonyui.core.PropertyType('char', 'row', {'570nm','505nm'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'squarewave', 'pulse'})
  chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'red', 'green', 'blue', 'yellow', 'L-iso', 'M-iso', 'S-iso', 'LM-iso'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  searchAxis
  position
  orientation
  orientations
  sequence
end

methods
  function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
  end

  function prepareRun(obj)
    prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

      obj.showFigure('edu.washington.riekelab.manookin.figures.ResponseFigure',...
        obj.rig.getDevices('Amp'), 'numberOfAverages', obj.numberOfAverages);

      if ~strcmp(obj.onlineAnalysis, 'none')
        obj.showFigure('edu.washington.riekelab.sara.figures.BarCenteringFigure',...
        obj.rig.getDevice(obj.amp), obj.preTime, obj.stimTime, obj.temporalFrequency,...
        'recordingType', obj.onlineAnalysis);
      end

      % begin with x-axis
      obj.searchAxis = 'xaxis';

      % set up the stimulus parameters
      obj.orientations = repmat([0 90], length(obj.positions), 1);
      obj.orientations = obj.orientations(:)';

      pos = obj.positions(:);
      pos = pos(:);

      x = [pos+obj.centerOffset(1) obj.centerOffset(2)*ones(length(pos),1)];
      y = [obj.centerOffset(1)*ones(length(pos),1) pos+obj.centerOffset(2)];
      obj.sequence = [x; y];

      obj.setColorWeights();
  end % prepareRun

    function p = createPresentation(obj)
      p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
      p.setBackgroundColor(obj.backgroundIntensity);

      rect = stage.builtin.stimuli.Rectangle();
      rect.size = obj.barSize;
      rect.orientation = obj.orientation;
      rect.position = obj.canvasSize/2 + obj.position;

      if strcmp(obj.stageClass, 'Video')
          rect.color = obj.intensity*obj.colorWeights*obj.backgroundIntensity + obj.backgroundIntensity;
      else
          rect.color = obj.intensity*obj.backgroundIntensity + obj.backgroundIntensity;
      end

      % Add the stimulus to the presentation.
      p.addStimulus(rect);

      % Control when the spot is visible.
      spotVisible = stage.builtin.controllers.PropertyController(rect, 'visible', ...
          @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
      p.addController(spotVisible);

      % Control the bar intensity.
      if strcmp(obj.temporalClass, 'squarewave')
          colorController = stage.builtin.controllers.PropertyController(rect, 'color', ...
              @(state)getSpotColorVideoSqwv(obj, state.time - obj.preTime * 1e-3));
          p.addController(colorController);
      end

      function c = getSpotColorVideoSqwv(obj, time)
        if strcmp(obj.stageClass, 'Video')
          c = obj.intensity * sign(sin(obj.temporalFrequency*time*2*pi)) * obj.colorWeights * obj.backgroundIntensity + obj.backgroundIntensity;
        else
          c = obj.intensity * sign(sin(obj.temporalFrequency*time*2*pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
        end
      end
  end

  function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

      obj.position = obj.sequence(obj.numEpochsCompleted+1, :);
      obj.orientation = obj.orientations(obj.numEpochsCompleted+1);

      if obj.numEpochsCompleted >= length(obj.positions)
        obj.searchAxis = 'yaxis';
      else
        obj.searchAxis = 'xaxis';
      end

      if strcmp(obj.searchAxis, 'xaxis')
          epoch.addParameter('position', obj.position(1));
      else
          epoch.addParameter('position', obj.position(2));
      end
      epoch.addParameter('searchAxis', obj.searchAxis);
      epoch.addParameter('orientation', obj.orientation);
  end

  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
  end % methods
end % classdef
