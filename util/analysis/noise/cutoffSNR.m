function newMap = cutoffSNR(oldMap, cutoff, SNR)
	% zero out values under a certain SNR
	% if unsure of cutoff, input only oldMap to get cutoff stats
	% INPUT: 	oldMap = original spatial RF,
	%					SNR = signal to noise for each pixel
	%					cutoff = SNR cutoff (percent 0.x)

	if nargin < 2
		fprintf('SNR mean = %.2f, SNR range = %.2f-%.2f\n',...
			mean(mean(SNR)), min(min(SNR)), max(max(SNR)));
	end

	if nargin < 3 && isstruct(oldMap)
		SNR = oldMap.analysis.SNR;
		strf = oldMap.analysis.strf;
	else
		strf = oldMap;
	end

	cutoff = cutoff * (max(max(max(SNR))) - min(min(min(SNR))));
	cutoff = cutoff + min(min(min(SNR)));
	fprintf('cutoff set to %.2f\n', cutoff);

	strf = strf/max(max(max(abs(strf))));
	fprintf('normalized strf\n');

	counter = 0;
	newMap = zeros(size(strf));

	for ii = 1:size(SNR,1)
		for jj = 1:size(SNR,2)
			if SNR(ii, jj) > cutoff
				newMap(ii, jj, :) = strf(ii, jj);
			else
				newMap(ii, jj, :) = 0;
				counter = counter + 1;
			end
		end
	end
	fprintf('cut %u of %u pixels\n', counter, numel(SNR));
