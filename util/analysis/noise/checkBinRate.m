function [peakTime, zeroCross, biphasicIndex] = checkBinRates(r, binRates)
  % check the effect of bin rate on zero cross, peak time and biphasic index
  % INPUT:  r           data structure
  %         binRates    which bin rates to test (default 1:20)
  % OUTPUT  peakTime, zeroCross, biphasicIndex at each binRate
  % also generates graphs
  % 20Mar2017 - SSP

  if nargin < 2
    binRates = 1:20;
  end

  peakTime = zeros(1, length(binRates));
  zeroCross = zeros(size(peakTime));
  biphasicIndex = zeros(size(peakTime));

  for ii = 1:length(binRates)
    tmp = analyzeOnline(r, 'bpf', ii);
    peakTime(1, ii) = tmp.analysis.peakTime;
    zeroCross(1, ii) = tmp.analysis.zeroCross;
    biphasicIndex(1, ii) = tmp.analysis.biphasicIndex;
  end

  figure('Name', 'bin rate analysis'); hold on;
  subplot(3,1,1); hold on;
  plot(binRates, peakTime, '-ok', 'LineWidth', 1);
  title('Peak times'); xlabel('bin rate'); ylabel('time (ms)');

  subplot(3,1,2); hold on;
  plot(binRates, zeroCross, '-ok', 'LineWidth', 1);
  title('Zero cross'); xlabel('bin rate'); ylabel('time (ms)');

  subplot(3,1,3); hold on;
    plot(binRates, biphasicIndex, '-ok', 'LineWidth', 1);
  title('Biphasic index'); xlabel('bin rate');

  fprintf('peak time %.2f (%.2f)\n', mean(peakTime), std(peakTime));
  fprintf('zero cross %.2f (%.2f)\n', mean(zeroCross(3:end)), std(zeroCross(3:end)));
  fprintf('biphasic index %.2f (%.2f)\n', mean(biphasicIndex), std(biphasicIndex));
