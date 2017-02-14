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
  r.omittedEpochs.spikes(ind, :) = r.spikes(epNum, :);
  r.omittedEpochs.startTimes{ind} = r.startTimes{epNum};
  r.omittedEpochs.uuidEpoch{ind} = r.uuidEpoch{epNum};
  r.omittedEpochs.spikeData.resp(ind,:) = r.spikeData.resp(epNum,:);
  r.omittedEpochs.spikeData.times{ind} = r.spikeData.times{epNum};
  r.omittedEpochs.spikeData.amps{ind} = r.spikeData.amps{epNum};


  % clear epoch data
  r.resp(epNum, :) = [];
  r.spikes(epNum, :) = [];
  r.spikeData.resp(epNum,:) = [];
  r.spikeData.times{epNum} = [];
  r.spikeData.amps{epNum} = [];
  % this won't reduce the # of cells just replaces with [] but should be fine
  r.uuidEpoch{epNum} = [];
  r.startTimes{epNum} = [];

  r.numEpochs = r.numEpochs - 1;
end
