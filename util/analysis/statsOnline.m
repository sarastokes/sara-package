function S = statsOnline(r)
  % get protocol stats
  if nargin < 2
    bestSF = [];
  end

  switch r.protocol
    case 'edu.washington.riekelab.sara.protocols.ConeSweep'
      switch r.params.recordingType
      case 'extracellular'
        if ~isempty(strfind(r.params.stimClass, 'lms'))
          ind = strfind(r.params.stimClass, 'l')';
          F1 = mean(r.analysis.F1(ind:ind+2,:),2);
          F1 = F1/sum(F1);
          fprintf('%.2f %.2f %.2f\n', F1);
        end
      case 'voltage_clamp'
        % TODO: peak/min times+
      end

    case 'edu.washington.riekelab.sara.protocols.FullChromaticGrating'
      % low-cut ratio for type I vs type II
      if r.params.orientations == 1
        if isempty(bestSF) || bestSF > length(r.params.SFs)
          [~, bestSF] = max(r.analysis.F1);
          fprintf('Set bestSF to %u\n', bestSF);
        end
        % optimal SF vs low SF - type1/2
        fprintf('optimal:low SF = %.2f\n', max(r.analysis.F1)/r.analysis.F1(1));
      else
        for ii = 1:size(r.analysis.F1, 1)
          [~, bestSF(ii)] = max(r.analysis.F1(ii,:));
          BPratio(ii) = max(r.analysis.F1(ii,:))/r.analysis.F1(ii,1);
        end
        S.BPratio = BPratio
        % average, max, min optimal vs low SF
        % fprintf('optimal:low SF = %.2f pm %.2f\n',... mean(r.analysis.F1(:, bestSF)/r.analysis.F1(:,1)),...
        %  sem(r.analysis.F1(:,bestSF)/r.analysis.F1(:,1)));
      end

      case 'edu.washington.riekelab.manookin.protocols.ChromaticSpot'
    end
