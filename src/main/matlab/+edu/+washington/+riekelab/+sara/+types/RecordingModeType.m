classdef RecordingModeType 
	enumeration
		EXTRACELLULAR
		VOLTAGE_CLAMP
		CURRENT_CLAMP
		LOCAL_FIELD
		OPTICAL
	end

	methods
		function c = char(obj)
			import edu.washington.riekelab.sara.types.RecordingModeType;
			switch obj
				case RecordingModeType.EXTRACELLULAR
					c = 'extracellular';
				case RecordingModeType.VOLTAGE_CLAMP
					c = 'voltage_clamp';
				case RecordingModeType.CURRENT_CLAMP
					c = 'current_clamp';
				case RecordingModeType.LOCAL_FIELD
					c = 'local_field';
				case RecordingModeType.OPTICAL
					c = 'optical';
				otherwise
					c = 'unknown';
			end
		end
	end

	methods (Static)
		function obj = fromChar(c)
			import edu.washington.riekelab.sara.types.RecordingModeType;
			switch c
				case 'extracellular'
					obj = RecordingModeType.EXTRACELLULAR;
				case 'voltage_clamp'
					obj = RecordingModeType.VOLTAGE_CLAMP;
				case 'current_clamp'
					obj = RecordingModeType.CURRENT_CLAMP;
				case 'local_field'
					obj = RecordingModeType.LOCAL_FIELD;
				case 'optical'
					obj = RecordingModeType.OPTICAL;
				otherwise
					error('Unknown recording mode type');
			end
		end
	end
end
