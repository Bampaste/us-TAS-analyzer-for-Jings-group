function smoothed = usTASSegmentedSmooth(time, signal, options)
%USTASSEGMENTEDSMOOTH Smooth kinetics with different windows by time segment.
%
% options.segmentEdgesUs defines segment edges in microseconds.
% options.windowPoints defines the moving-window size for each segment.

if nargin < 3
    options = struct();
end
options = applyDefaults(options);

time = time(:);
signal = signal(:);

if numel(time) ~= numel(signal)
    error('usTAS:SizeMismatch', 'time and signal must have the same length.');
end

edgesUs = options.segmentEdgesUs(:).';
windowPoints = options.windowPoints(:).';

if numel(windowPoints) ~= numel(edgesUs) + 1
    error('usTAS:BadSmoothOptions', ...
        'windowPoints must have one more value than segmentEdgesUs.');
end

timeUs = time .* 1e6;
smoothed = nan(size(signal));

for i = 1:numel(windowPoints)
    if i == 1
        inSegment = timeUs <= edgesUs(1);
    elseif i == numel(windowPoints)
        inSegment = timeUs > edgesUs(end);
    else
        inSegment = timeUs > edgesUs(i - 1) & timeUs <= edgesUs(i);
    end

    if ~any(inSegment)
        continue;
    end

    win = normalizeWindow(windowPoints(i), numel(signal));
    candidate = smoothWithMethod(signal, win, options.method);
    smoothed(inSegment) = candidate(inSegment);
end

missing = isnan(smoothed);
if any(missing)
    smoothed(missing) = signal(missing);
end
end

function y = smoothWithMethod(signal, windowPoints, method)
switch lower(method)
    case 'movmean'
        y = movmean(signal, windowPoints, 'omitnan');
    case 'movmedian'
        y = movmedian(signal, windowPoints, 'omitnan');
    otherwise
        error('usTAS:UnknownSmoothMethod', 'Unknown smoothing method: %s.', method);
end
end

function win = normalizeWindow(value, n)
win = max(1, round(value));
win = min(win, n);
if mod(win, 2) == 0
    win = win + 1;
end
win = min(win, n);
end

function options = applyDefaults(options)
defaults = struct();
defaults.segmentEdgesUs = [0 10 100];
defaults.windowPoints = [5 21 81 301];
defaults.method = 'movmean';

fields = fieldnames(defaults);
for i = 1:numel(fields)
    name = fields{i};
    if ~isfield(options, name)
        options.(name) = defaults.(name);
    end
end
end
