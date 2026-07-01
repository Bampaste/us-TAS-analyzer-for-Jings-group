function trace = usTASReadOscilloscopeCsv(filePath)
%USTASREADOSCILLOSCOPECSV Read Tek/oscilloscope CSV with time/value in cols 4-5.

data = readmatrix(filePath, 'FileType', 'text', 'Delimiter', ',');
if size(data, 2) < 5
    error('usTAS:NoData', 'Expected at least 5 columns in %s.', filePath);
end

time = data(:, 4);
signal = data(:, 5);
valid = isfinite(time) & isfinite(signal);
time = time(valid);
signal = signal(valid);

if isempty(time)
    error('usTAS:NoData', 'No numeric time/signal data found in %s.', filePath);
end

trace = struct();
trace.filePath = filePath;
trace.time = time;
trace.signal = signal;
end
