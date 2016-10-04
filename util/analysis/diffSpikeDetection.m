function r = diffSpikeDetection(r, threshold, epochNum)
  % take the differential of spikes and threshold from there
  % epochNum = 0 means all epochs


  % r.old.spikes = r.spikes; r.spikes = [];
  % r.old.spikeData = r.spikeData;
  if epochNum == 0
    r.spikeData.times = [];
    r.spikes = [];
  else
    r.spikes(epochNum, :) = 0;
  end 
  if length(epochNum) == 1 && epochNum == 0
    for ii = 1:size(r.resp,1)
      ep = epochNum(ii);
      spikeTimes = getThresCross([0 diff(r.resp(ep,:))], threshold, 1);
      spikesBinary = zeros(size(r.resp(ep,:)));
      spikesBinary(spikeTimes) = 1;
      r.spikes(ep,:) = spikesBinary;
      fprintf('clipped spikes from %u to %u\n', length(r.spikeData.amps{ep}), length(spikeTimes));
      r.spikeData.times{ep} = spikeTimes;
    end
  elseif length(epochNum) > 1
    for ii = 1:length(epochNum)
      ep = epochNum(ii);
      spikeTimes = getThresCross([0 diff(r.resp(ep,:))], threshold, 1);
      spikesBinary = zeros(size(r.resp(ep,:)));
      spikesBinary(spikeTimes) = 1;
      r.spikes(ep, :) = spikesBinary;
      % for now, doesn't change spikeData.amps so use that as old spike count
      fprintf('clipped spikes from %u to %u\n', length(r.spikeData.amps{ep}), length(spikeTimes));
      r.spikeData.times{ep} = spikeTimes;
    end
  else
    spikeTimes = getThresCross([0 diff(r.resp(epochNum,:))], threshold, 1);
    spikesBinary = zeros(size(r.resp(epochNum,:)));
    spikesBinary(spikeTimes) = 1;
    r.spikes(epochNum, :) = spikesBinary;
    fprintf('clipped spikes from %u to %u\n', length(r.old.spikeData.times{epochNum}), length(spikeTimes));
    r.spikeData.times{epochNum} = spikeTimes;
  end


  % keep track of changes from SpikeDetectorOnline
  str = sprintf('epoch %u - used differential to get spikes with threshold of %.1f', epochNum, threshold);
  if isfield(r, 'report')
    r.report{end+1} = str;
  else
    r.report{1} = str;
  end
