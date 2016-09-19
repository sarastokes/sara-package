function res = getPSTH(r, spikeTrials ,binSize)
  %For online analysis
  %spikeTrials is a n * d matrix of cell-attached spike recordings
  %    where d=number data points per trial and n is number trials
  %binsize (in data points)
  % binaryFlag = 1 for input that is a binary string of spike times
  % MHT 080814
%  [n, ~]=size(spikes);
%  n
%  for nn = 1:n
%    spikeTrials(nn,:) = spikes(nn, r.params.preTime/1000 * r.params.sampleRate+1 : (r.params.preTime/1000 + r.params.stimTime/1000) * r.params.sampleRate + 1);
%  end
  [n, d]=size(spikeTrials);


  noBins=floor(d/binSize);
  binCenters=binSize/2:binSize:noBins*binSize-binSize/2;
  binSpikes=zeros(n,noBins);
  for j=1:n %for trials
      for i=1:noBins %for bins
          binSpikes(j,i)=sum(spikeTrials(j,(i-1)*binSize+1:i*binSize));
      end
  end
  spikeSTD=std(binSpikes,1);
  spikeSEM=spikeSTD./sqrt(n);

  binSpikes=mean(binSpikes,1); %average over trials


  res.binCenters = binCenters; %data points
  res.spikeCounts = binSpikes; %mean per bin
  res.spikeSEM = spikeSEM; %sem per bin
  res.spikeSTD = spikeSTD;

end
