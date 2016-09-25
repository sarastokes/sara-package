classdef SplitFieldCentering < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol
% Max's SplitFieldCentering protocol with a few ManookinLabStageProtocol changes and chromatic options
% right now this is working for achromatic and chromatic.. committing now before I try to change absolutely everything for cone-iso

properties
    preTime = 250 % ms
    stimTime = 2000 % ms
    tailTime = 250 % ms
    contrast = 0.9 % relative to mean (0-1)
    chromaticClass = 'achromatic'
    temporalClass = 'sinewave'
    temporalFrequency = 4 % Hz
    radius = 300; % um
    maskRadius = 0 % um
    splitField = false
    rotation = 0;  % deg
    backgroundIntensity = 0.5 % (0-1)
    centerOffset = [0, 0] % [x,y] (um)
    onlineAnalysis = 'none'
    numberOfAverages = uint16(1) % number of epochs to queue
    amp % Output amplifier
end

properties (Hidden)
    ampType
    temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave'})
    chromaticClassType = symphonyui.core.PropertyType('char', 'row', {'achromatic', 'L-iso', 'M-iso', 'S-iso', 'LM-iso', 'red', 'yellow', 'green', 'blue'})
    onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    currentColorWeights
    plotColor
end

properties (Hidden, Transient)
  analysisFigure
end

methods
function didSetRig(obj)
  didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
  [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
end

function p = getPreview(obj, panel)
    if isempty(obj.rig.getDevices('Stage'))
        p = [];
        return;
    end
    p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
        'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
end

function prepareRun(obj)
  prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);

  % catch some errors
  if strcmp(obj.temporalClass, 'sinewave') && ~isempty(strfind(obj.chromaticClass, '-iso'))
    error('cone iso only works with squarewave splitfield, use conesweep for ff sinewave');
  end

  [obj.currentColorWeights, obj.plotColor, ~] = setColorWeightsLocal(obj, obj.chromaticClass);

  stimTrace = getStimTrace(obj, 'modulation');
  obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure', obj.rig.getDevice(obj.amp), stimTrace, 'stimColor', obj.plotColor);

  obj.showFigure('edu.washington.riekelab.manookin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp), 'recordingType', obj.onlineAnalysis);

  if ~strcmp(obj.onlineAnalysis, 'none')
    if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
      obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.F1F2_PTSH);
      f = obj.analysisFigure.getFigureHandle();
      set(f, 'Name', 'Cycle avg PTSH');
      obj.analysisFigure.userData.runningTrace = 0;
      obj.analysisFigure.userData.axesHandle = axes('Parent', f);
    else
      obj.analysisFigure.userData.runningTrace = 0;
    end
  end
end

function F1F2_PTSH(obj, ~, epoch) % online analysis function
  response = epoch.getResponse(obj.rig.getDevice(obj.amp));
  quantities = response.getData();
  sampleRate = response.sampleRate.quantityInBaseUnits;

  axesHandle = obj.analysisFigure.userData.axesHandle;
  runningTrace = obj.analysisFigure.userData.runningTrace;

  if strcmp(obj.onlineAnalysis, 'extracellular')
    filterSigma = (20/1000) * sampleRate;
    newFilt = normpdf(1:10*filterSigma, 10*filterSigma/2, filterSigma);
    res = spikeDetectorOnline(quantities, [], sampleRate);
    epochResponseTrace = zeros(size(quantities));
    epochResponseTrace(res.sp) = 1; %spike binary
    epochResponseTrace = sampleRate*conv(epochResponseTrace,newFilt,'same');
  else
    epochResponseTrace = quantities-mean(quantities(1:sampleRate*obj.preTime/1000));
    if strcmp(obj.onlineAnalysis,'exc') %measuring exc
        epochResponseTrace = epochResponseTrace./(-60-0); %conductance (nS), ballpark
    elseif strcmp(obj.onlineAnalysis,'inh') %measuring inh
        epochResponseTrace = epochResponseTrace./(0-(-60)); %conductance (nS), ballpark
    end
  end

  noCycles = floor(obj.temporalFrequency*obj.stimTime/1000);
  period = (1/obj.temporalFrequency)*sampleRate;
  epochResponseTrace(1:(sampleRate*obj.preTime/1000)) = [];
  cycleAvgResp = 0;
  for c = 1:noCycles
    cycleAvgResp = cycleAvgResp + epochResponseTrace((c-1) * period+1:c*period);
  end
  cycleAvgResp = cycleAvgResp ./ noCycles;
  timeVector = (1:length(cycleAvgResp))./sampleRate;
  runningTrace = runningTrace + cycleAvgResp;
  cla(axesHandle);
  h = line(timeVector, runningTrace./obj.numEpochsCompleted);
  set(h, 'color', [0 0 0], 'linewidth', 2);
  xlabel(axesHandle, 'Time (s)');
  title(axesHandle, 'Running cycle average...')
  if strcmp(obj.onlineAnalysis,'extracellular')
    ylabel(axesHandle, 'spike rate (hz)');
  else
    ylabel(axesHandle, 'resp (ns)');
  end
  obj.analysisFigure.userData.runningTrace = runningTrace;
