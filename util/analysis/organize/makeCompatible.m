function r = makeCompatible(r, src)
  % keep up with all the random improvements to data workflow
  % to be called by other functions
  % INPUT: r  data structure
  % OPT:   src    true if calling from analyzeOnline
  %
  % 28Jan2017 - created to go with analysis code 2.0
  % 13Feb2017 - ColorExchange and IsoSTA protocol changes
  % previous major changes:
  %   5Oct2016 - 2nd neuron option
  %   11Nov2016 - added recordingType and analysisType
  %   5Dec2016 - added log

  if nargin < 2
    src = false;
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
      if src
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

  if ~isempty(strfind(r.protocol, 'GaussianNoise')) || ~isempty(strfind(r.protocol, 'IsoSTA'))
      if ~isfield(r.params, 'frameDwell')
          r.params.frameDwell = 1;
      end
  end

  if ~isfield(r.params, 'analysisType')
    if isfield(r, 'secondary')
      if neuron == 1
        r.params.analysisType = 'dual_c1';
      else
        r.params.analysisType = 'dual_c2';
      end
    else
      r.params.analysisType = 'single';
    end
    % not sure how to extract paired recordings at this stage
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
  end
