function [recordingType, analysisType] = getRecordingType(r)
	% input analysis structure r

	switch r.params.onlineAnalysis
		case 'extracellular'
			recordingType = 'extracellular';
		case {'spikes_CCLamp', 'subthresh_CClamp'}
			recordingType = 'current_clamp';
		case 'analog'
			recordingType = 'voltage_clamp';
		case 'none'
			switch r.label(1:2)
				case 'IC'
					recordingType = 'current_clamp';
				case {'VC', 'WC'}
					recordingType = 'voltage_clamp';
				otherwise
					recordingType = 'extracellular';
			end
	end
	analysisType

	function analysisType = getAnalysisType(r, recordingType)

		switch recordingType
		case 'extracellular'
			if r.numAmps == 2
				analysisType = 'paired';
			elseif isfield(r, 'secondary')
				analysisType = 'dual';
			else
				analysisType = 'spikes&subthresh';
			end
		case 'current_clamp'
			analysisType = 'both';
		case 'voltage_clamp'
			if mean(r.resp(1,:) > 0)
				analysisType = 'inhibition';
			else
				analysisType = 'excitation'
			end
		end
	end % getAnalysisType
end % getRecordingType

