function response = getResponseByType(response, onlineAnalysis)
    % Bin the data based on the type.
    %  'extracellular', 'spikes_CClamp', 'subthresh_CClamp', 'analog'

    % added to utils for figure access 
  switch onlineAnalysis
    case 'extracellular'
      response = wavefilter(response(:)', 6);
      S = spikeDetectorOnline(response);
      spikesBinary = zeros(size(response));
      spikesBinary(S.sp) = 1;
      response = spikesBinary;
    case 'spikes_CClamp'
      spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
      spikesBinary = zeros(size(response));
      spikesBinary(spikeTimes) = 1;
      response = spikesBinary;
    case 'subthresh_CClamp'
      spikeTimes = getThresCross([0 diff(response(:)')], 1.5, 1);
      % Get the subthreshold potential.
      if ~isempty(spikeTimes)
        response = getSubthreshold(response(:)', spikeTimes);
      else
        response = response(:)';
      end
      % Subtract the median.
      if obj.preTime > 0
        response = response - median(response(1:round(obj.sampleRate*obj.preTime/1000)));
      else
        response = response - median(response);
      end
    case 'analog'
      % Deal with band-pass filtering analog data here.
      response = bandPassFilter(response, 0.2, 500, 1/obj.sampleRate);
      % Subtract the median.
      if obj.preTime > 0
        response = response - median(response(1:round(obj.sampleRate*obj.preTime/1000)));
      else
        response = response - median(response);
      end
   end
