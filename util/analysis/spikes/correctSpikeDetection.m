function r = correctSpikeDetection(r, threshold, direction, epochs)

  % 9Oct2016 - edited chromatic spot, it works but needs to be cleaned up later

  if isfield(r, 'data')
    if length(epochs) == 1
      error('include to epoch number references for chromatic spot');
    else
      epochNum = epochs(1);
      respNum = epochs(2);
    end
  end

if ~isfield(r, 'data') % chromatic spot uses r.data
  n = size(r.resp,1);
  r.correctedThreshold = threshold;
  r.old.spikeData = r.spikeData;
  r.old.spikes = r.spikes;
  if epochs == 0
    epoch = 1:n;
    for jj = 1:length(epoch)
        ep = epoch(jj);
      correctedSpikeTimes = 0; correctedSpikeAmps = 0;
      for ii = 1:length(r.old.spikeData.times{ep})
        if strcmp(direction,'up')
          if r.old.spikeData.amps{ep}(1,ii) > threshold
            correctedSpikeTimes(1, end+1) = r.old.spikeData.times{ep}(ii);
            correctedSpikeAmps(1, end+1) = r.old.spikeData.amps{ep}(ii);
          end
        elseif strcmp(direction, 'down')
          if r.old.spikeData.amps{ep}(1,ii) < threshold
            correctedSpikeTimes(1, end+1) = r.old.spikeData.times{ep}(ii);
            correctedSpikeAmps(1, end+1) = r.old.spikeData.amps{ep}(ii);
          end
        end
      end
      r.spikeData.times{ep} = correctedSpikeTimes(2:end);
      r.spikeData.amps{ep} = correctedSpikeAmps(2:end);
      r.spikeData.resp(epochs,:) = 0;
      r.spikeData.resp(epochs, correctedSpikeTimes(2:end)) = correctedSpikeAmps(2:end);
      r.spikes(ep,:) = 0;
      r.spikes(ep, r.spikeData.times{ep}) = 1;
    end
  elseif epochs > 0
    correctedSpikeTimes = 0; correctedSpikeAmps = 0;
    for ii = 1:length(r.old.spikeData.times{epochs})
      if strcmp(direction, 'up')
        if r.old.spikeData.amps{epochs}(1,ii) > threshold
          correctedSpikeTimes(1, end+1) = r.old.spikeData.times{epochs}(ii);
          correctedSpikeAmps(1, end+1) = r.old.spikeData.amps{epochs}(ii);
        end
      end
    end
    r.spikeData.times{epochs} = correctedSpikeTimes(2:end);
    r.spikeData.amps{epochs} = correctedSpikeAmps(2:end);
    r.spikeData.resp(epochs,:) = 0;
    r.spikeData.resp(epochs, correctedSpikeTimes(2:end)) = correctedSpikeAmps(2:end);
    r.spikes(epochs, :) = 0;
    r.spikes(epochs, r.spikeData.times{epochs}) = 1;
  end
else % ChromaticSpot
  r.data(epochNum).old.spikeData = r.data(epochNum).spikeData;
  % if epochs == 0 % this isn't ready
  %   epoch = 1:length(r);
  %   for jj = 1:length(epoch)
  %       ep = epoch(jj);
  %       r(ep).correctedThreshold = threshold;
  %       r(ep).old.spikeData = r.spikeData;
  %       r(ep).old.spikes = r.spikes;
  %     correctedSpikeTimes = 0; correctedSpikeAmps = 0;
  %     for ii = 1:length(r(jj).old.spikeData.times)
  %       if strcmp(direction,'up')
  %         if r(ep).old.spikeData.amps{respNum}(1,ii) > threshold
  %           correctedSpikeTimes(1, end+1) = r(ep).old.spikeData.times(ii);
  %           correctedSpikeAmps(1, end+1) = r(ep).old.spikeData.amps(ii);
  %         end
  %       elseif strcmp(direction, 'down')
  %         if r(ep).old.spikeData.amps{respNum}(1,ii) < threshold
  %           correctedSpikeTimes(1, end+1) = r(ep).old.spikeData.times(ii);
  %           correctedSpikeAmps(1, end+1) = r(ep).old.spikeData.amps(ii);
  %         end
  %       end
  %     end
  %     r(ep).spikeData.times{respNum} = correctedSpikeTimes(2:end);
  %     r(ep).spikeData.amps{respNum} = correctedSpikeAmps(2:end);
  %     r(ep).spikeData.resp(respNum, :) = zeros(1, size(r(ep).spikes,2));
  %     r(ep).spikeData.resp(respNum, correctedSpikeTimes(2:end)) = correctedSpikeAmps(2:end);
  %     r(ep).spikes(:) = 0;
  %     r(ep).spikes(r(ep).spikeData.times) = 1;
  %   end
  % elseif epochs > 0
    correctedSpikeTimes = 0; correctedSpikeAmps = 0;
    for ii = 1:size(r.data(epochNum).resp,1)
      if r.data(epochNum).old.spikeData.amps{respNum}(1,ii) > threshold
        correctedSpikeTimes(1, end+1) = r.data(epochNum).old.spikeData.times{respNum}(ii);
        correctedSpikeAmps(1, end+1) = r.data(epochNum).old.spikeData.amps{respNum}(ii);
      end 
    end
    spikeTimes = correctedSpikeTimes(2:end);
    spikeAmps = correctedSpikeAmps(2:end);
    r.data(epochNum).spikeData.resp(respNum, :) = 0;
    spikesBinary = zeros(1, length(r.data(epochNum).spikeData.resp));
    spikesBinary(correctedSpikeTimes(2:end)) = correctedSpikeAmps(2:end);
    r.data(epochNum).spikeData.resp(respNum, :) = spikesBinary;
    r.data(epochNum).spikes(respNum, :) = 0;
    spikesBinary = zeros(1, length(r.data(epochNum).spikes));
    spikesBinary(spikeTimes) = 1;

    r.data(epochNum).spikes(respNum, :) = spikesBinary;
    r.data(epochNum).spikeData.times{respNum} = spikeTimes;
  % end
end
