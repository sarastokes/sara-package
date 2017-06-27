function EEweights = getWhite(varargin)
  % get the LMS weights of equal energy white
  % for an ex-vivo prep without a lens
  %
  % INPUTS:
  %     species       ['human'], 'nemestrina'
  %     OD            [0.2] optical density
  % OUTPUTS:
  %     coneWeights   normalized LMS activations
  %
  % SSP - 6Jun2017 - created

  ip = inputParser();
  ip.addParameter('species', 'human', @ischar);
  % optical density could change with prep layout but jay thinks 0.2 should be a safe bet. including as a parameter so we can test that
  ip.addParameter('OD', 0.2, @isnumeric);
  ip.parse(varargin{:});


  switch ip.Results.species
    case 'nemestrina'
      pkSens = [559 530 430];
      % jim's lens data - keep in unpublished folder for now
      load('nemestrinaLens.mat');
    case 'human'
      pkSens = [559 530 419];
      % from http://www.cvrl.org/database/text/maclens/lenssmj.htm
      load('humanLens.mat');
      % human lens data starts at 390nm, not 380 like spectra and cones
      wlMin = 390; wlMax = 780;
  end

  PRs = 'lms'; % TODO: does code work with rod added?
  wavelengths = wlMin:wlMax;
  npts = length(wavelengths)-1;
  spect = struct();

  % get cone sensitivities from jim's fcn
  for ii = 1:length(PRs)
    spect.(PRs(ii)) = spectsens(pkSens(ii), ip.Results.OD, 'alog', wlMin, wlMax, npts);
  end

  % lens data is represented where 0 is no attenuation
  % so normalize and subtract from 1
  lens = lensData(2,:);
  absorbed = 1./(10.^lens);

  % correct for the lens
  for ii = 1:length(PRs)
    lenSpect.(PRs(ii)) = spect.(PRs(ii)) .* absorbed;
  end

  % quantal correction
  % NOTE: is this a 'quantal correction'? these were already in quanta right?
  wave = wavelengths/max(wavelengths);
  for ii = 1:length(PRs)
    waveSpect.(PRs(ii)) = spect.(PRs(ii)) .* wave;
  end

  % integrate
  for ii = 1:length(PRs)
    EEweights(ii) = sum(waveSpect.(PRs(ii)));
  end

  fprintf('raw weights are %.2f L, %.2f M, %.2f S\n', EEweights);

  % normalize to the largest (l-cone)
  EEweights = EEweights/max(abs(EEweights));
  fprintf('normalized weights are %.2f L, %.2f M, %.2f S\n', EEweights);
