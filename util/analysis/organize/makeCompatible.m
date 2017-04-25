function r = makeCompatible(r, ao)
  % keep up with all the random improvements to data workflow
  % to be called by other functions
  % INPUT: r  data structure
  % OPT:   src    true if calling from analyzeOnline
  %
  % previous major changes:
  %   5Oct2016 - 2nd neuron option
  %   11Nov2016 - added recordingType and analysisType
  %   5Dec2016 - added log
  %
  %
  % 28Jan2017 - created to go with analysis code 2.0
  % 13Feb2017 - ColorExchange and IsoSTA protocol changes
  % 23Feb2017 - some current clamp stuff and old grating analysis

  if nargin < 2
    ao = false;
  end

  if ~isfield(r, 'log')
    r.log{1} = 'parsed before 10Dec2016 log update';
    if isfield(r, 'startTimes')
      r.log{2} = ['recorded at ' r.startTimes{1}];
    end
    fprintf('created log\n');
  end

  if ~isfield(r.params, 'recordingType')
    r.params.recordingType = 'extracellular';
    fprintf('recording type set to %s\n', r.params.recordingType);
  end

  if isfield(r, 'analysis')
    if isfield(r.analysis, 'nonlinearity')
      r.analysis.NL = r.analysis.nonlinearity;
      r.analysis = rmfield(r.analysis, 'nonlinearity');
    end
    if isfield(r.analysis, 'f1amp')
      if ao
        r.analysis.F1 = r.analysis.f1amp;
        r.analysis.P1 = r.analysis.f1phase;
        r.analysis = rmfield(r.analysis, 'f1amp');
        r.analysis = rmfield(r.analysis, 'f1phase');
      else
        r = analyzeOnline(r);
      end
    end
    if isfield(r.analysis, 'f2amp') && isfield(r.analysis, 'F2')
      r.analysis = rmfield(r.analysis, 'f2amp');
      r.analysis = rmfield(r.analysis, 'f2phase');
    end
  end

  if ~isfield(r.params, 'analysisType')
    switch r.params.recordingType
    case 'extracellular'
      r.params.analysisType = 'single';
    case 'current_clamp'
      r.params.analysisType = 'spikes&subthresh';
    case 'voltage_clamp'
      % TODO: improve
      r.params.analysisType = 'exc';
    end
  end

  if isfield(r, 'ICspikes')
    r.spikes = r.ICspikes;
    r = rmfield(r, 'ICspikes');
  end
  if isfield(r, 'subthresh')
    r.analog = r.subthresh;
    r = rmfield(r, 'subthresh');
  end

  switch r.protocol
  case 'edu.washington.riekelab.sara.protocols.IsoSTC'
    if strcmp(r.params.paradigmClass, 'STA')
      r.protocol = 'edu.washington.riekelab.sara.protocols.IsoSTA';
    end
  case 'edu.washington.riekelab.sara.protocols.TempSpatialNoise'
    r.protocol = 'edu.washington.riekelab.sara.protocols.SpatialReceptiveField';
  case 'edu.washington.riekelab.sara.protocols.CompareCones'
    r.protocol = 'edu.washington.riekelab.sara.protocols.ColorExchange';
  case 'edu.washington.riekelab.manookin.protocols.ChromaticGrating'
    if isfield(r.params, 'spatialFreqs')
      r.params.spatialFrequencies = r.params.spatialFreqs;
      r.params = rmfield(r.params, 'spatialFreqs')
    end
  case 'edu.washington.riekelab.sara.protocols.ColorCircle'
    if isfield(r.params, 'orientation')
      r.params.orientations = r.params.orientation;
      r.params = rmfield(r.params, 'orientation');
    end
  end

  if ~isempty(strfind(r.protocol, 'GaussianNoise')) || ~isempty(strfind(r.protocol, 'IsoSTA'))
      if ~isfield(r.params, 'frameDwell')
          r.params.frameDwell = 1;
      end
  end
