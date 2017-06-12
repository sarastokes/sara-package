classdef (Abstract) Preparation < symphonyui.core.persistent.descriptions.SourceDescription

    methods

        function obj = Preparation()
            import symphonyui.core.*;

            obj.addProperty('time', datestr(now), ...
                'type', PropertyType('char', 'row', 'datestr'), ...
                'description', 'Time the preparation was prepared');
            obj.addProperty('region', {}, ...
                'type', PropertyType('cellstr', 'row', {'fovea', 'parafovea', 'macula', 'central', 'peripheral', 'temporal', 'nasal', 'dorsal', 'ventral'}));
            obj.addProperty('preparation', 'whole mount, RGCs up', ...
                'type', PropertyType('char', 'row', {'', 'shredded retina', 'whole mount, cones up', 'whole mount, RGCs up', 'slice'}));
            obj.addProperty('bathSolution', 'Ames', ...
                'type', PropertyType('char', 'row', {'', 'Ames', 'Ames + 14mM D-glucose'}), ...
                'description', 'The solution the preparation is bathed in');
        end

    end

end
