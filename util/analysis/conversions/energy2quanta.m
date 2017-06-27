function energy2quanta(wls, energy)
  % quanta = energy2quanta(wls, energy)
  %
  % Convert energy units (energy or power per unit wavelength)
  % to quantal units (quanta or quanta/sec per unit wavelength).
  %
  % Constants are set up so that we have energy in joules or
  % power in watts. Wavelengths should be passed in nanometers.
  %
  % This routine is set up to convert spectra. These are
  % passed as the columns of the matrix energy. The
  % wavelengths corresponding to each row are passed in
  % the column vector wls.
  %
  % 7/29/96 dhb Wrote it.
  % 8/16/96 dhb, abp Modified interface
  %
  % 10Jun2016 - SSP - This was from psychtoolbox,
  % just edited a little to work alone

  h = getConstant('planck');
  c = getConstant('c');
  [n, m] = size(energy);
  quanta = (energy/(h*c)) .* (1e-9 * wls(:, ones(1,m)));
