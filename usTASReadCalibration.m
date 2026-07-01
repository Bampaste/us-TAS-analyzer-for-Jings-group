function calibration = usTASReadCalibration(filePath)
%USTASREADCALIBRATION Read wavelength/intensity calibration table.

data = readmatrix(filePath, 'FileType', 'text');
data = data(all(isfinite(data), 2), :);

if size(data, 2) < 2
    error('usTAS:BadCalibration', 'Calibration file must contain wavelength and intensity columns.');
end

wavelengthNm = data(:, 1);
intensity = data(:, 2);

[wavelengthNm, order] = sort(wavelengthNm);
intensity = intensity(order);

if any(intensity <= 0)
    error('usTAS:BadCalibration', 'Calibration intensities must be positive.');
end

calibration = struct();
calibration.filePath = filePath;
calibration.wavelengthNm = wavelengthNm;
calibration.intensity = intensity;
calibration.minWavelengthNm = min(wavelengthNm);
calibration.maxWavelengthNm = max(wavelengthNm);
end
