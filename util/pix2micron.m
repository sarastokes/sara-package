function m = pix2micron(x, objectiveMag)
  % INPUT: x = number(s) to be converted
  %         objectiveMag = 10, 60 or full data structure


  if isstruct(objectiveMag)
    micronsPerPixel = objectiveMag.params.micronsPerPixel;
  elseif isnumeric(objectiveMag)
    if objectiveMag == 60
        micronsPerPixel = 0.133;
    elseif objectiveMag == 10
        micronsPerPixel = 0.8;
    end
  end

  m = x * micronsPerPixel;
