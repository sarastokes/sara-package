function res = getPSTHOnline(spikeTrials, binSize, temporalFrequency)
  %For online analysis
  %spikeTrials is a n * d matrix of cell-attached spike recordings
  %    where d=number data points per trial and n is number trials
  %binsize (in data points)
  % binaryFlag = 1 for input that is a binary string of spike times
  % MHT 080814

  % took out binary flag, added option to find cycleData for chromaticGrating, coneSweep...
  % SSP 082615

  if nargin == 1
    binSize = 200;
    temporalFrequency = 0;
  elseif nagrin == 2
    temporalFreqency = 0;
  end

  [n d]=size(spikeTrials);

  noBins=floor(d/binSize);
  binCenters=binSize/2:binSize:noBins*binSize-binSize/2;
  binSpikes=zeros(n,noBins);
  for j=1:n %for trials
      for i=1:noBins %for bins
          binSpikes(j,i)=sum(spikeTrials(j,(i-1)*binSize+1:i*binSize));
      end
  end

  if temporalFrequency ~= 0
    binsPerCycle = noBins / (temporalFrequency*10);
    numCycles = floor(length(binSpikes)/binsPerCycle);
    cycleData = zeros(n, floor(binsPerCycle));
    for j = 1:n
      for k = 1:numCycles
        index = round((k-1)*binsPerCycle) + (1 : floor(binsPerCycle));
        cycleData(j,:) = binSpikes(j,index);
      end
    end
  end

  spikeSTD=std(binSpikes,1);
  spikeSEM=spikeSTD./sqrt(n);

  binSpikes=mean(binSpikes,1); %average over trials


  res.binCenters = binCenters; %data points
  res.spikeCounts = binSpikes; %mean per bin
  res.spikeSEM = spikeSEM; %sem per bin
  res.spikeSTD = spikeSTD;

  res.cycleData = cycleData;
  res.cycleMean = mean(cycleData,1);
  res.cycleSEM = sem(cycleData);
  res.cycleSTD = std(cycleData, 1);
end
