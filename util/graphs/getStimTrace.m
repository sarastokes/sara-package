function stimTrace = getStimTrace(r)

  if strcmp(r.protocol, 'edu.washington.riekelab.manookin.protocols.ChromaticSpot')
    stimTrace = r.backgroundIntensity * ones(1, (r.preTime + r.stimTime + r.tailTime));
    if r.backgroundIntensity > 0
      stimTrace(r.preTime+1:r.preTime + r.stimTime) = r.backgroundIntensity + (r.contrast*r.backgroundIntensity);
    else
      stimTrace(r.preTime+1:r.preTime + r.stimTime) = r.contrast;
    end
  else
    x = 0:0.001:((r.params.stimTime - 1) * 1e-3);
    stimValues = zeros(1, length(x));
    for ii = 1:length(x)
      if strcmp(r.params.temporalClass, 'sinewave')
        stimValues(1,ii) = r.params.contrast * sin(r.params.temporalFrequency * x(ii) * 2 * pi) * r.params.backgroundIntensity + r.params.backgroundIntensity;
      elseif strcmp(r.params.temporalClass, 'squarewave')
        stimValues(1,ii) = r.params.contrast * sign(sin(r.params.temporalFrequency * x(ii) * 2 * pi)) * r.params.backgroundIntensity + r.params.backgroundIntensity;
      end
    end

    stimTrace = [(r.params.backgroundIntensity * ones(1, r.params.preTime)) stimValues (r.params.backgroundIntensity * ones(1, r.params.tailTime))];
  end
