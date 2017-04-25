% clear all;
addpath('C:\Users\manoo\Documents\MATLAB\tbox\Calibration')
% The illumination area on the retina.
flashArea = pi*(515/2)^2; % 1024*768*1.3;

% Calculate the energy spectra: E = hc/wavelength.
h = 6.626e-34; % Joules/sec
c = 3.0e8; % meters/sec

% Load the spectra.
load('Spectra.mat');

c0 = load('ConduitCorrection.mat');

for k = 1 : size(energySpectra, 3)
    energySpectra(:,k) = energySpectra(:,k) .* c0.correction;
end

foo = sum(energySpectra);
% Normalize to the red led.
foo = foo / foo(1);

% Make sure the energySpectra sum to 1.
for k = 1 : size(energySpectra,3)
    energySpectra(:,k) = energySpectra(:,k) / sum(energySpectra(:,k)); 
end

% Load the radiometer calibrations.
% radcal = load('C:\Users\manoo\Google Drive\Calibrations\20161020\RadiometerCorrection.mat');
% scl = ones(1,3);
% for k = 1 : 3
%     scl(k) = sum(energySpectra(:,k) .* radcal.fitdata.correction(:));
% end

% The LED power in mWatts. This is the value that comes out of the
% photometer.

% The LED power in uWatts.
% ledPower = [0.166   0.341   0.38]*1000;
ledPower = [0.250 0.628 0.154]*1000;

% The ratio 'foo' came from spectroradiometer, so we need that ratio.
% ledPower = ledPower(1)*foo * 28/36;
% scl = ones(1,3);
scl = [54/54 10/28 55/55];

% scl = [1 1.3155 1.9372]; % Correct for the optometer bias

% 3.0 NDF
% scl = [9.425053569961490e-04 7.499137460042633e-04 7.011585570318966e-04];


% 4.0 NDF
% scl = [9.704161401583191e-05 7.058782602099980e-05 6.415017236476572e-05];

ledPower = ledPower .* scl;

% Scale by the mean setting of the LEDs.
ledScale = [1 1 1];
ledPower = ledPower .* ledScale;

% Convert to Watts.
ledPower = ledPower * 1e-9;

% Divide the energy spectra by the integral.
for j = 1 : 3
    energySpectra(:,j) = energySpectra(:,j) / sum(energySpectra(:,j));
end

% Determine the step size between the wavelength.
stepSize = wavelength(2) - wavelength(1);

% Calculate the power of each gun.
gunPower = sum(energySpectra * stepSize);

% Normalize by the gun power.
energySpectra = energySpectra ./ (ones(size(energySpectra,1),1) * gunPower); 

% Convert wavelength from nm to meters.
lambda = wavelength * 1e-9;

% Divide by the wavelength to get the energy in watts/sec.
quantalSpectra = energySpectra .* (lambda*ones(1,3)) / (h*c);

% Multiply by the LED power.
quantalSpectra = quantalSpectra .* (ones(size(quantalSpectra,1),1) * ledPower);

%--------------------------------------------------------------------------
% Multiply the energy spectra by the cone spectra and take the integral.
receptorSpectra = PhotoreceptorSpectrum(wavelength);
% Grab the cone spectra.
% coneSpectra = receptorSpectra(1:3,:)';
coneSpectra = receptorSpectra(1:4,:)';

% Get the photon flux.
photonFlux = (quantalSpectra' * coneSpectra);

% Get the photon flux per square micron.
fluxPerSqMicron = photonFlux / flashArea;

%--------------------------------------------------------------------------
% Calculate the quantal catch.

outerSegment = 0.67; % Outer segment cross-sectional area in um^2

qCatch = fluxPerSqMicron * outerSegment;

% Factor in the quantal efficiency.
qCatch(:,1:3) = qCatch(:,1:3) * 0.37;

if size(qCatch,2) == 4
    qCatch(:,4) = qCatch(:,4) * 1.7; % Higher efficiency for rods.
end

qCatch(qCatch < 0) = 0;

%--------------------------------------------------------------------------
% Generate the cone-isolating stimuli. Normalize everything to the red gun.
stimulusMatrix = [
    1 0 0; % L-iso
    0 1 0; % M-iso
    0 0 1; % S-iso
    1 1 0; % L+M-iso
    -1 -1 1; % S-(L+M);
    -1 1 1; % (S+M)-L (blue)
    1 -1 1; % (S+L)-M (red)
    0 1 1; % (S+M)
    1 0 1; % (S+L)
    1 -1 -1; % L-(S+M)
    -1 1 -1; % M-(S+L)
    ];


gunMeans = 0.5*ones(size(stimulusMatrix));
gunMeans(3,:) = [0.5 0.5 0.5];

gunMeans(:,2) = 0.5;

coneContrast = zeros(size(stimulusMatrix));
rgbMatrix = zeros(size(stimulusMatrix));
for j = 1 : size(stimulusMatrix,1)
    deltaRGB = 2*(qCatch(:,1:3).*(ones(3,1)*gunMeans(j,:))')' \ stimulusMatrix(j,:)';
    deltaRGB = deltaRGB / max(abs(deltaRGB));
    
    % Calculate the mean photon flux.
    meanFlux = qCatch(:,1:3) * gunMeans(j,:)';
    
    % Calculate the max contrast of each photoreceptor type.    
    coneContrast(j,:) = deltaRGB(:)' * qCatch(:,1:3) .* gunMeans(j,:) ./ ...
        (gunMeans(j,:) .* sum(qCatch(:,1:3)));
    
    % Calculate the RGB gun amplitudes normalized to the red gun.
    rgbMatrix(j,:) = deltaRGB; % / deltaRGB(1);
end

% Loop through the NDFs an calculate the QCatch for each.
nd = load('NDTransmission.mat');

ndf00 = qCatch;

fnames = fieldnames(nd);

qCatch = struct();
qCatch.ndf00 = ndf00;
for k = 2 : length(fnames)
    tr = nd.(fnames{k});
    sc = energySpectra'*tr;
    qCatch.(fnames{k}) = ndf00 .* (sc*ones(1,4));
end

save('QCatch.mat', 'qCatch');

q = qCatch.ndf10;
b = sum(q); b = b(1:3);
b / b(1)

diag(coneContrast(1:3,:))