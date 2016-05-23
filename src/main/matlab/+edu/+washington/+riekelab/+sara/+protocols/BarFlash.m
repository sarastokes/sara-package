classdef BarFlash < edu.washington.riekelab.protocols.RiekeLabStageProtocol
    % add in .manookin before protocols later

  properties
    amp
    preTime = 500
    stimTime = 500
    tailTime = 500
    orientationClass = 'both'
    positions = 0
    centerOffset = [0,0]
    barSize = [300, 100]
    barColor = 1
    backgroundIntensity = 0.5
    onlineAnalysis = 'none'
    %numberOfStimuli = uint16(5)       % number of times bar is presented
    numberOfAverages = uint16(5)       % number of epochs
    %interpulseInterval = 0.5          % Duration between epochs (s)
  end

  properties (Hidden)
    ampType
    onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    orientationClassType = symphonyui.core.PropertyType('char', 'row', {'both', 'vertical', 'horizontal'})
    orientation
    positionArray
    position
    intensity
    protocolUsed
    % if using RiekeLabStageProtocol, uncomment these!
    canvasSize
    frameRate
    correctedIntensity
    correctedMean
    % if using RiekeLabStageProtocol for LCR, uncomment this too:
      stageClass
  end

  properties (Hidden, Transient)
    % future online analysis figure
    analysisFigure
  end

  methods
  function didSetRig(obj)
    didSetRig@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
    [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
  end

  function prepareRun(obj)
    % having some troubles getting ManookinLabStageProtocol to work
    obj.protocolUsed = 'rieke';  % other option is 'manookin', 'rieke_LCR'

    if ~strcmpi(obj.protocolUsed,'manookin')
     prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
    end

    if strcmpi(obj.protocolUsed,'manookin')
     prepareRun@edu.washington.riekelab.protocols.ManookinLabStageProtocol(obj);
    end

    if strcmpi(obj.protocolUsed,'rieke_LCR')
      % get frame rate. need to check if it's a LCR rig.
      if ~isempty(strfind(obj.rig.getDevice('Stage').name,'LightCrafter'))
        obj.frameRate = obj.rig.getDevice('Stage').getPatternRate();
      else
        obj.frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
      end
    end

    if length(obj.barColor) == 1
      obj.intensity = obj.barColor;
      obj.correctedIntensity = obj.intensity * 255;
    else
      % obj.intensity = [obj.barColor obj.barColor obj.barColor];
      % color settings
    end
    obj.correctedMean = obj.backgroundIntensity * 255;

    if ~strcmpi(obj.protocolUsed,'manookin')
      obj.canvasSize = obj.rig.getDevice('Stage')
    end

    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

    % this is where the function to analyze responses online will go
  %  function BarCenteringAnalysis(obj,~,epoch)
  %    response = epoch.getResponse(obj.rig.getDevice(obj.amp));
  %    responseTrace = getData();
  %    sampleRate = response.sampleRate.quantityInBaseUnits;

      % get the amplitude
  %  end

    obj.organizeParameters();
  end

  function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    rect = stage.builtin.stimuli.Rectangle();
    rect.size = obj.barSize;
    rect.orientation = obj.orientation;
    if length(obj.positions) == 1
      if obj.positions == 0
        rect.position = obj.canvasSize/2 + obj.centerOffset;
      end
    else
      if strcmpi(obj.orientation,'vertical')
        Xpos = 0;
        Ypos = obj.centerOffset(2) + ((obj.canvasSize/2)*obj.position);
      elseif strcmpi(obj.orientation,'horizontal')
        Ypos = 0;
        Xpos = obj.centerOffset(1) + ((obj.canvasSize/2)*obj.position);
      end
      rect.position = [Xpos,Ypos]; display(rect.position);
    end
    obj.position = rect.position;
    rect.color = obj.barColor;
    rect.opacity = 1;

    % add stimulus to the presentation
    p.addStimulus(rect);

    % only visible during stimTime
    rectVisible = stage.builtin.controllers.PropertyController(rect,'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime ) * 1e-3);
    p.addController(rectVisible);
  end

  function setBarPosition(obj)
    if obj.orientation == 0
        Xpos = 0;
        Ypos = obj.centerOffset(2) + ((obj.canvasSize/2)*obj.position);
    elseif obj.orientation == 180
        Ypos = 0;
        Xpos = obj.centerOffset(1) + ((obj.canvasSize/2)*obj.position);
    end
  end


  function organizeParameters(obj)
    % create the array of bar positions
    numberOfTrials = double(obj.numberOfAverages)* length(obj.positions);
    if strcmpi(obj.orientationClass,'both')
      numberOfTrials = numberOfTrials*2;
    end
    positionArray = zeros(1,numberOfTrials);

    for ii = 1:length(obj.positions)
      n = (ii-1) * double(obj.numberOfAverages); n = n + 1;
      nn = n + double(obj.numberOfAverages); nn = nn - 1;
      positionArray(1,n:nn) = obj.positions(ii);
    end


    % not sure if we need random order but i left it in just in case
    if (obj.randomOrder)
      epochSyntax = randperm(obj.numberOfAverages);
    else
      epochSyntax = 1:obj.numberOfAverages;
    end
  end

  function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

    device = obj.rig.getDevice(obj.amp);
    duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
    epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
    epoch.addResponse(device);

    obj.position = obj.positions(obj.numEpochsCompleted+1);

    switch obj.orientationClass
    case 'vertical'
      obj.orientation = 0;
    case 'horizontal'
      obj.orientation = 180;
    case 'both'
      if obj.numEpochsCompleted >
    if strcmpi(obj.orientationClass,'both')

    end

    obj.setPosition();

    epoch.addParameter('position', obj.position)
  end


  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < obj.numberOfAverages;
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < obj.numberOfAverages;
  end
  end
end
