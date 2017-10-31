classdef ChromaticityType
	enumeration
		ACHROMATIC
		LISO
		MISO
		SISO
		LMISO
		YELLOW
		RED
		GREEN
		BLUE
		CYAN
		MAGENTA
	end

	methods
		function c = char(obj)
			import edu.washington.riekelab.sara.types.ChromaticityType;
			switch obj
				case ChromaticityType.ACHROMATIC
					c = 'achromatic';
				case ChromaticityType.LISO
					c = 'l-iso';
				case ChromaticityType.MISO
					c = 'm-iso';
				case ChromaticityType.SISO
					c = 's-iso';
				case ChromaticityType.LMISO
					c = 'lm-iso';
				case ChromaticityType.YELLOW
					c = 'yellow';
				case ChromaticityType.RED
					c = 'red';
				case ChromaticityType.GREEN
					c = 'green';
				case ChromaticityType.BLUE
					c = 'blue';
				case ChromaticityType.CYAN
					c = 'cyan';
				case ChromaticityType.MAGENTA
					c = 'magenta';
			end
		end
	end

	methods (Static)
		function obj = fromChar(c)
			import edu.washington.riekelab.sara.types.ModulationType.*;
			switch lower(c)
				case 'achromatic'
					obj = ChromaticityType.ACHROMATIC;
				case {'l-iso', 'liso', 'l'}
					obj = ChromaticityType.LISO;
				case {'m-iso', 'miso', 'm'}
					obj = ChromaticityType.MISO;
				case {'s-iso', 'siso', 's'}
					obj = ChromaticityType.SISO;
				case {'lm-iso', 'lmiso'}
					obj = ChromaticityType.LMISO;
				case 'yellow'
					obj = ChromaticityType.YELLOW;
				case 'red'
					obj = ChromaticityType.RED;
				case 'green'
					obj = ChromaticityType.GREEN;
				case 'blue'
					obj = ChromaticityType.BLUE;
				case 'magenta'
					obj = ChromaticityType.MAGENTA;
				case 'cyan'
					obj = ChromaticityType.CYAN;
				otherwise
					error('Unknown chromaticity type');
            end
        end
    end

end