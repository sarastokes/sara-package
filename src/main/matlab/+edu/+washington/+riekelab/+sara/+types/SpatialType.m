classdef SpatialType
	enumeration
		ANNULUS
		SPOT
		FULLFIELD
		UNDEFINED
	end

	methods 
		function c = char(obj)
			import edu.washington.riekelab.sara.types.RecordingModeType;
			switch obj
				case SpatialType.SPOT
					c = 'spot';
				case SpatialType.ANNULUS
					c = 'annulus';
				case SpatialType.FULLFIELD
					c = 'fullfield';
				otherwise
					c = 'undefined';
			end
		end
	end
end
