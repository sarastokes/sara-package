classdef ColorCircle < edu.washington.riekelab.sara.protocols.SaraStageProtocol
    % might merge with ColorExchange, DKL space
		%
		% 2Mar2017 - flipped the L and M cone weights. L-M is now 0, not 180

properties
	amp
	greenLED = '570nm'
	preTime = 250
	stimTime = 2000
	tailTime = 250
  contrast = 1
	radius = 1500
	maskRadius = 0
	temporalClass = 'sinewave'
	temporalFrequency = 4
	centerOffset = [0, 0]
	onlineAnalysis = 'extracellular'
	lightMean = 0.5
	numberOfAverages = uint16(9)
end

properties (Hidden)
	ampType
  greenLEDType = symphonyui.core.PropertyType('char', 'row', {'570nm','505nm'})
	temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
	onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
	stimulusClass
	coneWeights
	stimTrace
	orientations
end

methods
function didSetRig(obj)
  didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

  [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
  prepareRun@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj);

  % set stimulus class
  if obj.maskRadius == 0
    obj.stimulusClass = 'spot';
  else
    obj.stimulusClass = 'annulus';
  end

  obj.stimTrace = getLightStim(obj, 'modulation');

  obj.orientations = linspace(0, 360, double(obj.numberOfAverages));

  obj.coneWeights = zeros(double(obj.numberOfAverages), 3);

  obj.coneWeights(:, 1) = cos(deg2rad(obj.orientations));
  obj.coneWeights(:, 2) = -cos(deg2rad(obj.orientations));
  obj.coneWeights(:, 3) = sin(deg2rad(obj.orientations));


  % set up figures
  if numel(obj.rig.getDeviceNames('Amp')) < 2
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseFigure',... 
        obj.rig.getDevice(obj.amp), obj.stimTrace,...
    	'stimColor', 'k');
  else
    obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure',...
        obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
  end

  if ~strcmp(obj.onlineAnalysis, 'none')
  	obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure',...
        obj.rig.getDevice(obj.amp), obj.orientations, obj.onlineAnalysis,...
  		obj.preTime, obj.stimTime, 'temporalFrequency', obj.temporalFrequency);
  end
end

function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.lightMean);

    spot = stage.builtin.stimuli.Ellipse();
    spot.radiusX = obj.radius;
    spot.radiusY = obj.radius;
    spot.position = obj.canvasSize/2 + obj.centerOffset;

    spotVisibleController = stage.builtin.controllers.PropertyController(spot, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

    spotColorController = stage.builtin.controllers.PropertyController(spot, 'color', @(state)getSpotColor(obj, state.time - obj.preTime * 1e-3));

    p.addStimulus(spot);
    p.addController(spotVisibleController);
    p.addController(spotColorController);

    % center mask for annulus
    if obj.maskRadius > 0
      mask = stage.builtin.stimuli.Ellipse();
      mask.radiusX = obj.maskRadius;
      mask.radiusY = obj.maskRadius;
      mask.position = obj.canvasSize/2 + obj.centerOffset;
      mask.color = obj.lightMean;

      maskVisibleController = stage.builtin.controllers.PropertyController(mask, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

      p.addStimulus(mask);
      p.addController(maskVisibleController);
    end


  function c = getSpotColor(obj, time)
      if time >= 0
          if strcmp(obj.temporalClass, 'sinewave')
            c = obj.contrast * obj.currentLedWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.lightMean + obj.lightMean;
          elseif strcmp(obj.temporalClass, 'squarewave')
             c = obj.contrast * obj.currentLedWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.lightMean + obj.lightMean;
          end
      else
          c = obj.lightMean;
      end
  end
end

	function prepareEpoch(obj, epoch)
	  prepareEpoch@edu.washington.riekelab.sara.protocols.SaraStageProtocol(obj, epoch);

	  w = obj.quantalCatch(:, 1:3)' \ obj.coneWeights(obj.numEpochsCompleted+1,:)';
	  w = w/max(abs(w));
	  obj.currentLedWeights = w(:)';

	  epoch.addParameter('orientation', obj.orientations(obj.numEpochsCompleted+1));
	  epoch.addParameter('coneWeights', obj.coneWeights(obj.numEpochsCompleted+1,:));
	  epoch.addParameter('ledWeights', obj.currentLedWeights);
	  epoch.addParameter('stimulusClass', obj.stimulusClass);
	end

  function tf = shouldContinuePreparingEpochs(obj)
    tf = obj.numEpochsPrepared < obj.numberOfAverages;
   end

  function tf = shouldContinueRun(obj)
    tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end % methods
end % classdef
