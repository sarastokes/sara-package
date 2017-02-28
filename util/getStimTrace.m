function stimTrace = getStimTrace(r, stimType, varargin)
  % if calling from onlineAnalysis, r = obj. if calling from offline structure, r = r.params

  ip=inputParser();
  ip.addParameter('coneContrast', 1, @(x)isvector(x));
  ip.parse(varargin{:});
  coneContrast = ip.Results.coneContrast;

  if ~isfield(r, 'stimTime') && isfield(r, 'params')
      r = r.params;
  end
  if ~isfield(r, 'waitTime')
      waitTime = 0;
  else
      waitTime = r.waitTime;
  end

  if ~isfield(r, 'contrast')
    if isfield(r, 'intensity')
      c = r.intensity;
    else
      c = 1;
    end
  else
    c = r.contrast;
  end
  c = c*coneContrast;

  if strcmp(stimType, 'pulse')
    stimTrace = r.backgroundIntensity * ones(1, (r.preTime + r.stimTime + r.tailTime));
    if r.backgroundIntensity > 0
      stimTrace(r.preTime+1:r.preTime + r.stimTime) = r.backgroundIntensity + (r.contrast*r.backgroundIntensity);
    else
      stimTrace(r.preTime+1:r.preTime + r.stimTime) = c;
    end

  elseif strcmp(stimType, 'modulation')
    % numCycles = (r.stimTime - waitTime) * r.temporalFrequency / 1000;
    stimValues = sin(r.temporalFrequency * (1:r.stimTime)/1000 * 2 * pi);
    if strcmp(r.temporalClass, 'squarewave')
      stimValues = sign(stimValues);
    end
    stimValues = c * stimValues * r.backgroundIntensity + r.backgroundIntensity;
    stimTrace = [0.5+zeros(1, r.preTime + waitTime) stimValues 0.5+zeros(1, r.tailTime)];
  end
