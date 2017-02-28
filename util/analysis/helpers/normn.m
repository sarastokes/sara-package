function A = normN(A)
  % normalize matrices quickly
  % A = A/max(abs(A))
  % 22Feb2017


  s = A;
  while numel(s) > 1
    s = max(s);
  end

  A = A/abs(s);
