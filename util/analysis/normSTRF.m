function r = normSTRF(r)

%  if strcmp(method,'time')

  strf = r.analysis.strf;
  [x,y,t] = size(r.analysis.strf);
  r.analysis.normSTRF = zeros(size(strf));
  r.analysis.normSRF = zeros(size(r.analysis.spatialRF));

%  temporalRF = zeros(size(r.analysis.strf,3), 1);
foo = squeeze(mean(r.analysis.strf,3));

   for ii = 1:x
     for jj = 1:y
       stdev = squeeze(std(r.analysis.strf(ii,jj,:)));
       for kk = 1:t
         if abs(r.analysis.strf(ii,jj,kk)) < squeeze(mean(r.analysis.strf(ii,jj,:)))+2*stdev
           r.analysis.normSTRF(ii,jj,kk) = foo;
         end
       end
     end
   end
   r.analysis.normSRF = squeeze(mean(r.analysis.normSTRF, 3));
