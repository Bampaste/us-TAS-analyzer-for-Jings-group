function [corrected, baselineValue] = usTASBaselineCorrect(time, signal, options)
%USTASBASELINECORRECT Subtract baseline estimated from a time window.
%
% time is in seconds. options.baselineWindowUs is in microseconds.

if nargin < 3
    options = struct();
end
options = applyDefaults(options);

timeUs = time(:) .* 1e6;
signal = signal(:);
window = options.baselineWindowUs;
inWindow = timeUs >= window(1) & timeUs <= window(2) & isfinite(signal);

if ~any(inWindow)
    error('usTAS:NoBaselinePoints', ...
        'No finite points found in baseline window %.3g to %.3g us.', window(1), window(2));
end

switch lower(options.baselineMethod)
    case 'mean'
        baselineValue = mean(signal(inWindow), 'omitnan');
    case 'median'
        baselineValue = median(signal(inWindow), 'omitnan');
    case 'none'
        baselineValue = 0;
    otherwise
        error('usTAS:UnknownBaselineMethod', ...
            'Unknown baseline method: %s.', options.baselineMethod);
end

corrected = signal - baselineValue;
end

function options = applyDefaults(options)
defaults = struct();
defaults.baselineWindowUs = [-900 -50];
defaults.baselineMethod = 'mean';

fields = fieldnames(defaults);
for i = 1:numel(fields)
    name = fields{i};
    if ~isfield(options, name)
        options.(name) = defaults.(name);
    end
end
end
