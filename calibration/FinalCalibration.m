%% CALIBRATION_CALCULATIONS
% 8Jun2017 - SSP - created
% 20Jul2017 - SSP - updated with 4 LEDs and skipping white calculation
% 
% CALC_DIR = 'fname';
% species = 'nemestrina'; % nemestrina or human
% whitePt = getWhite('species',species);

%% -------------------------------------------------------- constants -----
h = 6.6e-34;
c = 2.998e8;
qe = getConstant('qe');
os = getConstant('os');
flashArea = (257.5)^2 * pi;
OD = 0.2;
lambdaMax = [559 530 430]; % Schnapf S-cone peak

%% ---------------------------------------------------- calibrations ------
whichLED = 'Green_570nm';
% from jay's spectrophotometer
load('spectra_21Jun2017.mat');
load('ConduitCorrection.mat');
waveStep = wavelength(2)-wavelength(1);
% from fred's optometer
% measured 17Jul2017 at 0.0ND
UDTPower = [0.64, 0.62, 0.47, 0.2]*1000; % uWatts
UDTPower = UDTPower * 1e-9;
switch whichLED
    case 'Green_570nm'
        energySpectra(:,2) = [];
        UDTPower(2) = [];
    case 'Green_505nm'
        energySpectra(:,3) = [];
        UDTPower(3) = [];
end
numLEDs = size(energySpectra,2);



%% ------------------------------------------------ cone spectra ----------
% cone spectra from jay's template
for cone = 1:3
	coneSpectra(cone,:) = spectsens(lambdaMax(cone), OD, 'alog',... 
		wavelength(1), wavelength(end), length(wavelength)-1);
end

%% --------------------------------------------- correct and convert ------
for led = 1:numLEDs
	% multiply by the correction for the light pipe
	energySpectra(:,led) = energySpectra(:,led) .* conduit;

	% integrate each LED (waveStep=1 bc we sampled every 1 nm)
	ledPower(led) = sum(energySpectra(:,led)) * waveStep;

	% set relative weights by the optometer values
	energySpectra(:,led) = energySpectra(:, led) * UDTPower(led) / ledPower(led);

	% now to quanta
	quantalSpectra(:, led) = energySpectra(:, led) .* wavelength * 1e-9 / (h * c * flashArea);
end

% multiply the LED spectra by the cone spectra (all in quanta now!)
PhotonFlux = quantalSpectra' * coneSpectra';
% rows rgb, cols lms
cd('C:\Users\sarap\Google Drive\MATLAB\Symphony\sara-package\calibration');
switch whichLED
    case 'Green_505nm'
        save('PhotonFlux_505', 'PhotonFlux');
    otherwise
        save('PhotonFlux_570', 'PhotonFlux');
end

% Factor in quantal efficiency and collecting area of cones
% NOTE: doesn't really matter since i'm not including rods?
% PhotonFlux = PhotonFlux * qe(1) * os;

%% ---------------------------------------------------- cone iso stim -----
%GunMeans = [1 0.88 0.45]/2;
GunMeans = [0.5 0.5 0.5];
MeanFlux = PhotonFlux * GunMeans';
coneContrast = zeros(3);
coneStim = eye(3);

for stim = 1:3
	dRGB = 2 * (PhotonFlux .* repmat(GunMeans, [3 1]))' \ coneStim(cone,:)';
	dRGB = dRGB / max(abs(dRGB));

	coneContrast(stim, :) = dRGB' * PhotonFlux(:, 1:3) .* GunMeans ./ ...
		(GunMeans .* sum(PhotonFlux(:, 1:3)));
end