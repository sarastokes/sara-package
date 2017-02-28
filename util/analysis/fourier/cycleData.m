function cdata = cycleData(r, varargin)
  % break up data and return ready to graph
  % INPUT:  r = data structure
  %         fac (15) = ptsh filter msec
  %         avg (true) = return avg instead of all
  %         cycleOne (2) = which cycle to start on
  %         numCycles (1) = how many cycles per data row
  % OUTPUT: cdata = data structure w/ ypts, xpts, stim, stats
  %
  %


  ip = inputParser();
  ip.addParameter('numCycles', 1, @(x)isvector(x));
  ip.addParameter('fac',15, @(x)isvector(x));
  ip.addParameter('avg', true, @(x)islogical(x));
  ip.addParameter('cycleOne', 2, @(x)isvector(x));
  ip.addParameter('epochs', [], @(x)isvector(x));

  ip.parse(varargin{:});
  numCycles = ip.Results.numCycles;
  fac = ip.Results.fac;
  avg = ip.Results.avg;
  cycleOne = ip.Results.cycleOne;
  epochList = ip.Results.epochs;

  if isempty(epochList)
    epochList = 1:r.numEpochs;
  end

  if ~isfield(r.params, 'waitTime')
    r.params.waitTime = 0;
  end


  for ii = 1:length(epochList)
    ep = epochList(ii);
    % slightly modified from max's cycle avg figure
    if strcmp(r.params.recordingType,'extracellular')
        filterSigma = (fac/1000)*r.params.sampleRate; % fac msec -> dataPts
        newFilt = normpdf(1:10*filterSigma,10*filterSigma/2,filterSigma);
        y = r.spikes(ep, :);
        y = r.params.sampleRate*conv(y,newFilt,'same'); %inst firing rate, Hz
    else
        y = r.analog(ep,:);
    end

    noCycles = floor(numCycles * r.params.temporalFrequency * (r.params.stimTime - r.params.waitTime) / 1000);
    period = numCycles * (1/r.params.temporalFrequency) * r.params.sampleRate;
    y(1:(r.params.sampleRate * (r.params.preTime + r.params.waitTime) / 1000))=[];
    epochResp = [];
    for c = cycleOne:noCycles
    	epochResp = [epochResp; y((c-1)*period+1:c*period)];
    end
    if ii == 1
        cdata.ypts = zeros(length(epochList), size(epochResp,1), size(epochResp,2));
        cdata.xpts = (1:length(epochResp))./r.params.sampleRate;
    end
    cdata.ypts(ii,:,:) = epochResp;
  end

  % get the stim
  cdata.stim = sin(r.params.temporalFrequency * cdata.xpts * 2 * pi);

  % get some info
  if strcmp(r.params.recordingType, 'voltage_clamp')
      cdata.stats.pk = zeros(length(epochList), size(cdata.ypts,2), 2);
      for ii = 1:length(epochList)
          for jj = 1:size(cdata.ypts,2)
            [pkInd, pk] = peakfinder(squeeze(cdata.ypts(ii,jj,:)),[],[],sign(r.holding));
            if sign(r.holding) == 1
              [pk,indind]=max(pk);
            else
              [pk,indind]=min(pk);
            end
            % [peak time, peak value]
            cdata.stats.pk(ii,jj,:) = [cdata.xpts(pkInd(indind)), pk];
          end
      end
      if avg
        cdata.stats.pk = squeeze(mean(cdata.stats.pk,2));
      end
      if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ConeSweep')
        cdata.stats.pk = reshape(cdata.stats.pk, [length(r.params.stimClass) ceil(r.numEpochs/length(r.params.stimClass)) 2]);
        if avg
          cdata.stats.pk = squeeze(mean(cdata.stats.pk,2));
        end
      end
  end
  % get the average
  if avg
    cdata.ypts = squeeze(mean(cdata.ypts,2));
  end
  if strcmp(r.protocol, 'edu.washington.riekelab.sara.protocols.ConeSweep')
    if avg
      cdata.ypts = reshape(cdata.ypts, [length(r.params.stimClass) ceil(r.numEpochs/length(r.params.stimClass)) size(cdata.ypts,2) size(cdata.ypts,3)]);
    else
      cdata.ypts = reshape(cdata.ypts, [length(r.params.stimClass) ceil(r.numEpochs/r.params.stimClass) size(cdata.ypts,2)]);
    end
  end
