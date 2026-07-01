function value = usTASCalibrationValue(calibration, wavelengthNm, allowExtrapolation)
%USTASCALIBRATIONVALUE Interpolate calibration and guard extrapolation.

if wavelengthNm < calibration.minWavelengthNm || wavelengthNm > calibration.maxWavelengthNm
    if ~allowExtrapolation
        error('usTAS:CalibrationOutOfRange', ...
            ['No calibration value for %.1f nm. Calibration range is %.1f-%.1f nm. ' ...
            'Enable extrapolation only for exploratory QC.'], ...
            wavelengthNm, calibration.minWavelengthNm, calibration.maxWavelengthNm);
    end

    value = interp1(calibration.wavelengthNm, calibration.intensity, wavelengthNm, ...
        'linear', 'extrap');
else
    value = interp1(calibration.wavelengthNm, calibration.intensity, wavelengthNm, ...
        'linear');
end

if ~isfinite(value) || value <= 0
    error('usTAS:InvalidCalibrationValue', ...
        'Invalid calibration value %.4g for %.1f nm.', value, wavelengthNm);
end
end
