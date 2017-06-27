classdef RigA_AmpOne < edu.washington.riekelab.sara.rigs.RigA

	methods
		function obj = RigA_AmpOne()
			import symphonyui.builtin.daqs.*;
			import symphonyui.builtin.devices.*;
			import symphonyui.core.*;

			daq = obj.daqController;

			amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStrem('ao8')).bindStream(daq.getStream('ai0'));
			obj.addDevice(amp1);

			% get calibration resources
			% TODO: work out the function instead
			ramps = containers.Map();
			ramps('red') = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'red_gamma_ramp.txt'));
			ramps('green') = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'green_gamma_ramp.txt'));
			ramps('blue') = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'blue_gamma_ramp.txt'));
			ramps('uv') = 65535 * importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'uv_gamma_ramp.txt'));

			% add the lightcrafter
			lightCrafter = edu.washington.riekelab.sara.devices.LcrVideoDevice(...
				'micronsPerPixel', 0.1121,...
				'gammaRamps', ramps);

			% Binding the LightCrafter to an unused stream only so its configuration settings are written to each epoch
      lightCrafter.bindStream(daq.getStream('doport1'));
      daq.getStream('doport1').setBitPosition(lightCrafter, 15);

			% add the LED spectra
			lightCrafter.addResource('spectrum', containers.Map(...
				{'red', 'green', 'blue', 'uv', 'wavelength'}, {...
				importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'red_spectrum.txt')),...
				importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'green_spectrum.txt')),...
				importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'blue_spectrum.txt')),...
				importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'uv_spectrum.txt')),...
				importdata(edu.washington.riekelab.sara.Package.getCalibrationResource('rigs', 'rig_A', 'wavelength.txt'))}));

			obj.addDevice(lightCrafter);
		end % constructor
	end % methods
end % classdef
