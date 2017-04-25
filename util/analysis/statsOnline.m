function r = statsOnline(r)
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

    case 'edu.washington.riekelab.sara.protocols.ConeTestGrating'
      f1Mat = reshape(r.analysis.F1, 4, length(r.params.orientations));
      p1Mat = reshape(r.analysis.P1, 4, length(r.params.orientations));

      stats.coneF1 = mean(f1Mat(2:end,:),2);
      stats.coneP1 = mean(p1Mat(2:end,:),2);
      stats.lms = sign(stats.coneP1) .* (stats.coneF1/sum(stats.coneF1));
      fprintf('cone weights are %.2f L, %.2f M, %.2f S\n', stats.lms);

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
        r.stats.BPratio = BPratio;
        r.stats.bestSF = bestSF;
        fprintf('BP ratio = %.2f (%.2f)\n', mean(r.stats.BPratio), sem(r.stats.BPratio));
        fprintf('best SF = %.2f (%.2f).. in cpd: %.2f (%.2f)\n', mean(r.stats.bestSF), sem(r.stats.bestSF), pix2deg(mean(r.stats.bestSF)), pix2deg(sem(r.stats.bestSF)));
        % average, max, min optimal vs low SF
        % fprintf('optimal:low SF = %.2f pm %.2f\n',... mean(r.analysis.F1(:, bestSF)/r.analysis.F1(:,1)),...
        %  sem(r.analysis.F1(:,bestSF)/r.analysis.F1(:,1)));
      end

      case 'edu.washington.riekelab.manookin.protocols.ChromaticSpot'
    end
