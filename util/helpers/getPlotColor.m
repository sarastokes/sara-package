function [p, c] = getPlotColor(colorCall, fac)
  % optional: fac = lighten plot color by factor (usually 0.5 or 0.6)
  % negative fac will be 1-fac (unless -1, that just stays at 1): for
  % contrast parameter inputs

    if nargin < 2
      fac = 1;
    end
    if fac == -1
        fac = 1;
    elseif fac < 0
        fac = 1+fac;
    end

    % Cone iso options
    if strcmp(colorCall, 'L-iso') || strcmp(colorCall, 'l')
      c = 'L-iso';
      p = [0.82353, 0, 0];
    elseif strcmp(colorCall, 'M-iso') || strcmp(colorCall, 'm')
      c = 'M-iso';
      p = [0, 0.52941, 0.21569];
    elseif strcmp(colorCall, 'S-iso') || strcmp(colorCall, 's')
      c = 'S-iso';
      p = [0.14118, 0.20784, 0.84314];
    elseif strcmp(colorCall, 'LM-iso') || strcmp(colorCall, 'y')
      c = 'LM-iso';
      p = [0.90588, 0.43529, 0.31765];
    elseif strcmp(colorCall, 'MS-iso') || strcmp(colorCall, 'c')
      c = 'MS-iso';
      p = [0, 0.74902, 0.68627];
    elseif strcmp(colorCall, 'LS-iso') || strcmp(colorCall, 'p')
      c = 'LS-iso';
      p = [0.64314, 0.011765, 0.43529];
    elseif strcmp(colorCall, 'LMS-iso') || strcmp(colorCall, 'lms')
      c = 'LMS-iso';
      p = [0 0 0];

    % Chromatic options
  elseif strcmp(colorCall, 'red') || strcmp(colorCall, 'R')
      p = [0.82353, 0, 0]; c = 'red';
    elseif strcmp(colorCall, 'green') || strcmp(colorCall, 'G')
      p = [0, 0.52941, 0.21569]; c = 'green';
    elseif strcmp(colorCall, 'blue') || strcmp(colorCall, 'B')
      p = [0.14118, 0.20784, 0.84314]; c = 'blue';
    elseif strcmp(colorCall, 'yellow')
      p = [1, 0.83, 0.11]; c = 'yellow';
    elseif strcmp(colorCall, 'cyan')
      p = [0, 0.74902, 0.68627]; c = 'cyan';
    elseif strcmp(colorCall, 'magenta')
      p = [0.64314, 0.011765, 0.43529]; c = 'magenta';

    % hue basis
    elseif strcmp(colorCall, 'sml')
      p = [0.14118, 0.20784, 0.84314];
      c = 'blue (S+M)-L';
    elseif strcmp(colorCall, 'lsm')
      p = [0.90588, 0.43529, 0.31765];
      c = 'yellow L-(S+M)';
    elseif strcmp(colorCall, 'slm')
      p = [0.82353, 0, 0];
      c = 'red (S+L)-M';
    elseif strcmp(colorCall, 'msl')
      p = [0, 0.52941, 0.21569];
      c = 'green M-(S+L)';
    else
      p = [0 0 0];
      c = 'Achromatic';
    end

    if length(fac) ~= 1
      p = [p; p+(fac(2)*(1-p))];
    elseif fac ~= 1
      p = p + (fac * (1-p));
    end

 end
