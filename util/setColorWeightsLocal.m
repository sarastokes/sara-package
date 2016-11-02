function [w, p, c] = setColorWeightsLocal(obj, colorCall)
  % use when there's >1 chromaticClass or to get extra info
  % also for colorweights found by ConeIsoSearch

    % Cone iso options
    if strcmp(colorCall, 'L-iso') || strcmp(colorCall, 'l')
        w = obj.quantalCatch(:,1:3)' \ [1 0 0]';
        w = w / max(abs(w)); c = 'L-iso';
        p = [0.82353, 0, 0];
    elseif strcmp(colorCall, 'M-iso') || strcmp(colorCall, 'm')
      w = obj.quantalCatch(:,1:3)' \ [0 1 0]';
      w = w / max(abs(w)); c = 'M-iso';
      p = [0, 0.52941, 0.21569];
    elseif strcmp(colorCall, 'S-iso') || strcmp(colorCall, 's')
      w = obj.quantalCatch(:,1:3)' \ [0 0 1]';
      w = w / max(abs(w));  c = 'S-iso';
      p = [0.14118, 0.20784, 0.84314];
    elseif strcmp(colorCall, 'LM-iso') || strcmp(colorCall, 'y')
      w = obj.quantalCatch(:,1:3)' \ [1 1 0]';
      w = w / max(abs(w)); c = 'LM-iso';
      p = [0.90588, 0.43529, 0.31765];
    % no reason, just curious:
    elseif strcmp(colorCall, 'MS-iso') || strcmp(colorCall, 'c')
      w = obj.quantalCatch(:,1:3)' \ [0 1 1]';
      w = w / max(abs(w)); c = 'MS-iso';
      p = [0, 0.74902, 0.68627];
    elseif strcmp(colorCall, 'LS-iso') || strcmp(colorCall, 'p')
      w = obj.quantalCatch(:,1:3)' \ [1 0 1]';
      w = w / max(abs(w)); c = 'LS-iso';
      p = [0.64314, 0.011765, 0.43529];

    % Chromatic options
    elseif strcmp(colorCall, 'red')
      w = [1 0 0]; c = 'red';
      p = [0.82353, 0, 0];
    elseif strcmp(colorCall, 'green')
      w = [0 1 0]; c = 'green';
      p = [0, 0.52941, 0.21569];
    elseif strcmp(colorCall, 'blue')
      w = [0 0 1]; c = 'blue';
      p = [0.14118, 0.20784, 0.84314];
    elseif strcmp(colorCall, 'yellow')
      w = [1 1 0]; c = 'yellow';
      p = [0.90588, 0.43529, 0.31765];
    elseif strcmp(colorCall, 'cyan')
      w = [0 1 1]; c = 'cyan';
      p = [0, 0.74902, 0.68627];
    elseif strcmp(colorCall, 'magenta')
      w = [1 0 1]; c = 'magenta';
      p = [0.64314, 0.011765, 0.43529];

    % hue basis
    elseif strcmp(colorCall, 'sml')
      w = obj.quantalCatch(:, 1:3)' \ [-1 1 1]';
      w = w / max(abs(w));
      p = [0.14118, 0.20784, 0.84314];
      c = 'blue (S+M)-L';
    elseif strcmp(colorCall, 'lsm')
      w = obj.quantalCatch(:, 1:3)' \ [1 -1 -1]';
      w = w / max(abs(w));
      p = [0.90588, 0.43529, 0.31765];
      c = 'yellow L-(S+M)';
    elseif strcmp(colorCall, 'slm')
      w = obj.quantalCatch(:, 1:3)' \ [1 -1 1]';
      w = w / max(abs(w));
      p = [0.82353, 0, 0];
      c = 'red (S+L)-M';
    elseif strcmp(colorCall, 'msl')
      w = obj.quantalCatch(:,1:3)' \ [-1 1 -1];
      w = w / max(abs(w));
      p = [0, 0.52941, 0.21569];
      c = 'green M-(S+L)';
    elseif strcmp(colorCall, 'custom')
      w = [0 0 0];
      p = [0 0 1];
      c = 'custom s-iso';
    else
      w = [1 1 1];
      p = [0 0 0];
      c = 'Achromatic';
    end
    w = w(:)';
  end
