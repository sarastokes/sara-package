function S = blankTracefh(nTraces, varargin)
  % Make a blank figure for comparing raw traces
  % INPUT: nTraces      how many traces
  % OPTIONAL: stimFlag   (0) set to 1 or include stimTrace vector
  %           recType    (ec) recording type for axes labels
  % OUTPUT: S            structure with figure and axes handles


  ip = inputParser();
  ip.addParameter('stimFlag', 0, @isvector);
  ip.addParameter('recType', 'ec', @ischar);
  ip.parse(varargin{:});
  stimFlag = ip.Results.stimFlag;
  recType = ip.Results.recType;


  if length(stimFlag) > 1
    stimTrace = stimFlag;
    stimFlag = 1;
  else
    stimTrace = [];
  end

  fh = figure('Color', 'w');
  fh.Position(2) = fh.Position(2) - (50*nTraces);
  fh.Position(4) = fh.Position(4) + (50*nTraces);

  for ii = 1:nTraces
    S.ax(ii) = subtightplot((2*nTraces) + stimFlag, 1, [1+(2*(ii-1)):2+(2*(ii-1))], 0.05, [0.05 0.05], [0.1 0.06]);
    hold on;
    set(S.ax(ii), 'Box', 'off', 'TickDir', 'out');
    if ii == nTraces
      xlabel('time (ms)');
      switch recType
        case {'ec', 'extracellular'}
          ylabel(S.ax(ii), 'amplitude (mV)');
        case {'vc', 'voltage_clamp'};
          ylabel(S.ax(ii), 'current (pA)');
      end
    else
      set(S.ax(ii), 'XTick', [], 'XTickLabel', {}, 'XColor', 'w');
    end
  end

  if stimFlag == 1
    S.stim = subtightplot((2*nTraces)+3, 1, (2*nTraces+3), 0.05, [0.03 0.1], [0.1 0.06]); hold on;
    if ~isempty(stimTrace)
      plot(stimTrace, 'k', 'LineWidth', 1);
    end
    set(gca, 'Box', 'off', 'TickDir', 'out', 'XColor', 'w', 'XTick', []);
    ylabel('contrast');
  end

  S.fh = fh;
