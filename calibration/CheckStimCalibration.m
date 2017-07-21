% 20Jul2017 - SSP
%% -------------------------------------------------------- constants -----
h = 6.6-34;
c = 2.998e8;
qe = getConstant('qe');
os = getConstant('os');
flashArea = (257.5)^2 * pi;


%% --------------------------------------------------- cone spectra -------
wavelength = 380:780;
lambdaMax = [559 530 430];
OD = 0.2;
for cone = 1:3
	coneSpectra(cone,:) = spectsens(lambdaMax(cone), OD, 'alog',... 
		wavelength(1), wavelength(end), length(wavelength)-1);
end

%% ---------------------------------------------------- calibrations ------
% 8 columns: S+, S-, M+, M-, L+, L-, (M+, M- with 505nm)
% 20Jul2017 - spectraphotometer  measurements (0.0ND)
load('ConeIso_20Jul.mat');
% 19Jul2017 - optometer measurements (0.0ND)
UDTPower = [0.76, 0.58, 0.57, 0.88, 0.99, 0.46, 0.45, 0.85] * 1e3;% uWatts
UDTPower = UDTPower * 1e-9; % Watts
% ??? - conduit measurement and correction
load('ConduitCorrection');


%% --------------------------------------------- correct and convert ------
numStim = size(energySpectra,2);
ledPower = size(UDTPower);
for stim = 1:numStim
    % multiply by the correction for the light pipe
    energySpectra(:, stim) = energySpectra(:, stim) .* conduit;
    
    % get the LED power provided by spectraphotometer 
    % (technically spectra are a histograms so correct to include nm step)
    ledPower(stim) = sum(energySpectra(:, stim)) * (wavelength(2)-wavelength(1));
    
    % divide out power from spect, use optometer power instead
    energySpectra(:, stim) = energySpectra(:, stim) / ledPower(stim);
    
    % use the optometer power instead
    energySpectra(:, stim) = energySpectra(:, stim) * UDTPower(1, stim);
    
    % now to quanta
    quantalSpectra(:, stim) = energySpectra(:, stim) .* wavelength' * 1e-9 / (h*c*flashArea);   
end
%%
% multiply the LED spectra by the cone spectra (all in quanta now!)
PhotonFlux = quantalSpectra' * coneSpectra';

%% ------------------------------------------------- compare stimuli ------
format short
siso = abs(PhotonFlux(1,:) - PhotonFlux(2,:));
miso = abs(PhotonFlux(3,:) - PhotonFlux(4,:));
liso = abs(PhotonFlux(5,:) - PhotonFlux(6,:));
%miso = abs(PhotonFlux(7,:) - PhotonFlux(8,:));
