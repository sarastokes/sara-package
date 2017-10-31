function [isi, counts, bins, stats] = getISI(spikes, varargin)
    % GETISI  Interspike interval analysis
    %
    %	Input:
    %		spikes			spike times cell or spike binary matrix
    %	Optional:
    %		numBins 		number of bins, (50)
    %		norm 			counts as percent of total isi # (true)
    %	Output:
	%		isi 			all interspike intervals
    %		counts 			number of ISIs per bin
    %		binCenters 		center of each bin for x-axis
	%		stats 			structure containing mean, sem, etc
	%
    %
    % 24Oct2017 - SSP

    ip = inputParser();
    ip.CaseSensitive = false;
    addParameter(ip, 'numBins', 50, @isnumeric);
    addParameter(ip, 'normCount', true, @islogical);
    parse(ip, varargin{:});
    numBins = ip.Results.numBins;
    
    isi = [];

    % Convert to spike times if input is a spike binary matrix
    if ~iscell(spikes)
        if sum(sum(spikes>1)) == 0
            for i = 1:size(spikes, 1) % epochs in rows
                isi = cat(2, isi, diff(find(spikes(i,:))));
            end
        else
            isi = diff(spikes);
        end
    else % cell of spike times
        for i = 1:numel(spikes)
            if ~isempty(spikes{i})
                isi = cat(2, isi, diff(spikes{i}));
            end
        end
    end
    
    isi = pts2ms(isi);

    % Histogram
    if nargout > 1
        [counts, bins] = hist(isi, numBins);
        if ip.Results.normCount
            counts = counts/numel(isi)*100;
            fprintf('%.1f%% in bin one, %.1f%% in bin two\n', counts(1:2));
        end
    end

    % Basic ISI stats
    stats.mean = mean(isi);
    stats.n = numel(isi);
    stats.sem = sem(isi);
    stats.sd = std(isi);
    fprintf('isi anaysis: mean = %.2f +- %.2f (n = %u)\n',...
        stats.mean, stats.sem, stats.n);
    
    % Find peaks
    stats.pks = peakfinder(counts(2:end), [], [], 1);
    fprintf('found %u peaks at: ', numel(stats.pks));
    disp(bins(stats.pks));