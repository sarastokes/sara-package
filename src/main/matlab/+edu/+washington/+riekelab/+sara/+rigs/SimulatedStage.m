classdef SimulatedStage < symphonyui.core.descriptions.RigDescription

    methods

        function obj = SimulatedStage()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;

            daq = HekaSimulationDaqController();
            obj.daqController = daq;

            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);

%             % Get calibration resources.
%             ramps = containers.Map();
%             ramps('red')    = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'red_gamma_ramp.txt'));
%             ramps('green')  = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'green_gamma_ramp.txt'));
%             ramps('blue')   = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'blue_gamma_ramp.txt'));

            green = UnitConvertingDevice('Green LED', 'V').bindStream(daq.getStream('ao2'));
            green.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'0.3', '0.6', '1.2', '3.0', '4.0'}));
            green.addConfigurationSetting('gain', '', ...
                'type', PropertyType('char', 'row', {'', 'low', 'medium', 'high'}));
            obj.addDevice(green);

            blue = UnitConvertingDevice('Blue LED', 'V').bindStream(daq.getStream('ao3'));
            blue.addConfigurationSetting('ndfs', {}, ...
                'type', PropertyType('cellstr', 'row', {'0.3', '0.6', '1.2', '3.0', '4.0'}));
            blue.addConfigurationSetting('gain', '', ...
                'type', PropertyType('char', 'row', {'', 'low', 'medium', 'high'}));
            obj.addDevice(blue);

             trigger1 = UnitConvertingDevice('Trigger1', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(trigger1, 0);
            obj.addDevice(trigger1);

            trigger2 = UnitConvertingDevice('Trigger2', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(trigger2, 2);
            obj.addDevice(trigger2);

            frameMonitor = UnitConvertingDevice('Frame Monitor', 'V').bindStream(obj.daqController.getStream('ai7'));
            obj.addDevice(frameMonitor);

            microdisplay = edu.washington.riekelab.sara.devices.VideoDevice('micronsPerPixel', 0.67);
            obj.addDevice(microdisplay);

            % Add the filter wheel.
            filterWheel = edu.washington.riekelab.sara.devices.FilterWheelDevice('comPort', 'COM13');
            obj.addDevice(filterWheel);
        end
    end

end
