classdef BarCentering < edu.washington.riekelab.manookin.protocols.ManookinLabStageProtocol

  properties
    amp
    preTime = 200
    stimTime = 250
    tailTime = 50
    orientationClass = 'horizontal'
    % randomOrder = false
    positions = [-0.8:0.2:0.8] % %screen from the center [-1 1]
    centerOffset = [0,0]
    barSize = [1000, 50]
    barColor = 1
    backgroundIntensity = 0.5
    onlineAnalysis = 'none'
    numberOfAverages = uint16(5)
    %ndf = 4.0                      % NDF wheel - deal with after mike's updates
  end

  properties (Hidden)
    ampType
    onlineAnalysisType = symphonyui.core.PropertyType('char', 'row', {'none', 'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'})
    orientationClassType = symphonyui.core.PropertyType('char', 'row', {'both', 'vertical', 'horizontal'})
    orientation
    positionArray
    currentPosition
    numberOfOrientations
    protocolUsed
    position
    numberOfTrials
    intensity
    correctedIntensity
    correctedMean
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

%    if length(obj.barColor) == 1
%      obj.intensity = obj.barColor;
%      obj.correctedIntensity = obj.intensity * 255;
%    else
%      % color settings?
%      obj.intensity = obj.barColor;
%    end
%    obj.correctedMean = obj.backgroundIntensity * 255;

    obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));

    % this is where the function to analyze responses online will go
  %  function BarCenteringAnalysis(obj,~,epoch)
  %    response = epoch.getResponse(obj.rig.getDevice(obj.amp));
  %    responseTrace = getData();
  %    sampleRate = response.sampleRate.quantityInBaseUnits;

      % get the amplitude
  %  end
    switch obj.orientationClass
    case 'vertical'
      obj.numberOfOrientations = 1;
    case 'horizontal'
      obj.numberOfOrientations = 1;
    case 'both'
      obj.numberOfOrientations = 2;
    end
    display(obj.numberOfOrientations);


    obj.organizeParameters();
  end

  function p = createPresentation(obj)
    p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
    p.setBackgroundColor(obj.backgroundIntensity);

    % make bar stimulus
    Bar = stage.builtin.stimuli.Rectangle();
    Bar.size = obj.barSize;
    Bar.orientation = obj.orientation;
    Bar.position = obj.position;
    Bar.color = obj.barColor;
    % Bar.opacity = 1;  <-- how is this different from setting intensity?

    % add stimulus to the presentation
    p.addStimulus(Bar);

    % only visible during stimTime
    barVisible = stage.builtin.controllers.PropertyController(Bar,'visible', @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime ) * 1e-3);
    p.addController(barVisible);
  end

  function setBarPosition(obj)
    if obj.orientation == 0
        Xpos = obj.canvasSize(1)/2;
        Ypos = ((obj.canvasSize(2)/2) + obj.centerOffset(2)) + ((obj.canvasSize(2)/2)*obj.currentPosition);
    elseif obj.orientation == 90
        Ypos = obj.canvasSize(2)/2;
        Xpos = ((obj.canvasSize(1)/2) + obj.centerOffset(1)) + ((obj.canvasSize(1)/2)*obj.currentPosition);
    end
    obj.position = [Xpos Ypos];
  end


  function organizeParameters(obj)
    % create the array of bar positions

%    if strcmp(obj.orientationClass,'both')
%      display(obj.numberOfTrials,'debug - both');
%    else
    obj.numberOfTrials = double(obj.numberOfAverages)*length(obj.positions);
%      display(obj.numberOfTrials, 'debug - single');
%    end
    obj.positionArray = zeros(1,obj.numberOfTrials);

    for ii = 1:length(obj.positions)
      n = (ii-1) * double(obj.numberOfAverages); n = n + 1;
      nn = n + double(obj.numberOfAverages); nn = nn - 1;
      obj.positionArray(1,n:nn) = obj.positions(ii);
    end
    display(obj.positionArray,'pre-addition')
    if strcmp(obj.orientationClass,'both')
      obj.numberOfTrials = double(obj.numberOfAverages)*length(obj.positions)*2;
      foo = obj.positionArray;
      foo = foo' * ones(1,2); foo = foo(:)';
      obj.positionArray = foo;
      display(obj.positionArray,'post-addition')
    end
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
      obj.orientation = 90;
      display(obj.orientation,'prepareEpoch');
    case 'both'
      if obj.numEpochsCompleted >= obj.numberOfTrials/2
        obj.orientation = 90;
      else
        obj.orientation = 0;
        display(obj.orientation,'reached 2nd group');
      end
    end

    obj.setBarPosition();  % display(obj.position);

    epoch.addParameter('position', obj.position);
    epoch.addParameter('orientation', obj.orientation);
  end


  function tf = shouldContinuePreparingEpochs(obj)
      tf = obj.numEpochsPrepared < (obj.numberOfAverages * numel(obj.positions)*obj.numberOfOrientations);
  end

  function tf = shouldContinueRun(obj)
      tf = obj.numEpochsCompleted < (obj.numberOfAverages * numel(obj.positions)*obj.numberOfOrientations);
  end
  end % end of methods
end
