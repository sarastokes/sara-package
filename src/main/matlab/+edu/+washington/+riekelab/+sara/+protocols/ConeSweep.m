classdef ConeSweep < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

properties
  amp
  stimClass = 'lms'
  preTime = 200
  stimTime = 1000
  tailTime = 200
  contrast = 1
  backgroundIntensity = 0.5
  radius = 1500
  maskRadius = 0
  temporalClass = 'sinewave'
  temporalFrequency = 2
  centerOffset = [0,0]
  checkSpikes = false                     % pulls up SpikeDetectionFigure
  onlineAnalysis = 'extracellular'
  numberOfAverages = uint16(9)
end

properties (Hidden)
  ampType
  stimClassType = symphonyui.core.PropertyType('char', 'row', {'lms', 'olms', 'alms', 'klms', 'cpy', 'ysa', 'lmx', 'zwx', 'azwx' 'almx', 'yxa', 'rgb', 'rgby', 'ghij'})
  temporalClassType = symphonyui.core.PropertyType('char', 'row', {'sinewave', 'squarewave', 'flash'})
  onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
  chromaticClass
  stimulusClass
  currentColorWeights
  currentContrast
  currentEpoch
end

properties (Hidden) % online analysis properties
  stimTrace
  stimValues
  sweepColor
  plotColors
  plotColor % some of these are unnecessary, condense later
end

