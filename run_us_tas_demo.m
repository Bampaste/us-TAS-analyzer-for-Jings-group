% run_us_tas_demo
% Edit these paths for the dataset you want to process.

sampleFolder = 'D:\OneDrive\Jing Group\Results\PDI\us-TAS\2026.06.26\PDINH-Air-1mJ';
calibrationFile = 'G:\for jing us-TAS\Light intensity@20230408.txt';
outputFolder = fullfile(fileparts(mfilename('fullpath')), 'demo_output');

options = struct();
options.allowExtrapolation = false;  % Real-analysis default: do not simulate missing calibration.
options.correctionMode = 'unscaledSubtract';
options.referenceWavelengths = [600 650 700 750 800 850 900 950];
options.saveFigures = true;
options.figureFormat = 'png';

results = usTASProcessSample(sampleFolder, calibrationFile, outputFolder, options);

disp(struct2table(results.summary));
fprintf('Output written to:\n%s\n', outputFolder);
