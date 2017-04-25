function [a,b] = splitDual(a)

  b = a;
  b.spikes = b.secondary.spikes;
  b.spikeData = b.secondary.spikeData;
  b = rmfield(b, 'secondary');
  a = rmfield(a, 'secondary');

  a.cellName = [a.cellName 'a'];
  b.cellName = [b.cellName 'b'];
