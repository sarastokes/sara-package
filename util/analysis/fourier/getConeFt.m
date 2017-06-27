function cw = getConeFt(r)

  if ~isfield(r, 'instFt')
    r.instFt = getInstFt(r.spikes);
    r.instFt = reshape(r.instFt, length(r.stimClass), r.numEpochs/length(r.stimClass), )
  end

  prePts = r.params.preTime * 1e-3 * r.params.sampleRate;
  stimPts = r.params.stimTime * 1e-3 * r.params.sampleRate;

  cw = mean(squeeze(sum(r.instFt(:,:,prePts:prePts+stimPts))),2);
