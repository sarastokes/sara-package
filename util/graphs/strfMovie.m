function strfMovie(r, numBins, pauseLength)

  if nargin < 3
    pauseLength = 0.25;
    if nargin < 2
      [~,~,foo] = size(r.analysis.strf);
      numBins = 1:foo;
    end
  end

  if strcmp(r.params.chromaticClass, 'RGB')
    strf = shiftdim(r.analysis.strf, 1);
  else
    strf = r.analysis.strf;
  end

  figure;
  for ii = 1:length(numBins)
    bin = numBins(ii);
    if strcmp(r.params.chromaticClass, 'RGB')
      imagesc(squeeze(strf(:,:,bin,:)), [0 1]);
    elseif strcmp(r.params.chromaticClass,'achromatic')
      imagesc(squeeze(strf(:,:, bin)));
      colormap(bone);
    else
      imagesc(squeeze(strf(:,:,bin)));
      colormap(pmkmp(256,'cubicL'));
    end
    axis equal; axis off;
    title([num2str(bin) ' msec before spike']);
    pause(pauseLength);
  end
end
