function pts = ms2pts(ms, sampleRate)
    % MS2PTS  Convinient conversion from milliseconds to data points
    % 
    % 22Oct2017 - SSP
    
    if nargin == 1
        sampleRate = 1e4;
    end
    pts = ms/1e3*sampleRate;