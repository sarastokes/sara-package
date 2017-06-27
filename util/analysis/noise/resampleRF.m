function resampleRF(srf1, srf2)
	% [newRFs, fh] = resampleRF(srf1, srf2, interpType)
	% upsample or downsample two spatial receptive fields, view result
	%
	% INPUTS:
	% 	srf1 		2d receptive field or data structure
	%   srf2		same but different stixel sizes
	% OUTPUTS:
	%	newRFs		m x n x 2 matrix of both receptive fields
	%	fh			figure handle
	% 	
	% 14Jun2017 - SSP - created

	if nargin < 3
		interpType = 'linear';
	else
		if isempty(find(ismember(interpType, {'linear', 'cubic', 'spline'})))
			warndlg('interpType should be linear cubic or spline. set to linear');
		end
	end

	if isstruct(srf1) || isstruct(srf2)
		warndlg('no structures for now');
		return;
	end

	[m1, n1] = size(srf1);
	[m2, n2] = size(srf2);

	if m1 > m2
		srf2 = interp2(m1, n1, srf2, m2, n2, interpType);
	else
		srf1 = interp2(m2, n2, srf1, m1, n1, interpType);
	end

	newRFs = [srf1; srf2];

	figure('Color', 'w', 'Name', 'Resampled receptive field');
	subplot(1,3,1); imagesc(srf1);
	subplot(1,3,2); imagesc(srf2);
	subplot(1,3,3); imagesc(mean(newRFs, 3));
	axis equal; axis tight; axis off;
	tightfig(gcf);

	if nargout == 2
		fh = gcf;
	end




