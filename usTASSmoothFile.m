function output = usTASSmoothFile(inputFile, outputFile, options)
%USTASSMOOTHFILE Smooth an existing A-B text file and write output data.

if nargin < 3
    options = struct();
end

trace = usTASReadABTxt(inputFile);
smoothed = usTASSegmentedSmooth(trace.time, trace.signal, options);
[baselineCorrected, baselineValue] = usTASBaselineCorrect(trace.time, smoothed, options);

outputDir = fileparts(outputFile);
if ~isempty(outputDir) && ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

output = struct();
output.inputFile = inputFile;
output.outputFile = outputFile;
output.time = trace.time;
output.raw = trace.signal;
output.smoothed = smoothed;
output.baselineCorrected = baselineCorrected;
output.baselineValue = baselineValue;

out = [trace.time(:), trace.signal(:), smoothed(:), baselineCorrected(:)];
writematrix(out, outputFile, 'Delimiter', 'tab', 'FileType', 'text');
end
