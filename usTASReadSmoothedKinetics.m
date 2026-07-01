function trace = usTASReadSmoothedKinetics(filePath)
%USTASREADSMOOTHEDKINETICS Read exported or two-column kinetic traces.
%
% Expected columns:
% 2 columns: time_s, signal
% 3 columns: time_s, raw_A_minus_B, smoothed_A_minus_B
% 4+ columns: time_s, raw_A_minus_B, smoothed_A_minus_B, final_signal

data = readmatrix(filePath, 'FileType', 'text');
if size(data, 2) < 2
    error('usTAS:BadKineticsFile', 'Kinetics file must contain at least two numeric columns.');
end

time = data(:, 1);
if size(data, 2) >= 4
    signal = data(:, 4);
elseif size(data, 2) >= 3
    signal = data(:, 3);
else
    signal = data(:, 2);
end

valid = isfinite(time) & isfinite(signal);
if ~any(valid)
    error('usTAS:NoKineticsData', 'No finite kinetic data found in %s.', filePath);
end

[~, name, ext] = fileparts(filePath);
trace = struct();
trace.filePath = filePath;
trace.label = [name ext];
trace.time = time(valid);
trace.timeUs = time(valid) .* 1e6;
trace.signal = signal(valid);
trace.visible = true;
trace.normFactor = 1;
trace.normalized = signal(valid);
end
