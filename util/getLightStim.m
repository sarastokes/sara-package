function [stimTrace, stimUnits] = getLightStim(obj, stimType)
% GETSTIMONLINE  Get stimulus trace

switch stimType
    case 'pulse'
        stimTrace = obj.lightMean * ones(1, (obj.preTime + obj.stimTime + obj.tailTime));
        if obj.lightMean > 0
            stimTrace(obj.preTime+1:obj.preTime+obj.stimTime) = obj.lightMean + ...
                (obj.contrast * obj.lightMean);
        else
            stimTrace(obj.preTime + 1: obj.preTime + obj.stimTime) = obj.contrast;
        end
    case 'modulation'
        if isproperty(obj, waitTime)
            wt = obj.waitTime;
        else
            wt = 0;
        end
        stimValues = sin(obj.temporalFrequency * (1:obj.stimTime-wt)/1000 * 2 * pi);
        if isproperty(obj, 'temporalClass') && strcmp(obj.temporalClass, 'squarewave')
            stimValues = sign(stimValues);
        end
        stimValues = obj.contrast * stimValues * obj.lightMean + obj.lightMean;
        stimTrace = [(obj.lightMean * zeros(1, obj.preTime + wt)), stimValues,...
            (obj.lightMean+zeros(1, obj.tailTime))];
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
