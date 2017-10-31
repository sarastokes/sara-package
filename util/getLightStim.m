function [stimTrace, stimUnits] = getLightStim(obj, stimType)
% GETSTIMONLINE  Get stimulus trace
if isprop(obj, 'contrasts')
    stimWeight = 1;
elseif ~isprop(obj, 'contrast')
    stimWeight = 1;
elseif numel(obj.contrast)>1 % contrast param exists
    stimWeight = 1;
else 
    stimWeight = sign(obj.contrast);
end

switch stimType
    case 'pulse'
        stimTrace = obj.lightMean * ones(1, (obj.preTime + obj.stimTime + obj.tailTime));
        if obj.lightMean > 0
            stimTrace(1, obj.preTime+1:obj.preTime+obj.stimTime) =...
                (stimWeight * obj.lightMean) + obj.lightMean;
        else
            stimTrace(obj.preTime + 1: obj.preTime + obj.stimTime) = stimWeight;
        end
    case 'modulation'
        if isprop(obj, 'waitTime')
            wt = obj.waitTime;
        else
            wt = 0;
        end
        stimValues = sin(obj.temporalFrequency * (1:obj.stimTime-wt)/1000 * 2 * pi);
        if isprop(obj, 'temporalClass') && strcmp(lower(obj.temporalClass), 'squarewave')
            stimValues = sign(stimValues);
        end
        stimValues = stimWeight * stimValues * obj.lightMean + obj.lightMean;
        stimTrace = [(obj.lightMean + zeros(1, obj.preTime + wt)), stimValues,...
            (obj.lightMean+zeros(1, obj.tailTime))];
    case 'baseline'
        stimTrace = obj.lightMean * ones(1, obj.preTime + obj.stimTime + obj.tailTime);
    otherwise
        stimTrace = zeros(1, obj.preTime + obj.stimTime + obj.tailTime);
end

if nargout > 1
    if obj.lightMean > 0
        stimUnits = 'contrast';
    else
        stimUnits = 'intensity';
    end
end
