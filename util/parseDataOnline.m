function r = getDataOnline(epochBlock, protocol)
  % also for quick offline data

  numEpochs = length(epochBlock.epochs);
  trial = 0;
  % data from all protocols
  for ii = 1:numEpochs
    r.protocol = epochBlock.protocolId; % get protocol name
    epoch = epochBlock.epochs{ii}; % get epoch
    resp = epoch.responses{1}.getData; % get response
    if ii == 1
      r.resp = zeros(numEpochs, length(resp));
      r.resp(1,:) = resp;
      r.params.preTime = epochBlock.protocolParameters('preTime');
      r.params.stimTime = epochBlock.protocolParameters('stimTime');
      r.params.tailTime = epochBlock.protocolParameters('tailTime');
      r.params.backgroundIntensity = epochBlock.protocolParameters('backgroundIntensity');
      r.params.ndf = epoch.protocolParameters('ndf');
      r.params.objectiveMag = epoch.protocolParameters('objectiveMag');
      r.params.micronsPerPixel = epoch.protocolParameters('micronsPerPixel');
      r.params. numberOfAverages = epochBlock.protocolParameters('numberOfAverages');
      r.params.sampleRate = 10000;
      r.params.onlineAnalysis =epochBlock.protocolParameters('onlineAnalysis');
    else
      r.resp(ii,:) = resp;
    end
  end

  % protocol specific data - could be condensed but keeping each protocol separate for now.
  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ConeSweep')
    for ii = 1:numEpochs
      epoch = epochBlock.epochs{ii}; % get epoch
      if ii == 1
        r.params.stimClass = epochBlock.protocolParameters('stimClass');
        r.params.contrast = epochBlock.protocolParameters('contrast');
        r.params.radius = epochBlock.protocolParameters('radius');
        r.params.temporalFrequency = epochBlock.protocolParameters('temporalFrequency');
        r.params.temporalClass = epochBlock.protocolParameters('temporalClass');
        r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
        r.params.reverseOrder = epochBlock.protocolParameters('reverseOrder');
        r.analysis.f1amp = zeros(length(r.params.stimClass), numEpochs/length(r.params.stimClass));
        r.analysis.f1phase = zeros(length(r.params.stimClass), numEpochs/length(r.params.stimClass));
      end
      index = rem(ii, length(r.params.stimClass));
      if index == 0
        index = length(r.params.stimClass);
      elseif index == 1
        trial = trial + 1;
      end
      r.trials(ii).chromaticClass = epoch.protocolParameters('chromaticClass');
      [r.analysis.f1amp(index,trial), r.analysis.f1phase(index,trial)] = CTRAnalysis(r, r.resp(ii,:));
    end
  end

    if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.IsoSTC')
      for ii = 1:length(epochBlock.epochs)
        epoch = epochBlock.epochs{ii}; % get epoch
        if ii == 1
          r.params.paradigmClass = epochBlock.protocolParameters('paradigmClass');
          r.params.chromaticClass = epochBlock.protocolParameters('chromaticClass');
          r.params.contrast = epochBlock.protocolParameters('contrast');
          r.params.radius = epochBlock.protocolParameters('radius');
          if strcmp(r.params.paradigmClass,'ID')
            r.params.temporalClass = epoch.protocolParameters('temporalClass')
          elseif strcmp(r.params.paradigmClass, 'STA')
            r.params.randomSeed = epochBlock.protocolParameters('randomSeed');
            r.params.stdev = epochBlock.protocolParameters('stdev');
          end
          r.params.centerOffset = epochBlock.protocolParameters('centerOffset');
        end
        r.params.seed = epoch.protocolParameters('seed');
      end
    end

  function [f1amp, f1phase] = CTRAnalysis(r, response)
    responseTrace = getResponseByType(response, 'extracellular');

    responseTrace = responseTrace(r.params.preTime/1000 * r.params.sampleRate+1 : end);
    binRate = 60;
    binWidth = r.params.sampleRate/binRate;
    numBins = floor(r.params.stimTime/1000 * binRate);
    binData = zeros(1, numBins);
    for k = 1:numBins
      index = round((k-1) * binWidth+1 : k*binWidth);
      binData(k) = mean(responseTrace(index));
    end
    binsPerCycle = binRate / r.params.temporalFrequency;
    numCycles = floor(length(binData) / binsPerCycle);
    cycleData = zeros(1, floor(binsPerCycle));

    for k = 1:numCycles
      index = round((k-1) * binsPerCycle) + (1:floor(binsPerCycle));
      cycleData = cycleData + binData(index);
    end
    cycleData = cycleData / k;

    % get the F1 response
    ft = fft(cycleData);
    f1amp = abs(ft(2))/length(ft)*2;
    f1phase = angle(ft(2)) * 180/pi;
  end
end % overall function
