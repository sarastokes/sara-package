classdef AnalysisModeType
    enumeration
        AUTO
        NONE
        EXCITATION
        INHIBITION
        SUBTHRESHOLD
        SPIKES
        ANALOG
        IC_SPIKES
    end
    
    methods (Static)
        function obj = fromChar(c)
            import edu.washington.riekelab.sara.types.AnalysisModeType;
            
            switch c
                case 'Excitation'
                    obj = AnalysisModeType.EXCITATION;
                case 'Inhibition'
                    obj = AnalysisModeType.INHIBITION;
                case 'Subthreshold'
                    obj = AnalysisModeType.SUBTHRESHOLD;
                case 'Spikes'
                    obj = AnalysisModeType.SPIKES;
                case 'IC_Spikes'
                    obj = AnalysisModeType.IC_SPIKES;
                otherwise
                    obj = AnalysisModeType.INVALID;
                    fprintf('unrecognized AnalysisModeType - %c\n', c);
                    
            end
        end
        
    end
end