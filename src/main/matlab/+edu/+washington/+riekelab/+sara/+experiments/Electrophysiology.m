classdef ConeElectrophysiology < symphonyui.core.persistent.descriptions.ExperimentDescription

    methods

        function obj = ConeElectrophysiology()
            import symphonyui.core.*;

            obj.addProperty('experimenter', '', ...
                'description', 'Who performed the experiment');
            obj.addProperty('project', '', ...
                'description', 'Project the experiment belongs to');
            obj.addProperty('institution', 'UW', ...
                'description', 'Institution where the experiment was performed');
            obj.addProperty('lab', 'Manookin Lab', ...
                'description', 'Lab where experiment was performed');
            obj.addProperty('rig', 'A (manookin1)', ...
                'type', PropertyType('char', 'row', {'', 'A (manookin1)', 'B (two photon)', 'C (suction)', 'E (confocal)', 'F (old slice)', 'G (shared two photon)'}), ...
                'description', 'Rig where experiment was performed');

            % calibration settings
            obj.addPropertyType('ledRed', 54,...
                'description', 'red led setting');
            obj.addPropertyType('ledGreen', 17,...
                'description', 'green led setting');
            obj.addPropertyType('ledBlue', 55,...
                'description', 'blue led setting');
            obj.addPropertyType('radiometerDark', '',...
                'description', 'dark calibration');
            obj.addPropertyType('radiometerRed', '',...
                'description', 'Red LED calibration');
            obj.addPropertyType('radiometerGreen', '',...
                'description', 'Green LED calibration');
            obj.addPropertyType('radiometerBlue', '',...
                'description', 'Blue LED calibration');
            obj.addPropertyType('radiometerDate', datestr(now, 'ddmmmyyyy'),...
                'description', 'Date of radiometer calibration');
            obj.addPropertyType('gammaData', datestr('03Apr2017'),...
                'description', 'Date of last gamma calibration');
            obj.addPropertyType('spectraDate', '03Apr2017',...
                'description', 'Date of last spectra measurement');
        end
    end
end