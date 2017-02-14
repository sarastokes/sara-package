function tx = getNiceLabels(cones)
  % make good graph labels (liso vs L-iso)
  % INPUT: cones (string or cellstring)

  tx = cones;
  for ii = 1:length(cones)
    cone = cones{ii};
    switch cone
      case {'liso', 'l'}
        tx{ii} = 'L-iso';
      case {'miso', 'm'}
        tx{ii} = 'M-iso';
      case {'siso', 's'}
        tx{ii} = 'S-iso';
      case {'lmiso', 'lm'}
        tx{ii} = 'LM-iso';
      case {'lmsiso', 'lms'}
        tx{ii} = 'LMS-iso';
      case {'lsiso', 'ls'}
        tx{ii} = 'LS-iso';
      case {'msiso', 'ms'}
        tx{ii} = 'MS-iso';
      case {'a'}
        tx{ii} = 'Achrom';
    end
  end
