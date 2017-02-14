function newMap = cutoffSNR(oldMap, SNR, cutoff)
	% zero out values under a certain SNR
	% if unsure of cutoff, input only oldMap to get cutoff stats
	% INPUT: oldMap = original spatial RF,
	%					SNR = signal to noise for each pixel
	%					cutoff = SNR cutoff

	if nargin == 2
		fprintf('SNR mean = %.2f, SNR range = %.2f-%.2f',...
			mean(mean(SNR)), min(min(SNR)), max(max(SNR)));
			return;
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
