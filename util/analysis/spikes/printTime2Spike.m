function printTime2Spike(r)
	% data structure, level above data

	for ii = 1:size(r.data,2)
		fprintf('\n%s at %.2f -->',r.data(ii).chromaticClass, r.data(ii).contrast);
		for jj = 1:r.data(ii).avg
			switch r.data(ii).recordingType
			case 'extracellular'
				if ~isempty(r.data(ii).spikeData.times{jj})
					fprintf(' %.1f ', (r.data(ii).spikeData.times{jj}(1)/10-r.data(ii).pre));
				else
					fprintf(' x ');
				end
			case 'voltage_clamp'
				switch r.data(ii).analysisType
				case 'excitation'
					[~, ind] = min(r.data(ii).analog(jj,:));
				case 'inhibition'
					[~, ind] = max(r.data(ii).analog(jj,:));
				end
				fprintf(' %.1f ', ind/10-r.data(ii).pre);
			end	
		end
	end
	fprintf('\n');