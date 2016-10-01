function r = diffSpikeDetection(r, threshold, epochNum)
  % take the differential of spikes and threshold from there

  r.old.spikes = r.spikes; r.spikes = [];
  r.old.spikeData = r.spikeData;
  r.spikeData.times = []; r.spikeData.amps = [];
  spikeTimes = getThresCross([0 diff(r.resp(epochNum,:))], threshold, 1);
  spikesBinary = zeros(size(r.resp(epochNum,:)));
  spikesBinary(spikeTimes) = 1;
  r.spikes(epochNum, :) = spikesBinary;
  fprintf('clipped spikes from %u to %u\n', length(r.old.spikeData.times), length(spikeTimes));
  r.spikeData.times = spikeTimes;


  % keep track of changes from SpikeDetectorOnline
  str = sprintf('epoch %u - used differential to get spikes with threshold of %.1f', epochNum, threshold);
  if isfield(r, 'report')
    r.report{end+1} = str;
  else
    r.report{1} = str;
  end
