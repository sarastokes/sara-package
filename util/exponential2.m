function y = exponential2(t, rise, decay)
%   EXPONENTIAL2 Double exponential fcn
%
%   INPUTS:
%       t           time vector
%       rise        tau rise
%       decay       tau decay
%
% Jul2017 - SSP
 
    y = ((rise*decay)/(rise - decay)) * (exp(-t/decay)-exp(-t/decay));
