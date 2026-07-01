function correction = usTASCorrectAB(aTrace, bTrace, wavelengthNm, calibration, options)
%USTASCORRECTAB Apply calibrated B-track correction.

if nargin < 5
    options = struct();
end
options = applyDefaults(options);

n = min(numel(aTrace.signal), numel(bTrace.signal));
time = aTrace.time(1:n);
a = aTrace.signal(1:n);
b = bTrace.signal(1:n);

calValue = usTASCalibrationValue(calibration, wavelengthNm, options.allowExtrapolation);

switch options.correctionMode
    case 'relativeCalibration'
        refWavelengths = options.referenceWavelengths;
        if isempty(refWavelengths)
            refWavelengths = calibration.wavelengthNm;
        end

        refValues = zeros(size(refWavelengths));
        for i = 1:numel(refWavelengths)
            refValues(i) = usTASCalibrationValue(calibration, refWavelengths(i), false);
        end

        scale = calValue / mean(refValues);
        message = sprintf('A - %.6g * B; calibration %.4g at %.1f nm.', ...
            scale, calValue, wavelengthNm);
    case 'unscaledSubtract'
        scale = 1;
        message = sprintf('A - B; calibration %.4g at %.1f nm recorded only.', ...
            calValue, wavelengthNm);
    otherwise
        error('usTAS:UnknownCorrectionMode', 'Unknown correction mode: %s.', options.correctionMode);
end

function options = applyDefaults(options)
defaults = struct();
defaults.allowExtrapolation = false;
defaults.correctionMode = 'unscaledSubtract';
defaults.referenceWavelengths = [];

fields = fieldnames(defaults);
for i = 1:numel(fields)
    name = fields{i};
    if ~isfield(options, name)
        options.(name) = defaults.(name);
    end
end
end

corrected = a - scale .* b;

if any(~isfinite(corrected))
    error('usTAS:NonFiniteCorrection', 'Correction generated non-finite values.');
end

correction = struct();
correction.wavelengthNm = wavelengthNm;
correction.time = time;
correction.a = a;
correction.b = b;
correction.corrected = corrected;
correction.calibrationValue = calValue;
correction.scale = scale;
correction.message = message;
correction.aFile = aTrace.filePath;
correction.bFile = bTrace.filePath;
end
