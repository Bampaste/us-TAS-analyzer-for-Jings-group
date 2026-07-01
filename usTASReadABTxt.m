function trace = usTASReadABTxt(filePath)
%USTASREADABTXT Read existing A-B text output with time and signal columns.

data = readmatrix(filePath, 'FileType', 'text');
if size(data, 2) < 2
    error('usTAS:BadABFile', 'A-B file must contain at least two numeric columns.');
end

time = data(:, 1);
signal = data(:, 2);
valid = isfinite(time) & isfinite(signal);

trace = struct();
trace.filePath = filePath;
trace.time = time(valid);
trace.signal = signal(valid);

if isempty(trace.time)
    error('usTAS:NoABData', 'No finite A-B data found in %s.', filePath);
end
end
