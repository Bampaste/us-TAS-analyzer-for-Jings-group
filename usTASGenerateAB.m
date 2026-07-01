function output = usTASGenerateAB(aFile, bFile, outputFile)
%USTASGENERATEAB Generate A-B text data directly from A-track and B-track CSVs.

aTrace = usTASReadOscilloscopeCsv(aFile);
bTrace = usTASReadOscilloscopeCsv(bFile);

n = min(numel(aTrace.signal), numel(bTrace.signal));
time = aTrace.time(1:n);
aSignal = aTrace.signal(1:n);
bSignal = bTrace.signal(1:n);
abSignal = aSignal - bSignal;

outputDir = fileparts(outputFile);
if ~isempty(outputDir) && ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

writematrix([time(:), abSignal(:)], outputFile, 'Delimiter', 'tab', 'FileType', 'text');

output = struct();
output.aFile = aFile;
output.bFile = bFile;
output.outputFile = outputFile;
output.time = time;
output.aSignal = aSignal;
output.bSignal = bSignal;
output.abSignal = abSignal;
end