properties (Constant)
  CONES = 'lmsa'
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

  % find plotColors
  if ~isempty(strfind(obj.stimClass, 'rgb'))
    leds = {'red' 'green' 'blue' 'yellow'};
    for ii = 1:length(obj.stimClass)
      colorCall = leds(ii);
      [~, obj.plotColors(ii,:), ~] = setColorWeightsLocal(obj, colorCall);
    end
  else
    for ii = 1:length(obj.stimClass)
      colorCall = obj.stimClass(ii);
      [~, obj.plotColors(ii, :), ~] = setColorWeightsLocal(obj, colorCall);
    end
  end

  % trace for response figure
  x = 0:0.001:((obj.stimTime - 1) * 1e-3);
  obj.stimValues = zeros(1, length(x));
  for ii = 1:length(x)
    if strcmp(obj.temporalClass, 'sinewave')
      obj.stimValues(1,ii) = sin(obj.temporalFrequency * x(ii) * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
    elseif strcmp(obj.temporalClass, 'squarewave')
      obj.stimValues(1,ii) = sign(sin(obj.temporalFrequency * x(ii) * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
    end
  end
  obj.stimTrace = [(obj.backgroundIntensity * ones(1, obj.preTime)) obj.stimValues (obj.backgroundIntensity * ones(1, obj.tailTime))];

  % set up figures
  if numel(obj.rig.getDeviceNames('Amp')) < 2
    obj.showFigure('edu.washington.riekelab.sara.figures.ResponseWithStimFigure',...
      obj.rig.getDevice(obj.amp), obj.stimTrace);
  else
    obj.showFigure('edu.washington.riekelab.sara.figures.DualResponseFigure',...
      obj.rig.getDevice(obj.amp), obj.rig.getDevice(obj.amp));
  end

  obj.showFigure('edu.washington.riekelab.sara.figures.ConeSweepFigure',...
    obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace);

  if isempty(obj.analysisFigure) || ~isvalid(obj.analysisFigure)
    obj.analysisFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @obj.F1F2_PTSH);
    f = obj.analysisFigure.getFigureHandle();
    set(f, 'Name', 'Cycle avg PTSH');
    for ii = 1:length(obj.CONES)
      obj.analysisFigure.userData.runningTrace.(obj.CONES(ii)) = 0;
    end
    obj.analysisFigure.userData.axesHandle = axes('Parent', f);
  else
    for ii = 1:length(obj.CONES)
      obj.analysisFigure.userData.runningTrace.(obj.CONES(ii)) = 0;
    end
  end

  if ~strcmp(obj.onlineAnalysis, 'none')
    if strcmp(obj.onlineAnalysis, 'extracellular') || strcmp(obj.onlineAnalysis, 'Spikes_CClamp')
       obj.showFigure('edu.washington.riekelab.sara.figures.ConeFiringRateFigure',...
      obj.rig.getDevice(obj.amp), obj.stimClass, 'stimTrace', obj.stimTrace, 'onlineAnalysis', obj.onlineAnalysis);
    end
  end
  if strcmp(obj.onlineAnalysis, 'extracellular') && obj.checkSpikes
    obj.showFigure('edu.washington.riekelab.sara.figures.SpikeDetectionFigure',...
      obj.rig.getDevice(obj.amp));
  end
end % prepareRun

function F1F2_PTSH(obj, ~, epoch)
  % from Max's SplitFieldCentering protocol
  response = epoch.getResponse(obj.rig.getDevice(obj.amp));
  quantities = response.getData();
  sampleRate = response.sampleRate.quantityInBaseUnits;

  axesHandle = obj.analysisFigure.userData.axesHandle;
  cone = lower(epoch.parameters('chromaticClass'));
  runningTrace = obj.analysisFigure.userData.runningTrace(cone(1));

  if strcmp(obj.onlineAnalysis,'extracellular') %spike recording
      filterSigma = (20/1000)*sampleRate; %msec -> dataPts
      newFilt = normpdf(1:10*filterSigma,10*filterSigma/2,filterSigma);
      res = spikeDetectorOnline(quantities,[],sampleRate);
      epochResponseTrace = zeros(size(quantities));
      epochResponseTrace(res.sp) = 1; %spike binary
      epochResponseTrace = sampleRate*conv(epochResponseTrace,newFilt,'same'); %inst firing rate
  else %intracellular - Vclamp
      epochResponseTrace = quantities-mean(quantities(1:sampleRate*obj.preTime/1000)); %baseline
      if strcmp(obj.onlineAnalysis,'exc') %measuring exc
          epochResponseTrace = epochResponseTrace./(-60-0); %conductance (nS), ballpark
      elseif strcmp(obj.onlineAnalysis,'inh') %measuring inh
          epochResponseTrace = epochResponseTrace./(0-(-60)); %conductance (nS), ballpark
      end
  end
  noCycles = floor(obj.temporalFrequency*obj.stimTime/1000);
  period = (1/obj.temporalFrequency)*sampleRate; %data points
  epochResponseTrace(1:(sampleRate*obj.preTime/1000)) = []; %cut out prePts
  cycleAvgResp = 0;
  for c = 1:noCycles
      cycleAvgResp = cycleAvgResp + epochResponseTrace((c-1)*period+1:c*period);
  end
  cycleAvgResp = cycleAvgResp./noCycles;
  timeVector = (1:length(cycleAvgResp))./sampleRate; %sec
  runningTrace = runningTrace + cycleAvgResp;

  % add to userdata
  obj.analysisFigure.userData.runningTrace.(cone) = runningTrace ./ ...
    (ceil(obj.numEpochsCompleted/length(obj.stimClass)));

  % edit the plot
  cla(axesHandle);

  % kinda messy but it'll do
  h = line(timeVector, runningTrace./ceil(obj.numEpochsCompleted/length(obj.stimClass)),...
    'Parent', axesHandle);
  set(h, 'Color', getPlotColor(epoch.parameters('chromaticClass')), 'LineWidth', 2);
  a = 1;
  for ii = 1:length(obj.CONES)
    if ~strcmp(obj.CONES(ii), cone)
      a = a + 1;
      h(a) = line(timeVector, obj.analysisFigure.userData.runningTrace.(obj.CONES(ii)),...
        'Parent', axesHandle);
      set(h(a), 'Color', getPlotColor(obj.CONES(ii)), 'LineWidth', 2);
    end
  end
  xlabel(axesHandle,'Time (s)')
  title(axesHandle,'Running cycle average...')
  if strcmp(obj.onlineAnalysis, 'extracellular')
    ylabel(axesHandle, 'Spike rate (Hz)');
  else
    ylabel(axesHandle, 'Resp (nS)');
  end

end % F1F2_PTSH

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
                c = obj.currentContrast * obj.currentColorWeights * sin(obj.temporalFrequency * time * 2 * pi) * obj.backgroundIntensity + obj.backgroundIntensity;
              elseif strcmp(obj.temporalClass, 'squarewave')
                 c = obj.currentContrast * obj.currentColorWeights * sign(sin(obj.temporalFrequency * time * 2 * pi)) * obj.backgroundIntensity + obj.backgroundIntensity;
              end
          else
              c = obj.backgroundIntensity;
          end
      end
  end

  function prepareEpoch(obj, epoch)
      prepareEpoch@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj, epoch);

      obj.currentEpoch = obj.numEpochsCompleted + 1;

      index = rem(obj.currentEpoch,length(obj.stimClass));
      if index == 0
        index = length(obj.stimClass);
      end
      if ~isempty(strfind(obj.stimClass, 'rgb'))
        leds = {'red' 'green' 'blue' 'yellow'};
        colorCall = leds(index);
      else
        colorCall = obj.stimClass(index);
      end

      [obj.currentColorWeights, obj.sweepColor, obj.chromaticClass]  = setColorWeightsLocal(obj, colorCall);
      obj.plotColor = obj.sweepColor;
      epoch.addParameter('chromaticClass', obj.chromaticClass);
      epoch.addParameter('sweepColor', obj.sweepColor);
      epoch.addParameter('stimulusClass', obj.stimulusClass);

  end

  function tf = shouldContinuePreparingEpochs(obj)
    tf = obj.numEpochsPrepared < obj.numberOfAverages;
   end

  function tf = shouldContinueRun(obj)
    tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
end
end
