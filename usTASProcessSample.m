function results = usTASProcessSample(sampleFolder, calibrationFile, outputFolder, options)
%USTASPROCESSSAMPLE Process all wavelength folders in one us-TAS sample.

if nargin < 4
    options = struct();
end
options = applyDefaults(options);

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

calibration = usTASReadCalibration(calibrationFile);
folders = dir(sampleFolder);
folders = folders([folders.isdir]);

summary = struct('folder', {}, 'wavelengthNm', {}, 'calibrationValue', {}, ...
    'scale', {}, 'status', {}, 'message', {}, 'outputFile', {});

for i = 1:numel(folders)
    folderName = folders(i).name;
    if startsWith(folderName, '.')
        continue;
    end

    wavelength = parseWavelength(folderName);
    if isnan(wavelength)
        continue;
    end

    measurementFolder = fullfile(sampleFolder, folderName);
    aFile = findTrackFile(measurementFolder, 'A track.csv');
    bFile = findTrackFile(measurementFolder, 'B track.csv');

    entry = struct();
    entry.folder = folderName;
    entry.wavelengthNm = wavelength;
    entry.calibrationValue = NaN;
    entry.scale = NaN;
    entry.status = "skipped";
    entry.message = "";
    entry.outputFile = "";

    try
        if isempty(aFile) || isempty(bFile)
            error('usTAS:MissingTrack', 'Missing A track or B track file.');
        end

        aTrace = usTASReadOscilloscopeCsv(aFile);
        bTrace = usTASReadOscilloscopeCsv(bFile);
        correction = usTASCorrectAB(aTrace, bTrace, wavelength, calibration, options);

        outName = sprintf('%s-corrected-A-B.txt', sanitizeName(folderName));
        outFile = fullfile(outputFolder, outName);
        writematrix([correction.time(:), correction.corrected(:)], outFile, ...
            'Delimiter', 'tab', 'FileType', 'text');

        if options.saveFigures
            figName = sprintf('%s-QC.%s', sanitizeName(folderName), options.figureFormat);
            figFile = fullfile(outputFolder, figName);
            usTASPlotQC(correction, figFile);
        end

        entry.calibrationValue = correction.calibrationValue;
        entry.scale = correction.scale;
        entry.status = "ok";
        entry.message = correction.message;
        entry.outputFile = outFile;
    catch ME
        entry.status = "error";
        entry.message = string(ME.message);
    end

    summary(end + 1) = entry; %#ok<AGROW>
end

results = struct();
results.summary = summary;
results.outputFolder = outputFolder;
results.calibration = calibration;
end

function options = applyDefaults(options)
defaults = struct();
defaults.allowExtrapolation = false;
defaults.correctionMode = 'unscaledSubtract';
defaults.referenceWavelengths = [];
defaults.saveFigures = true;
defaults.figureFormat = 'png';

fields = fieldnames(defaults);
for i = 1:numel(fields)
    name = fields{i};
    if ~isfield(options, name)
        options.(name) = defaults.(name);
    end
end
end

function wavelength = parseWavelength(textValue)
tokens = regexp(textValue, '(\d+(?:\.\d+)?)\s*nm', 'tokens', 'once', 'ignorecase');
if isempty(tokens)
    wavelength = NaN;
else
    wavelength = str2double(tokens{1});
end
end

function filePath = findTrackFile(folderPath, suffix)
files = dir(fullfile(folderPath, ['*' suffix]));
if isempty(files)
    filePath = '';
else
    filePath = fullfile(folderPath, files(1).name);
end
end

function value = sanitizeName(value)
value = regexprep(value, '[^\w\-. ]', '_');
value = strrep(value, ' ', '_');
end