end

function p = createPresentation(obj)
  p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
  p.setBackgroundColor(obj.backgroundIntensity); % Set background intensity

  % Create grating stimulus.
  grate = stage.builtin.stimuli.Grating('square'); %square wave grating
  grate.orientation = obj.rotation;
  grate.size = [2 * obj.radius, 2 * obj.radius];
  grate.position = obj.canvasSize/2 + obj.centerOffset;
  grate.spatialFreq = 1/(4*obj.radius);
  if (obj.splitField)
      grate.phase = 90;
  else %full-field
      grate.phase = 0;
  end
  p.addStimulus(grate); %add grating to the presentation

  %make it contrast-reversing
  if (obj.temporalFrequency > 0)
     if strcmp(obj.chromaticClass, 'achromatic')
      grateContrast = stage.builtin.controllers.PropertyController(grate, 'contrast', @(state)getGrateContrast(obj, state.time - obj.preTime/1e3));
      p.addController(grateContrast); %add the controller
     else
       grateColor = stage.builtin.controllers.PropertyController(grate, 'color', @(state)getGrateColor(obj, state.time - obj.preTime/1e3));
       p.addController(grateColor);
     end
  end

  function c = getGrateContrast(obj, time)
    if strcmp(obj.temporalClass, 'sinewave')
      c = obj.contrast.*sin(2 * pi * obj.temporalFrequency * time);
    else
      c = obj.contrast.*sign(sin(2 * pi * obj.temporalFrequency * time));
    end
  end

  function c = getGrateColor(obj, time)
    if time >= 0
      if strcmp(obj.temporalClass, 'sinewave')
        c = obj.contrast * obj.currentColorWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
      else
        c = obj.contrast * obj.currentColorWeights * sign(sin(obj.temporalFreuency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
      end
    else
      c = obj.backgroundIntensity;
    end
  end
  % Create aperture
  aperture = stage.builtin.stimuli.Rectangle();
  aperture.position = obj.canvasSize/2 + obj.centerOffset;
  aperture.color = obj.backgroundIntensity;
  aperture.size = [2*obj.radius, 2*obj.radius];
  mask = stage.core.Mask.createCircularAperture(1, 1024); %circular aperture
  aperture.setMask(mask);
  p.addStimulus(aperture); %add aperture

  if (obj.maskRadius > 0) % Create mask
      mask = stage.builtin.stimuli.Ellipse();
      mask.position = obj.canvasSize/2 + obj.centerOffset;
      mask.color = obj.backgroundIntensity;
      mask.radiusX = obj.maskRadius;
      mask.radiusY = obj.maskRadius;

      maskVisibleController = stage.builtin.controllers.PropertyController(mask, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);

      p.addStimulus(mask); %add mask
      p.addController(maskVisibleController);
  end

  %hide during pre & post
  grateVisibleController = stage.builtin.controllers.PropertyController(grate, 'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
  p.addController(grateVisibleController);
end

function prepareEpoch(obj, epoch)
  prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch)

  if obj.maskRadius > 0
    stimulusClass = 'annulus';
  else
    stimulusClass = 'spot';
  end
  epoch.addParameter('stimulusClass', stimulusClass);
  epoch.addParameter('plotColor', obj.plotColor);

end

function controllerDidStartHardware(obj)
  controllerDidStartHardware@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
  if (obj.numEpochsCompleted >= 1) && (obj.numEpochsCompleted < obj.numberOfAverages)
      obj.rig.getDevice('Stage').replay
  else
      obj.rig.getDevice('Stage').play(obj.createPresentation());
  end
end

function tf = shouldContinuePreparingEpochs(obj)
  tf = obj.numEpochsPrepared < obj.numberOfAverages;
end

function tf = shouldContinueRun(obj)
  tf = obj.numEpochsCompleted < obj.numberOfAverages;
end
end
end
