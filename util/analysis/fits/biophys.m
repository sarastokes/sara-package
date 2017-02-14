  function r = biophys(r, response, pulseAmp)
    % response can be a response block or the mean

    prePts = round(r.params.preTime * 1e-3 * r.params.sampleRate);
    stimStart = prePts + 1;
    stimEnd = round((r.params.preTime + r.params.stimTime) * 1e-3 * r.params.sampleRate);

    data = mean(response);
    % Calculate baseline current before step.
    baseline = mean(data(1:prePts));
    
    % curve fit the transient with a single exponential
    [~, peakPt] = max(data(stimStart:stimEnd));

    % set up fit
    fitStartPt = stimStart + peakPt + 1;
    fitEndPt = stimEnd;

    sampleInterval = 1/r.params.sampleRate * 1e3; % ms

    fitTime = (fitStartPt:fitEndPt) * sampleInterval;
    fitData = data(fitStartPt:fitEndPt);
    % to rows
    fitTime = fitTime(:)';
    fitData = fitData(:)';

    % initial guesses for a, b, c
    p0 = [max(fitData) - min(fitData), (max(fitTime) - min(fitTime)) / 2, mean(fitData)];

    % define the fit function
    fitFunc = @(a,b,c,x) a*exp(-x/b)+c;

    curve = fit(fitTime', fitData', fitFunc, 'StartPoint', p0);

    r.tauCharge = curve.b;
    r.currentSS = curve.c;

    % extrapolate single exponential back to where the step started to calculate the series resistance
    r.current0 = curve(stimStart * sampleInterval) - baseline;
    r.rSeries = (0.005 / (r.current0 * 1e-12)) / 1e6;

    % calculate charge, capacitance, input resistance
    subtractStartPt = stimStart;
    subtractEndPt = stimEnd;

    subtractStartTime = subtractStartPt * sampleInterval;
    subtractTime = (subtractStartPt:subtractEndPt) * sampleInterval;
    subtractData = baseline + (r.currentSS - baseline) * (1 - exp(-(subtractTime-subtractStartTime) / r.tauCharge));

    r.charge = trapz(subtractTime, data(subtractStartPt:subtractEndPt)) - trapz(subtractTime, subtractData);
    r.capacitance = r.charge / pulseAmp;
    r.rInput = (pulseAmp * 1e-3) / ((r.currentSS - baseline) * 1e-12) / 1e6;
