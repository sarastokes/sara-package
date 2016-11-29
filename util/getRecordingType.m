function [recordingType, analysisType] = getRecordingType(r)
	% input analysis structure r or symphonyInput

	onlineAnalysis = [];
	if isstruct(r)
		if isfield(r.params, 'onlineAnalysis')
			onlineAnalysis = r.params.onlineAnalysis;
			label = r.label;
		end
	else
		if isa('symphonyui.core.persistent.epoch')
			eb = r.epochBlock;
		elseif isa('symphonyui.core.persistent.epochBlock')
			eb = r;
		end
		if isKey(r.protocolParameters, 'onlineAnalysis')
			onlineAnalysis = epochBlock.protocolParameters('onlineAnalysis');
		end
		label = epochBlock.epochGroup.label;
	end

	if isempty(onlineAnalysis)
		onlineAnalysis = 'none';
	end
	
	switch onlineAnalysis
		case 'extracellular'
			recordingType = 'extracellular';
		case {'spikes_CCLamp', 'subthresh_CClamp'}
			recordingType = 'current_clamp';
		case 'analog'
			recordingType = 'voltage_clamp';
		case 'none'
			switch label(1:2)
				case 'IC'
					recordingType = 'current_clamp';
				case {'VC', 'WC'}
					recordingType = 'voltage_clamp';
				otherwise
					recordingType = 'extracellular';
			end
	end
	analysisType = getAnalysisType(r, recordingType)

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

