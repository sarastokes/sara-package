classdef ColorExchange < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
	amp
	preTime = 250
	stimTime = 2000
	tailTime = 250
	coneOne = 'L'
	coneTwo = 'M'
  contrast = 0.7
	radius = 1500
	maskRadius = 0
	temporalClass = 'sinewave'
	temporalFrequency = 2
	centerOffset = [0, 0]
	onlineAnalysis = 'extracellular'
	backgroundIntensity = 0.5
	numberOfAverages = uint16(13)
end

properties (Hidden)
	ampType
	temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
	onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
	coneOneType = symphonyui.core.PropertyType('char', 'row', {'L', 'M', 'S', 'LM', 'LS', 'MS', 'R', 'G', 'B'})
	coneTwoType = symphonyui.core.PropertyType('char', 'row', {'L', 'M', 'S', 'LM', 'LS', 'MS', 'R', 'G', 'B'}) 
	stimulusClass
	coneWeights
	ledWeights
	stimTrace
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

  obj.coneWeights = zeros(double(obj.numberOfAverages), 3);
  switch obj.coneOne
  case {'R', 'G', 'B'}
    ind1 = strfind('RGB', obj.coneOne); ind2 = strfind('RGB', obj.coneTwo);
  otherwise
    ind1 = strfind('LMS', obj.coneOne); ind2 = strfind('LMS', obj.coneTwo);
  end
  for ii = 1:double(obj.numberOfAverages)
    obj.coneWeights(ii, ind1) = cos((ii-1)*pi/(double(obj.numberOfAverages)-1)) * obj.contrast;
    obj.coneWeights(ii, ind2) = -sin((ii-1)*pi/(double(obj.numberOfAverages)-1)) * obj.contrast;
  end

  % set up figures
  if numel(obj.rig.getDeviceNames('Amp')) < 2
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), obj.stimTrace,... 
    	'stimColor', getPlotColor(lower(obj.coneOne)));
  else
    obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure', obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
  end

  if ~strcmp(obj.onlineAnalysis, 'none')
  	obj.showFigure('edu.washington.riekelab.sara.figures.F1Figure', obj.rig.getDevice(obj.amp), obj.contrast, obj.onlineAnalysis,... 
  		obj.preTime, obj.stimTime, 'temporalFrequency', obj.temporalFrequency, 'plotColor', getPlotColor(lower(obj.coneOne)));
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

  switch obj.coneOne
  case {'R', 'G', 'B'}
    obj.ledWeights = obj.coneWeights(obj.numEpochsCompleted+1,ii);
  otherwise
    w = obj.quantalCatch(:, 1:3)' \ obj.coneWeights(obj.numEpochsCompleted+1,:)';
    w = w/max(abs(w)); 
    obj.ledWeights = w(:)';
  end

  % obj.currentEpoch = obj.numEpochsCompleted + 1;
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