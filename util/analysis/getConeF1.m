function [F1, P1] = getConeF1(r, getSign,ft)
  % get relative LMS weights based on F1 amplitude and phase
  % INPUT:    r                   data structure
  % OPTIONAL: getSign   (false)   multiply F1 by phase sign
  %           ft        (1)       f1 or f2
  % OUTPUT: [F1, P1]

  if nargin < 2
    getSign = false;
  end
  if nargin < 3
    ft = 1;
  end


  r = makeCompatible(r);

  ind = strfind(r.params.stimClass, 'lms');
  ind = ind:ind+2;
  F1 = zeros(3,1);P1 = zeros(3,1);P1sign = zeros(3,1);
  for ii = 1:3
    if ft == 1
      F1(ii) = mean(r.analysis.F1(ind(ii),:),2);
      P1(ii) = mean(r.analysis.P1(ind(ii),:),2);
    else
      F1(ii) = mean(r.analysis.F2(ind(ii), :), 2);
      P1(ii) = mean(r.analysis.P2(ind(ii), :), 2);
    end
    switch r.params.recordingType
      case 'extracellular'
      P1sign(ii) = sign(P1(ii)) * -1;
      case 'analog'
      % ugh later
    end
  end
  F1 = F1 ./ sum(abs(F1));


  if getSign
    F1 = F1 .* P1sign;
  end
