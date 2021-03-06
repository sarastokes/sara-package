classdef Cell < edu.washington.riekelab.sara.sources.Cell
    
    methods
        
        function obj = Cell()
            import symphonyui.core.*;
           obj.addProperty('type', '', ...
                'type', PropertyType('char', 'row', containers.Map( ...
                    {'', 'unknown', 'RGC', 'amacrine', 'bipolar', 'horizontal', 'photoreceptor'}, ...
                    { ...
                        {}, ...
                        {}, ...
                        {'ON-midget', 'OFF-midget', 'ON-parasol', 'OFF-parasol', 'small bistratified', 'ON-smooth', 'OFF-smooth', 'melanopsin', 'ON-OFF', 'broad thorny'}, ...
                        {'AII', 'A17', 'starburst', 'A1'}, ...
                        {'OFF-diffuse', 'OFF-midget', 'ON-diffuse', 'ON-midget', 'rod'}, ...
                        {'H1', 'H2'}, ...
                        {'S cone', 'M cone', 'L cone', 'rod'} ...
                    })), ...
                'description', 'The confirmed type of the recorded cell', ...
                'isPreferred', true);            
            obj.addProperty('XLocation', '',...
                'description', 'X-axis location of cell');
            obj.addProperty('YLocation', '',...
                'description', 'Y-axis location of cell');
            
            % cone-specific properties
            obj.addProperty('center', 'unknown',...
                'type', PropertyType('char', 'row',...
                    {'unknown', 'L', 'M', 'LM', 'LS', 'MS', 'LMS'}),...
                'description', 'Center cone type(s)');
            obj.addProperty('surround', 'unknown',...
                'type', PropertyType('char', 'row',...
                    {'unknown', 'L', 'M', 'S', 'LM', 'LS', 'MS', 'LMS'}),...
                'description', 'surround cone type(s)');
            obj.addProperty('SConeInput','unknown',...
                'type', PropertyType('char', 'row',...
                    {'unknown', 'yes', 'no'}),...
                'description', 'Does the cell have s-cone input');
            obj.addProperty('centerCones', int32(0),...
                'type', PropertyType('int32', 'scalar', [0 100]),...
                'description', 'How many center cones?');
            
            obj.addAllowableParentType('edu.washington.riekelab.sara.sources.primate.Preparation');
        end
        
    end
    
end

