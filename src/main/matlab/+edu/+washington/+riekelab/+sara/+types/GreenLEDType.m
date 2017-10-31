classdef GreenLEDType
	enumeration
		NM505
		NM570
	end
	methods
		function c = char(obj)
			import edu.washington.riekelab.sara.types.GreenLEDType;
			switch obj
				case GreenLEDType.NM505
					c = '505nm';
				case GreenLEDType.NM570
					c = '570nm';
			end
		end
	end
end