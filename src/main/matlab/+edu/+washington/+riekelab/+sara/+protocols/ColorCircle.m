classdef ColorCircle < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
    % might merge with ColorExchange

properties
	amp
	preTime = 250
	stimTime = 2000
	tailTime = 250
  contrast = 0.7
	radius = 1500
	maskRadius = 0
	temporalClass = 'sinewave'
	temporalFrequency = 4
	centerOffset = [0, 0]
	onlineAnalysis = 'extracellular'
	backgroundIntensity = 0.5
	numberOfAverages = uint16(9)
end

properties (Hidden)
	ampType
	temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
	onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
	stimulusClass
	coneWeights
	ledWeights
	stimTrace
	orientations
end

methods
function didSetRig(obj)
  didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);

  [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function prepareRun(obj)
  prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

  % set stimulus class
  if obj.maskRadius == 0
    obj.stimulusClass = 'spot';
  else
    obj.stimulusClass = 'annulus';
  end

  obj.stimTrace = getStimTrace(obj, 'modulation');

  obj.orientations = linspace(0, 360, double(obj.numberOfAverages));

  obj.coneWeights = zeros(double(obj.numberOfAverages), 3);

  obj.coneWeights(:, 1) = -cos(deg2rad(obj.orientations));
  obj.coneWeights(:, 2) = cos(deg2rad(obj.orientations));
	obj.coneWeights(:, 3) = sin(deg2rad(obj.orientations));

  % set up figures
  if numel(obj.rig.getDeviceNames('Amp')) < 2
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace,...
    	'stimColor', getPlotColor(lower(obj.coneOne)));
  else
    obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
  end

  if ~strcmp(obj.onlineAnalysis, 'none')
  	obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure', obj.rig.getDevice(obj.amp), obj.orientations, obj.onlineAnalysis,...
  		obj.preTime, obj.stimTime, 'temporalFrequency', obj.temporalFrequency);
  end
end

function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

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
      mask.color = obj.backgroundIntensity;

      maskVisibleController = stage.builtin.controllers.PropertyController(mask, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

      p.addStimulus(mask);
      p.addController(maskVisibleController);
    end


  function c = getSpotColor(obj, time)
      if time >= 0
          if strcmp(obj.temporalClass, 'sinewave')
            c = obj.contrast * obj.ledWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
          elseif strcmp(obj.temporalClass, 'squarewave')
             c = obj.contrast * obj.ledWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
          end
      else
          c = obj.backgroundIntensity;
      end
  end
end

	function prepareEpoch(obj, epoch)
	  prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

	  w = obj.quantalCatch(:, 1:3)' \ obj.coneWeights(obj.numEpochsCompleted+1,:)';
	  w = w/max(abs(w));
	  obj.ledWeights = w(:)';

	  epoch.addParameter('orientation', obj.orientations(obj.numEpochsCompleted+1));
	  epoch.addParameter('coneWeights', obj.coneWeights(obj.numEpochsCompleted+1,:));
	  epoch.addParameter('ledWeights', obj.ledWeights);
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
