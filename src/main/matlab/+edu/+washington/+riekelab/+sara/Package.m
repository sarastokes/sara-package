classdef Package < handle

	methods (Static)
		function p = getCalibrationResource(varargin)
			parentPath = fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))))));
      calibrationPath = fullfile(parentPath, 'calibration-resources');

      p = fullfile(calibrationPath, varargin{:});
    end
  end % methods
end % classdef
 