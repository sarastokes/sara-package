function [RGBmap, fh] = strfRGB(r, bins)
  % return and plot a RGB strf map
  % INPUT:  r = data structure or strf matrix
  %         bins = time bins to use
  % OUTPUT: RGBmap = matrix
  %         fh = figure handle

  if isstruct(r)
    strf = r.analysis.strf;
  else
    strf = r;
  end

  if size(strf,1) == 3
    strf = shiftdim(strf, 1);
  end

  Rmap = squeeze(mean(strf(:,:,bins,1)));
  Gmap = squeeze(mean(strf(:,:,bins,2)));
  Bmap = squeeze(mean(strf(:,:,bins,3)));

  RGBmap = cat(3, Rmap/max(max(max(abs(Rmap)))), Gmap/max(max(max(abs(Gmap)))));
  RGBmap =  cat(3, RGBmap, Bmap/max(max(max(abs(Bmap)))));

  figure;
  imagesc(RGBmap);
