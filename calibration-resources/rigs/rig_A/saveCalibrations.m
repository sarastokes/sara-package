% note this will only work for mike
% d = load('C:\Users\manoo\Google Drive\Calibrations\20170621\Spectra.mat');
ledNames = {
    'red';
    'Green_505nm';
    'Green_570nm';
    'blue';
    };

for k = 1 : length(ledNames)
    fid = fopen([ledNames{k},'_spectrum.txt'],'wt');
    for m = 1 : size(energySpectra,1)
        fprintf(fid,'%e\n',energySpectra(m,k));
    end
    fclose(fid);
end

% q = load('C:\Users\manoo\Google Drive\Calibrations\20170621\QCatch.mat');




