function [w, p, c] = setColorWeightsLocal(obj, colorCall)
  % use when there's >1 chromaticClass or to get extra info
  % also for colorweights found by ConeIsoSearch

  colorCall = lower(colorCall);

    % Cone iso options
    switch colorCall
    case {'l-iso', 'l'}
        w = obj.quantalCatch(:,1:3)' \ [1 0 0]';
        w = w / max(abs(w)); c = 'L-iso';
        p = [0.82353, 0, 0];
    case {'m-iso', 'm'}
      w = obj.quantalCatch(:,1:3)' \ [0 1 0]';
      w = w / max(abs(w)); c = 'M-iso';
      p = [0, 0.52941, 0.21569];
    case {'s-iso', 's'}
      w = obj.quantalCatch(:,1:3)' \ [0 0 1]';
      w = w / max(abs(w));  c = 'S-iso';
      p = [0.14118, 0.20784, 0.84314];
    case {'lm-iso', 'y'}
      w = obj.quantalCatch(:,1:3)' \ [1 1 0]';
      w = w / max(abs(w)); c = 'LM-iso';
      p = [0.90588, 0.43529, 0.31765];
    % no reason, just curious:
    case {'ms-iso', 'c'}
      w = obj.quantalCatch(:,1:3)' \ [0 1 1]';
      w = w / max(abs(w)); c = 'MS-iso';
      p = [0, 0.74902, 0.68627];
    case {'ls-iso', 'p'}
      w = obj.quantalCatch(:,1:3)' \ [1 0 1]';
      w = w / max(abs(w)); c = 'LS-iso';
      p = [0.64314, 0.011765, 0.43529];
    case {'lms-iso', 'lms', 'k'}
      w = obj.quantalCatch(:,1:3)'\[1 1 1]';
      w = w / max(abs(w));
      c = 'LMS-iso';
      p = [0 0 0];

    % Chromatic options
    case 'red'
      w = [1 0 0]; c = 'red';
      p = [0.82353, 0, 0];
    case 'green'
      w = [0 1 0]; c = 'green';
      p = [0, 0.52941, 0.21569];
    case 'blue'
      w = [0 0 1]; c = 'blue';
      p = [0.14118, 0.20784, 0.84314];
    case 'yellow'
      w = [1 1 0]; c = 'yellow';
      p = [0.90588, 0.43529, 0.31765];
    case 'cyan'
      w = [0 1 1]; c = 'cyan';
      p = [0, 0.74902, 0.68627];
    case 'magenta'
      w = [1 0 1]; c = 'magenta';
      p = [0.64314, 0.011765, 0.43529];

    % hue basis
    case {'sml', 'g'}
      w = obj.quantalCatch(:, 1:3)' \ [-1 1 1]';
      w = w / max(abs(w));
      p = [0.14118, 0.20784, 0.84314];
      c = 'blue (S+M)-L';
    case {'lsm', 'h'}
      w = obj.quantalCatch(:, 1:3)' \ [1 -1 -1]';
      w = w / max(abs(w));
      p = [0.90588, 0.43529, 0.31765];
      c = 'yellow L-(S+M)';
    case {'slm', 'i'}
      w = obj.quantalCatch(:, 1:3)' \ [1 -1 1]';
      w = w / max(abs(w));
      p = [0.82353, 0, 0];
      c = 'red (S+L)-M';
    case {'msl', 'j'}
      w = obj.quantalCatch(:,1:3)' \ [-1 1 -1];
      w = w / max(abs(w));
      p = [0, 0.52941, 0.21569];
      c = 'green M-(S+L)';
    case {'custom', 'x', 'customS'}
      load csiso
      fprintf('custom s-iso values loaded = %.3f, %.3f, %.3f\n', csiso);
      w = csiso;
      p = [0.14118, 0.20784, 0.84314];
      c = 'custom s-iso';
    case {'w'}
      load cmiso
      fprintf('custom s-iso values loaded = %.3f, %.3f, %.3f\n', cmiso);
        w = cmiso;
        p = [0, 0.52941, 0.21569];
        c = 'custom m-iso';
    case 'z'
      load cliso
      fprintf('custom s-iso values loaded = %.3f, %.3f, %.3f\n', cliso);
      w = cliso;
      p = [0.82353, 0, 0];
      c = 'custom l-iso';
    otherwise
      w = [1 1 1];
      p = [0 0 0];
      c = 'Achromatic';
    end
    w = w(:)';
  end
