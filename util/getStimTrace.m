function stimTrace = getStimTrace(r, stimType, waitTime)
  % if calling from onlineAnalysis, r = obj. if calling from offline structure, r = r.params

  if nargin < 3
    if isfield(r, 'waitTime')
      waitTime = r.waitTime;
    else
      waitTime = 0;
    end
  end

  if ~isfield(r, 'contrast')
    if isfield(r, 'intensity')
      r.contrast = r.intensity;
    else
      r.contrast = 1;
    end
  end

  if strcmp(stimType, 'pulse')
    stimTrace = r.backgroundIntensity * ones(1, (r.preTime + r.stimTime + r.tailTime));
    if r.backgroundIntensity > 0
      stimTrace(r.preTime+1:r.preTime + r.stimTime) = r.backgroundIntensity + (r.contrast*r.backgroundIntensity);
    else
      stimTrace(r.preTime+1:r.preTime + r.stimTime) = r.contrast;
    end

  elseif strcmp(stimType, 'modulation')
    x = 0:0.001:((r.stimTime - waitTime - 1) * 1e-3);
    stimValues = zeros(1, length(x));
    for ii = 1:length(x)
      if isfield(r, 'temporalClass')
        if strcmp(r.temporalClass, 'sinewave')
          stimValues(1,ii) = r.contrast * sin(r.temporalFrequency * x(ii) * 2 * pi) * r.backgroundIntensity + r.backgroundIntensity;
        elseif strcmp(r.temporalClass, 'squarewave')
          stimValues(1,ii) = r.contrast * sign(sin(r.temporalFrequency * x(ii) * 2 * pi)) * r.backgroundIntensity + r.backgroundIntensity;
        end
      else
        stimValues(1,ii) = r.contrast * sign(sin(r.temporalFrequency * x(ii) * 2 * pi)) * r.backgroundIntensity + r.backgroundIntensity;
      end
    end

    if waitTime ~= 0
      stimTrace = [(r.backgroundIntensity*ones(1,r.preTime)) (stimValues(1) * ones(1, r.waitTime)) stimValues r.backgroundIntensity*ones(1, r.tailTime)];
    else
      stimTrace = [(r.backgroundIntensity * ones(1, r.preTime)) stimValues (r.backgroundIntensity * ones(1, r.tailTime))];
    end
  end
