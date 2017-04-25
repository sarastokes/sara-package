function r = rmEpoch(r, epNum)
  % to remove epochs from main data structure

  % move the epoch to r.omittedEpochs
  if ~isfield(r, 'omittedEpochs')
    r.omittedEpochs.numEpochs = 1;
  else
    r.omittedEpochs.numEpochs = r.omittedEpochs.numEpochs + 1;
  end
  ind = r.omittedEpochs.numEpochs;
  r.omittedEpochs.list(ind) = epNum;
  r.omittedEpochs.resp(ind, :) = r.resp(epNum,:);
  r.omittedEpochs.startTimes{ind} = r.startTimes{epNum};
  r.omittedEpochs.uuidEpoch{ind} = r.uuidEpoch{epNum};
  if strcmp(r.params.recordingType, 'extracellular')
    r.omittedEpochs.spikes(ind, :) = r.spikes(epNum, :);
    r.omittedEpochs.spikeData.resp(ind,:) = r.spikeData.resp(epNum,:);
    r.omittedEpochs.spikeData.times{ind} = r.spikeData.times{epNum};
    r.omittedEpochs.spikeData.amps{ind} = r.spikeData.amps{epNum};
    r.spikes(epNum, :) = [];
    r.spikeData.resp(epNum,:) = [];
    r.spikeData.times{epNum} = [];
    r.spikeData.amps{epNum} = [];  
  elseif strcmp(r.params.recordingType, 'voltage_clamp')
    r.omittedEpochs.analog(ind,:) = r.analog(epNum,:);
    r.analog(epNum, :) = [];
  end


  % clear epoch data
  r.resp(epNum, :) = [];

  % this won't reduce the # of cells just replaces with [] but should be fine
  r.uuidEpoch{epNum} = [];
  r.startTimes{epNum} = [];

  r.numEpochs = r.numEpochs - 1;
end
