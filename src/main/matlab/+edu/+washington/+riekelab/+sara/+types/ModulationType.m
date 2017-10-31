classdef ModulationType

	enumeration
		SINEWAVE
		SQUAREWAVE
		PULSE_POSITIVE
		PULSE_NEGATIVE
	end

	methods
		function c = char(obj)
			import edu.washington.riekelab.sara.types.ModulationType.*;

			switch obj
				case ModulationType.SINEWAVE
					c = 'sinewave';
				case ModulationType.SQUAREWAVE
					c = 'squarewave';
				case ModulationType.PULSE_NEGATIVE
					c = 'pulse_negative';
				case ModulationType.PULSE_POSITIVE
					c = 'pulse_positive';
			end
		end
	end

	methods (Static)
		function obj = fromChar(c)
			import edu.washington.riekelab.sara.types.ModulationType.*;
			switch c
				case 'sinewave'
					obj = ModulationType.SINEWAVE;
				case 'squarewave'
					obj = ModulationType.SQUAREWAVE;
				case 'pulse_positive'
					obj = ModulationType.PULSE_POSITIVE;
				case 'pulse_negative'
					obj = ModulationType.PULSE_NEGATIVE;
				otherwise
					error('Unknown ModulationType');
			end
		end
	end
end