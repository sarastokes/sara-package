function fh = figPos(fh, x, y)
  % fast change figure position while keeping screen position defaults
  % INPUTS:     fh    figure handle
  %             x     width
  %             y     height
  % x and y can be [], percent (any non-integer), pixels (integer)
  % SSP 20170302
  % 20170321 - fixed screen position issue

  pos = get(fh, 'Position');
  if ~isempty(x)
    if isinteger(x)
      pos(3) = x;
    else
      pos(3) = pos(3) * x;
    end
  end

  if ~isempty(y)
    if isinteger(y)
      pos(4) = y;
    else
      pos(4) = pos(4) * y;
    end
  end

  scrsz = get(0,'ScreenSize');
  if pos(2) + pos(4) > scrsz(4)-50
    pos(2) = 20;
    % pos(2) = (scrsz(4) + pos(4))/2;
  end
  if pos(1) + pos(3) > scrsz(3)-50
    % pos(1) = (scrsz(3) + pos(3))/2;
    pos(1) = 20;
  end

  set(fh, 'Position', pos);
