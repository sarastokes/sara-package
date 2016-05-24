classdef BarCentering < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

  properties
    amp
    preTime = 500
    stimTime = 500
    tailTime = 500
    orientationClass = 'vertical'
    % randomOrder = false
    positions = [-0.9:0.1:0.9] % %screen from the center [-1 1]
    centerOffset = [0,0]
    barSize = [1000, 50]
    barColor = 1
    backgroundIntensity = 0.5
    onlineAnalysis = 'none'
    %numberOfStimuli = uint16(5)       % number of times bar is presented
    numberOfAverages = uint16(5)       % number of epochs
    %interpulseInterval = 0.5          % Duration between epochs (s)
    %ndf = 4.0                         % NDF wheel - deal with after mike's updates
  end

  properties (Hidden)
    ampType
    onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    orientationClassType = symphonyui.core.PropertyType('char', 'row', {'both', 'vertical', 'horizontal'})
    orientation
    positionArray
    currentPosition
    position
    numberOfTrials
    orientedBarSize
    intensity
    protocolUsed
    % if using RiekeLabStageProtocol, uncomment these!
    %canvasSize
    %frameRate
    correctedIntensity
    correctedMean
    % if using RiekeLabStageProtocol for LCR, uncomment this too:
     % stageClass
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
    obj.protocolUsed = 'manookin';  % options:'rieke', 'manookin', 'rieke_LCR'

    if strcmpi(obj.protocolUsed,'manookin')
     prepareRun@edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol(obj);
    else
     prepareRun@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj);
     obj.canvasSize = obj.rig.getDevice('Stage')
     if strcmpi(obj.protocolUsed,'rieke_LCR')
       % get frame rate. need to check if it's a LCR rig.
       if ~isempty(strfind(obj.rig.getDevice('Stage').name,'LightCrafter'))
         obj.frameRate = obj.rig.getDevice('Stage').getPatternRate();
       else
         obj.frameRate = obj.rig.getDevice('Stage').getMonitorRefreshRate();
       end
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

    Bar = stage.builtin.stimuli.Rectangle();
    Bar.size = obj.barSize;
    %Bar.orientation = obj.orientation;
    if strcmpi(obj.orientationClass,'vertical')
      obj.orientation = 0; Bar.orientation = obj.orientation;
%      if obj.barSize(1) > obj.barSize(2)
%        Bar.size = obj.barSize;
%      else
%        Bar.size = fliplr(obj.barSize);
%      end
    elseif strcmpi(obj.orientationClass,'horizontal')
      obj.orientation = 180; Bar.orientation = obj.orientation;
      if obj.barSize(2) > obj.barSize(1)
        Bar.size = obj.barSize;
      else
        Bar.size = fliplr(obj.barSize);
      end
    else % deal with both later.. or just delete
      Bar.orientation = obj.orientation;
    end
    Bar.position = obj.position;

    Bar.color = obj.barColor;
    Bar.opacity = 1;

    % add stimulus to the presentation
    p.addStimulus(Bar);

    % only visible during stimTime
    barVisible = stage.builtin.controllers.PropertyController(Bar,'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime ) * 1e-3);
    p.addController(barVisible);
  end

  function setBarPosition(obj)
    switch obj.orientationClass
    case 'vertical'
      obj.orientation = 0;
      if obj.barSize(1) > obj.barSize(2)
        Bar.size = obj.barSize;
      else
        Bar.size = fliplr(obj.barSize);
      end
    case 'horizontal'
      obj.orientation = 180;
      if obj.barSize(2) > obj.barSize(1)
        Bar.size = obj.barSize;
      else
        Bar.size = fliplr(obj.barSize);
      end
    end
    if obj.orientation == 0
        Xpos = obj.canvasSize(1)/2;
        Ypos = ((obj.canvasSize(2)/2) + obj.centerOffset(2)) + ((obj.canvasSize(2)/2)*obj.currentPosition);
    elseif obj.orientation == 180
        Ypos = obj.canvasSize(2)/2;
        Xpos = ((obj.canvasSize(1)/2) + obj.centerOffset(1)) + ((obj.canvasSize(1)/2)*obj.currentPosition);
    end
    obj.position = [Xpos Ypos];
  end


  function organizeParameters(obj)
    % create the array of bar positions
    obj.numberOfTrials = double(obj.numberOfAverages)* length(obj.positions);
    if strcmpi(obj.orientationClass,'both')
      obj.numberOfTrials = obj.numberOfTrials*2;
    end
    obj.positionArray = zeros(1,obj.numberOfTrials);

    for ii = 1:length(obj.positions)
      n = (ii-1) * double(obj.numberOfAverages); n = n + 1;
      nn = n + double(obj.numberOfAverages); nn = nn - 1;
      obj.positionArray(1,n:nn) = obj.positions(ii);
    end

    % not sure if we need random order but i left it in just in case
    %if (obj.randomOrder)
     % epochSyntax = randperm(obj.numberOfAverages);
    %else
     epochSyntax = 1:obj.numberOfAverages;
    %end
  end

  function prepareEpoch(obj, epoch)
    prepareEpoch@edu.washington.riekelab.protocols.RiekeLabStageProtocol(obj, epoch);

    device = obj.rig.getDevice(obj.amp);
    duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
    epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
    epoch.addResponse(device);

    obj.currentPosition = obj.positionArray(obj.numEpochsCompleted+1);

    switch obj.orientationClass
    case 'vertical'
      obj.orientation = 0;
    case 'horizontal'
      obj.orientation = 180;
    case 'both'
      if obj.numEpochsCompleted > obj.numberOfTrials/2
        obj.orientation = 180;
      else
          obj.orientation = 0;
      end
    end

    obj.setBarPosition();

    display(obj.position);

    epoch.addParameter('position', obj.position);
    epoch.addParameter('orientation', obj.orientation);
  end


  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < (obj.numberOfAverages*numel(obj.positions));
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < (obj.numberOfAverages*numel(obj.positions));
  end

  %function completeEpoch(obj,epoch)
  %  display(obj.position);
  %end

%  function completeRun(obj)
%    assignin('base','brede',obj);
%  end
  end % end of methods
end
