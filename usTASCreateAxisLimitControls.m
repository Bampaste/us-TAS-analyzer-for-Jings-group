function controls = usTASCreateAxisLimitControls(parent, ax, position, onApply, onAuto, onZeroToggle, showZeroLine)
%USTASCREATEAXISLIMITCONTROLS Add editable X/Y axis limit controls.
%
% position is [x y width height] in normalized units.

if nargin < 4
    onApply = [];
end
if nargin < 5
    onAuto = [];
end
if nargin < 6
    onZeroToggle = [];
end
if nargin < 7
    showZeroLine = false;
end

panel = uipanel(parent, 'Units', 'normalized', 'Position', position, ...
    'BackgroundColor', 'w', 'BorderType', 'none');

uicontrol(panel, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.00 0.55 0.10 0.35], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'X min');
xMinEdit = makeEdit([0.10 0.55 0.13 0.38]);

uicontrol(panel, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.25 0.55 0.10 0.35], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'X max');
xMaxEdit = makeEdit([0.35 0.55 0.13 0.38]);

uicontrol(panel, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.00 0.05 0.10 0.35], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'Y min');
yMinEdit = makeEdit([0.10 0.05 0.13 0.38]);

uicontrol(panel, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.25 0.05 0.10 0.35], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'Y max');
yMaxEdit = makeEdit([0.35 0.05 0.13 0.38]);

uicontrol(panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.52 0.18 0.13 0.62], 'String', 'Apply axes', ...
    'Callback', @applyLimits);
uicontrol(panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.68 0.55 0.09 0.38], 'String', 'Auto X', ...
    'Callback', @(~, ~) autoLimits('x'));
uicontrol(panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.68 0.05 0.09 0.38], 'String', 'Auto Y', ...
    'Callback', @(~, ~) autoLimits('y'));
uicontrol(panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.80 0.18 0.11 0.62], 'String', 'Auto all', ...
    'Callback', @(~, ~) autoLimits('all'));
zeroCheck = uicontrol(panel, 'Style', 'checkbox', 'Units', 'normalized', ...
    'Position', [0.925 0.18 0.075 0.62], 'String', 'y=0', ...
    'BackgroundColor', 'w', 'Value', showZeroLine, ...
    'Callback', @toggleZeroLine);

controls = struct();
controls.panel = panel;
controls.ax = ax;
controls.xMinEdit = xMinEdit;
controls.xMaxEdit = xMaxEdit;
controls.yMinEdit = yMinEdit;
controls.yMaxEdit = yMaxEdit;
controls.zeroCheck = zeroCheck;

usTASSyncAxisLimitControls(controls);

    function editHandle = makeEdit(pos)
        editHandle = uicontrol(panel, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', pos, 'BackgroundColor', 'w', 'HorizontalAlignment', 'center', ...
            'Callback', @applyLimits);
    end

    function applyLimits(~, ~)
        xLimits = readLimits(xMinEdit.String, xMaxEdit.String, xlim(ax));
        yLimits = readLimits(yMinEdit.String, yMaxEdit.String, ylim(ax));

        if strcmp(ax.XScale, 'log')
            xLimits = makePositiveLimits(xLimits, xlim(ax));
        end
        if strcmp(ax.YScale, 'log')
            yLimits = makePositiveLimits(yLimits, ylim(ax));
        end

        xlim(ax, xLimits);
        ylim(ax, yLimits);
        if isa(onApply, 'function_handle')
            onApply();
        end
        usTASSyncAxisLimitControls(controls);
    end

    function autoLimits(mode)
        if isa(onAuto, 'function_handle')
            onAuto(mode);
        else
            if strcmp(mode, 'x') || strcmp(mode, 'all')
                ax.XLimMode = 'auto';
            end
            if strcmp(mode, 'y') || strcmp(mode, 'all')
                ax.YLimMode = 'auto';
            end
            usTASSyncAxisLimitControls(controls);
        end
    end

    function toggleZeroLine(~, ~)
        if isa(onZeroToggle, 'function_handle')
            onZeroToggle(logical(zeroCheck.Value));
        end
    end

    function limits = readLimits(minText, maxText, fallback)
        minValue = str2double(minText);
        maxValue = str2double(maxText);
        if ~isfinite(minValue)
            minValue = fallback(1);
        end
        if ~isfinite(maxValue)
            maxValue = fallback(2);
        end
        if minValue == maxValue
            delta = max(abs(minValue) * 0.1, eps);
            minValue = minValue - delta;
            maxValue = maxValue + delta;
        elseif minValue > maxValue
            temp = minValue;
            minValue = maxValue;
            maxValue = temp;
        end
        limits = [minValue maxValue];
    end

    function limits = makePositiveLimits(limits, fallback)
        if limits(1) <= 0 || limits(2) <= 0
            limits = fallback;
        end
    end
end
