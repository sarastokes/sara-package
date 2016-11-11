function timingFlag = checkFrameMonitor(epoch, deviceNum)
	% make sure frame monitor is ok - TODO: test out diff cutoff methods
	% assuming 10k sample rate

	% this could really be improved but it's good for now
	if nargin < 2
		if strcmp(epoch.getResponses{2}.device.name, 'Frame Monitor')
			deviceNum = 2;
		elseif strcmp(epoch.getResponses{3}.device.name, 'Frame Monitor')
			deviceNum = 3;
		else
			error('No frame monitor found');
		end
	end

	if deviceNum ~= 0
		frames = epoch.getResponses{deviceNum}.getData;
		xpts = length(frames);
		if isempty(find(frames(1:1000) < 0.25*(max(frames))))
			fprintf('Warning: stimuli triggered late\n');
			timingFlag = 1;
		elseif isempty(find(frames(xpts-1000:xpts) > 0.25*(max(frames))))
			fprintf('Warning: stimulus triggered early\n');
			timingFlag = 2;
		else
			timingFlag = 0;
		end
	end
