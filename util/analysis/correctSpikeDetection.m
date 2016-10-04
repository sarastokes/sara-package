function r = correctSpikeDetection(r, threshold, direction, epochs)

  % if nargin < 4
  %   epochs = 0;
  % elseif nargin < 3
  %   direction = 'up';
  %   epochs = 0; %#ok<*NASGU>
  % end

  % if epochs == 0
  %   epochs = 1:r.numEpochs;
  % end

  n = size(r.resp,1);


if isfield(r, 'protocol')
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
  if epochs == 0
    epoch = 1:length(r);
    for jj = 1:length(epoch)
        ep = epoch(jj);
        r(ep).correctedThreshold = threshold;
        r(ep).old.spikeData = r.spikeData;
        r(ep).old.spikes = r.spikes;
      correctedSpikeTimes = 0; correctedSpikeAmps = 0;
      for ii = 1:length(r(jj).old.spikeData.times)
        if strcmp(direction,'up')
          if r(ep).old.spikeData.amps(1,ii) > threshold
            correctedSpikeTimes(1, end+1) = r(ep).old.spikeData.times(ii);
            correctedSpikeAmps(1, end+1) = r(ep).old.spikeData.amps(ii);
          end
        elseif strcmp(direction, 'down')
          if r(ep).old.spikeData.amps(1,ii) < threshold
            correctedSpikeTimes(1, end+1) = r(ep).old.spikeData.times(ii);
            correctedSpikeAmps(1, end+1) = r(ep).old.spikeData.amps(ii);
          end
        end
      end
      r(ep).spikeData.times = correctedSpikeTimes(2:end);
      r(ep).spikeData.amps = correctedSpikeAmps(2:end);
      r(ep).spikeData.resp = zeros(size(r(ep).spikes));
      r(ep).spikeData.resp(correctedSpikeTimes(2:end)) = correctedSpikeAmps(2:end);
      r(ep).spikes(:) = 0;
      r(ep).spikes(r(ep).spikeData.times) = 1;
    end
  elseif epochs > 0
    correctedSpikeTimes = 0; correctedSpikeAmps = 0;
    for ii = 1:length(epochs)
      ep = epochs(ii)
      if strcmp(direction, 'up')
        if r(ep).old.spikeData.amps(1,ii) > threshold
          correctedSpikeTimes(1, end+1) = r(ep).old.spikeData.times(ii);
          correctedSpikeAmps(1, end+1) = r(ep).old.spikeData.amps(ii);
        end
      end
    end
    r(ep).spikeData.times = correctedSpikeTimes(2:end);
    r(ep).spikeData.amps = correctedSpikeAmps(2:end);
    r(ep).spikeData.resp = zeros(size(r(ep).spikes));
    r(ep).spikeData.resp(correctedSpikeTimes(2:end)) = correctedSpikeAmps(2:end);
    r(ep).spikes(:) = 0;
    r(ep).spikes(r(ep).spikeData.times) = 1;
  end
end
