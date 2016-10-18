function newMap = cutoffSNR(oldMap, SNR, cutoff)
	% zero out values under a certain SNR

	if nargin == 2
		fprintf('SNR mean = %.2f, SNR range = %.2f-%.2f',... 
			mean(mean(SNR)), min(min(SNR)), max(max(SNR)));
	end

	if isstruct(oldMap)
		oldMap = r.analysis.spatialRF;
	end
	if isstruct(SNR)
		SNR = r.analysis.SNR;
	end


	for ii = 1:size(SNR,1)
		for jj = 1:size(SNR,2)
			if SNR(ii, jj) > cutoff
				fprintf('%u-%u --> %.2f\n', ii, jj, oldMap(ii,jj));
				newMap(ii, jj) = oldMap(ii, jj);
			else
				newMap(ii, jj) = 0;
			end
		end
	end