classdef Preparation < edu.washington.riekelab.sara.sources.Preparation
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            
            obj.addAllowableParentType('edu.washington.riekelab.sara.sources.primate.Primate');
        end
        
    end
    
end

