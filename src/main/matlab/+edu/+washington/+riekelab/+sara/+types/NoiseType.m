classdef NoiseType

	enumeration
		BINARY
		GAUSSIAN
		TERNARY
	end

	methods
		function c = char(obj)
			import edu.washington.riekelab.sara.types.NoiseType.*;
			
			switch obj
				case NoiseType.BINARY
					c = 'binary';
				case NoiseType.GAUSSIAN
					c = 'gaussian';
				case NoiseType.TERNARY
					c = 'ternary';
			end				
		end
	end

	methods (Static)
		function obj = fromChar(c)
			import edu.washington.riekelab.sara.types.NoiseType.*;
			switch c
				case 'binary'
					obj = NoiseType.BINARY;
				case 'gaussian'
					obj = NoiseType.GAUSSIAN;
				case 'ternary'
					obj = NoiseType.TERNARY;
			end
		end
	end
end