function app = usTASSmoothViewer(inputFile, outputFolder)
%USTASSMOOTHVIEWER Interactive segmented smoothing for existing A-B traces.
%
% The viewer opens empty first. Use File > Open A-B file or the Load button.

if nargin < 1
    inputFile = '';
end
if nargin < 2
    outputFolder = '';
end

state = struct();
state.inputFile = inputFile;
state.outputFolder = outputFolder;
state.hasData = false;
state.segmentEdgesUs = [0 10 100];
state.windowPoints = [5 21 81 301];
state.method = 'movmean';
state.autoBaseline = false;
state.baselineMethod = 'mean';
state.baselineWindowUs = [-900 -50];
state.baselineValue = 0;
state.manualOffset = 0;
state.xScale = 'linear';
state.yScale = 'linear';
state.autoAxis = true;
state.showZeroLine = true;
state.time = [];
state.timeUs = [];
state.raw = [];
state.smoothed = [];
state.finalSignal = [];
state.draggingFigure = false;
state.dragStartPointer = [];
state.dragStartPosition = [];
prefGroup = 'usTASPipeline';

fig = figure('Name', 'us-TAS segmented smooth', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [80 80 1280 780], ...
    'WindowScrollWheelFcn', @scrollZoom, ...
    'WindowButtonDownFcn', @startFigureDrag, ...
    'WindowButtonMotionFcn', @dragFigure, ...
    'WindowButtonUpFcn', @stopFigureDrag);

fileMenu = uimenu(fig, 'Text', 'File');
uimenu(fileMenu, 'Text', 'Open A-B file...', 'MenuSelectedFcn', @loadFileFromDialog);
uimenu(fileMenu, 'Text', 'Export data...', 'MenuSelectedFcn', @exportData);
uimenu(fileMenu, 'Text', 'Save figure...', 'MenuSelectedFcn', @saveFigure);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.35 0.68 0.57]);
rawLine = plot(ax, NaN, NaN, 'Color', [0.65 0.65 0.65], 'DisplayName', 'raw A-B');
hold(ax, 'on');
finalLine = plot(ax, NaN, NaN, 'Color', [0 0.25 0.95], 'LineWidth', 1.25, ...
    'DisplayName', 'smoothed final');
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Time (\mus)');
ylabel(ax, 'A-B signal');
legend(ax, 'Location', 'best');
usTASUpdateZeroLine(ax, state.showZeroLine);
emptyText = text(ax, 0.5, 0.5, 'Load an A-B file to start', 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontSize', 16, 'Color', [0.35 0.35 0.35]);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.80 0.91 0.16 0.045], 'String', 'Load A-B file', ...
    'Callback', @loadFileFromDialog);

makeLabel('Smoothing windows (points)', 0.80, 0.865);

makeLabel('Pre-t0', 0.80, 0.825);
preSlider = makeSlider(1, 501, state.windowPoints(1), 0.80, 0.795);
preEdit = makeValueEdit(state.windowPoints(1), 0.875, 0.795);
makeStepButton('-', 0.920, 0.795, 1, -2);
makeStepButton('+', 0.945, 0.795, 1, 2);

makeLabel('0-10 us', 0.80, 0.745);
earlySlider = makeSlider(1, 1001, state.windowPoints(2), 0.80, 0.715);
earlyEdit = makeValueEdit(state.windowPoints(2), 0.875, 0.715);
makeStepButton('-', 0.920, 0.715, 2, -2);
makeStepButton('+', 0.945, 0.715, 2, 2);

makeLabel('10-100 us', 0.80, 0.665);
midSlider = makeSlider(1, 2001, state.windowPoints(3), 0.80, 0.635);
midEdit = makeValueEdit(state.windowPoints(3), 0.875, 0.635);
makeStepButton('-', 0.920, 0.635, 3, -2);
makeStepButton('+', 0.945, 0.635, 3, 2);

makeLabel('>100 us', 0.80, 0.585);
lateSlider = makeSlider(1, 5001, state.windowPoints(4), 0.80, 0.555);
lateEdit = makeValueEdit(state.windowPoints(4), 0.875, 0.555);
makeStepButton('-', 0.920, 0.555, 4, -2);
makeStepButton('+', 0.945, 0.555, 4, 2);

windowSliders = [preSlider, earlySlider, midSlider, lateSlider];
windowEdits = [preEdit, earlyEdit, midEdit, lateEdit];

makeLabel('Smoothing method', 0.80, 0.505);
methodPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.80 0.475 0.16 0.035], 'String', {'movmean', 'movmedian'}, ...
    'Callback', @updateFromControls);

autoBaselineCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
    'Position', [0.80 0.430 0.16 0.035], 'String', 'Auto baseline', ...
    'BackgroundColor', 'w', 'Value', state.autoBaseline, 'Callback', @updateFromControls);

makeLabel('Baseline method', 0.80, 0.390);
baselinePopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.80 0.360 0.16 0.035], 'String', {'mean', 'median'}, ...
    'Callback', @updateFromControls);

makeLabel('Baseline window (us)', 0.80, 0.320);
baselineStartEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.80 0.290 0.075 0.035], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'center', 'String', sprintf('%g', state.baselineWindowUs(1)), ...
    'Callback', @updateFromControls);
baselineEndEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.885 0.290 0.075 0.035], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'center', 'String', sprintf('%g', state.baselineWindowUs(2)), ...
    'Callback', @updateFromControls);

makeLabel('Manual offset', 0.80, 0.250);
offsetEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.80 0.220 0.085 0.035], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'center', 'String', sprintf('%.4g', state.manualOffset), ...
    'Callback', @updateFromControls);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.895 0.220 0.030 0.035], 'String', '-', ...
    'Callback', @(~, ~) bumpOffset(-offsetStep()));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.930 0.220 0.030 0.035], 'String', '+', ...
    'Callback', @(~, ~) bumpOffset(offsetStep()));

makeLabel('Offset step', 0.80, 0.180);
offsetStepEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.895 0.180 0.065 0.035], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'center', 'String', '1e-5');

makeLabel('Axes', 0.80, 0.135);
xPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.80 0.105 0.075 0.035], 'String', {'linear X', 'log X'}, ...
    'Callback', @scaleChanged);
yPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.885 0.105 0.075 0.035], 'String', {'linear Y', 'log Y'}, ...
    'Callback', @scaleChanged);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.80 0.060 0.050 0.035], 'String', 'Zoom +', ...
    'Callback', @(~, ~) zoomAxes(0.75));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.855 0.060 0.050 0.035], 'String', 'Zoom -', ...
    'Callback', @(~, ~) zoomAxes(1.35));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.910 0.060 0.050 0.035], 'String', 'Auto', ...
    'Callback', @autoScaleAxes);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.80 0.015 0.075 0.035], 'String', 'Export', ...
    'Callback', @exportData);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.885 0.015 0.075 0.035], 'String', 'Save fig', ...
    'Callback', @saveFigure);

statusText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.07 0.68 0.15], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'No file loaded.');
axisControls = usTASCreateAxisLimitControls(fig, ax, [0.08 0.220 0.68 0.055], ...
    @setManualAxisMode, @autoScaleFromAxisControls, @setZeroLineVisible, state.showZeroLine);

if ~isempty(inputFile)
    loadFile(inputFile);
else
    setControlsEnabled('off');
end

app = struct();
app.figure = fig;
app.axes = ax;

    function makeLabel(textValue, x, y)
        uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [x y 0.16 0.026], 'BackgroundColor', 'w', ...
            'HorizontalAlignment', 'left', 'String', textValue);
    end

    function slider = makeSlider(minValue, maxValue, value, x, y)
        slider = uicontrol(fig, 'Style', 'slider', 'Units', 'normalized', ...
            'Position', [x y 0.070 0.032], 'Min', minValue, 'Max', maxValue, ...
            'Value', value, 'SliderStep', [1 / (maxValue - minValue), 20 / (maxValue - minValue)], ...
            'Callback', @updateFromControls);
    end

    function editHandle = makeValueEdit(value, x, y)
        editHandle = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
            'Position', [x y 0.040 0.032], 'BackgroundColor', 'w', ...
            'HorizontalAlignment', 'center', 'String', sprintf('%d', value), ...
            'Callback', @updateFromEdit);
    end

    function makeStepButton(label, x, y, index, step)
        uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [x y 0.022 0.032], 'String', label, ...
            'Callback', @(~, ~) bumpWindow(index, step));
    end

    function loadFileFromDialog(~, ~)
        startFolder = getFolderPref('lastSmoothInputPath', pwd);
        if ~isempty(state.inputFile)
            startFolder = fileparts(state.inputFile);
        end
        [fileName, pathName] = uigetfile({'*.txt;*.dat;*.csv', 'A-B data files'}, ...
            'Select A-B data file', startFolder);
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastSmoothInputPath', pathName);
        loadFile(fullfile(pathName, fileName));
    end

    function loadFile(filePath)
        try
            trace = usTASReadABTxt(filePath);
        catch ME
            set(statusText, 'String', sprintf('Failed to load file:\n%s', ME.message));
            return;
        end

        state.inputFile = filePath;
        if isempty(state.outputFolder)
            state.outputFolder = fileparts(filePath);
        end
        state.hasData = true;
        state.time = trace.time;
        state.timeUs = trace.time .* 1e6;
        state.raw = trace.signal;
        state.smoothed = trace.signal;
        state.finalSignal = trace.signal;
        state.baselineValue = 0;
        state.manualOffset = 0;
        offsetEdit.String = '0';
        set(emptyText, 'Visible', 'off');
        setControlsEnabled('on');
        state.autoAxis = true;
        updateFromControls();
    end

    function setControlsEnabled(value)
        controls = [windowSliders, windowEdits, methodPopup, autoBaselineCheck, ...
            baselinePopup, baselineStartEdit, baselineEndEdit, offsetEdit, ...
            offsetStepEdit, xPopup, yPopup];
        for k = 1:numel(controls)
            controls(k).Enable = value;
        end
    end

    function updateFromControls(~, ~)
        if ~state.hasData
            return;
        end

        state.windowPoints = makeOdd([preSlider.Value, earlySlider.Value, ...
            midSlider.Value, lateSlider.Value]);
        methods = methodPopup.String;
        state.method = methods{methodPopup.Value};
        state.autoBaseline = logical(autoBaselineCheck.Value);
        baselineMethods = baselinePopup.String;
        state.baselineMethod = baselineMethods{baselinePopup.Value};
        state.baselineWindowUs = readBaselineWindow();
        state.manualOffset = readFinite(offsetEdit.String, state.manualOffset);
        offsetEdit.String = sprintf('%.6g', state.manualOffset);
        state.xScale = popupScale(xPopup, 'X');
        state.yScale = popupScale(yPopup, 'Y');

        syncWindowControls();

        opts = struct();
        opts.segmentEdgesUs = state.segmentEdgesUs;
        opts.windowPoints = state.windowPoints;
        opts.method = state.method;
        state.smoothed = usTASSegmentedSmooth(state.time, state.raw, opts);

        if state.autoBaseline
            baselineOpts = struct();
            baselineOpts.baselineWindowUs = state.baselineWindowUs;
            baselineOpts.baselineMethod = state.baselineMethod;
            try
                [autoCorrected, state.baselineValue] = usTASBaselineCorrect( ...
                    state.time, state.smoothed, baselineOpts);
            catch ME
                autoCorrected = state.smoothed;
                state.baselineValue = NaN;
                set(statusText, 'String', sprintf('Baseline correction failed:\n%s', ME.message));
            end
        else
            autoCorrected = state.smoothed;
            state.baselineValue = 0;
        end

        state.finalSignal = autoCorrected + state.manualOffset;

        set(rawLine, 'XData', state.timeUs, 'YData', state.raw);
        set(finalLine, 'XData', state.timeUs, 'YData', state.finalSignal);
        usTASUpdateZeroLine(ax, state.showZeroLine);
        applyScales();
        updateStatus();
        drawnow limitrate;
    end

    function updateFromEdit(source, ~)
        index = find(windowEdits == source, 1);
        if isempty(index)
            return;
        end
        value = str2double(source.String);
        if ~isfinite(value)
            value = state.windowPoints(index);
        end
        setWindowValue(index, value);
        updateFromControls();
    end

    function bumpWindow(index, step)
        setWindowValue(index, state.windowPoints(index) + step);
        updateFromControls();
    end

    function setWindowValue(index, value)
        minValue = windowSliders(index).Min;
        maxValue = windowSliders(index).Max;
        value = min(max(value, minValue), maxValue);
        value = makeOdd(value);
        windowSliders(index).Value = value;
    end

    function syncWindowControls()
        for k = 1:numel(windowSliders)
            value = min(max(state.windowPoints(k), windowSliders(k).Min), windowSliders(k).Max);
            value = makeOdd(value);
            windowSliders(k).Value = value;
            windowEdits(k).String = sprintf('%d', value);
            state.windowPoints(k) = value;
        end
    end

    function values = makeOdd(values)
        values = max(1, round(values));
        values(mod(values, 2) == 0) = values(mod(values, 2) == 0) + 1;
    end

    function window = readBaselineWindow()
        startValue = readFinite(baselineStartEdit.String, state.baselineWindowUs(1));
        endValue = readFinite(baselineEndEdit.String, state.baselineWindowUs(2));
        if startValue > endValue
            temp = startValue;
            startValue = endValue;
            endValue = temp;
        end
        baselineStartEdit.String = sprintf('%g', startValue);
        baselineEndEdit.String = sprintf('%g', endValue);
        window = [startValue endValue];
    end

    function value = readFinite(textValue, fallback)
        value = str2double(textValue);
        if ~isfinite(value)
            value = fallback;
        end
    end

    function scale = popupScale(popup, axisName)
        value = popup.String{popup.Value};
        if contains(value, 'log')
            scale = 'log';
        elseif contains(value, 'linear')
            scale = 'linear';
        else
            error('usTAS:BadScale', 'Unknown %s scale value.', axisName);
        end
    end

    function applyScales()
        set(ax, 'XScale', state.xScale, 'YScale', state.yScale);
        if state.autoAxis
            autoscaleCurrentData();
        end
        box(ax, 'on');
        usTASUpdateZeroLine(ax, state.showZeroLine);
        usTASSyncAxisLimitControls(axisControls);
    end

    function autoscaleCurrentData(axisMode)
        if nargin < 1
            axisMode = 'all';
        end
        if ~state.hasData
            return;
        end
        scaleX = strcmp(axisMode, 'x') || strcmp(axisMode, 'all');
        scaleY = strcmp(axisMode, 'y') || strcmp(axisMode, 'all');
        xData = state.timeUs(:);
        yData = [state.raw(:); state.finalSignal(:)];
        if strcmp(state.xScale, 'log')
            xData = xData(xData > 0 & isfinite(xData));
        else
            xData = xData(isfinite(xData));
        end
        if strcmp(state.yScale, 'log')
            yData = yData(yData > 0 & isfinite(yData));
        else
            yData = yData(isfinite(yData));
        end
        if scaleX && ~isempty(xData)
            xlim(ax, paddedLimits(xData, strcmp(state.xScale, 'log')));
        end
        if scaleY && ~isempty(yData)
            ylim(ax, paddedLimits(yData, strcmp(state.yScale, 'log')));
        end
        usTASSyncAxisLimitControls(axisControls);
    end

    function limits = paddedLimits(values, isLog)
        minValue = min(values);
        maxValue = max(values);
        if isLog
            minValue = max(minValue, realmin);
            if minValue == maxValue
                limits = [minValue / 1.2, maxValue * 1.2];
            else
                logLimits = log10([minValue maxValue]);
                pad = diff(logLimits) * 0.04;
                limits = 10 .^ [logLimits(1) - pad, logLimits(2) + pad];
            end
            return;
        end
        if minValue == maxValue
            delta = max(abs(minValue) * 0.1, eps);
        else
            delta = (maxValue - minValue) * 0.04;
        end
        limits = [minValue - delta, maxValue + delta];
    end

    function scaleChanged(~, ~)
        state.autoAxis = true;
        updateFromControls();
    end

    function setManualAxisMode()
        state.autoAxis = false;
    end

    function setZeroLineVisible(showLine)
        state.showZeroLine = showLine;
        usTASUpdateZeroLine(ax, state.showZeroLine);
    end

    function autoScaleAxes(~, ~)
        state.autoAxis = true;
        autoscaleCurrentData();
        usTASSyncAxisLimitControls(axisControls);
    end

    function autoScaleFromAxisControls(axisMode)
        state.autoAxis = strcmp(axisMode, 'all');
        autoscaleCurrentData(axisMode);
        usTASSyncAxisLimitControls(axisControls);
    end

    function scrollZoom(~, event)
        if ~state.hasData
            return;
        end
        if event.VerticalScrollCount > 0
            zoomAxes(1.25);
        else
            zoomAxes(0.80);
        end
    end

    function zoomAxes(factor)
        if ~state.hasData
            return;
        end
        state.autoAxis = false;
        zoomOneAxis('x', factor);
        zoomOneAxis('y', factor);
        usTASSyncAxisLimitControls(axisControls);
    end

    function zoomOneAxis(axisName, factor)
        if axisName == 'x'
            limits = xlim(ax);
            isLog = strcmp(state.xScale, 'log');
        else
            limits = ylim(ax);
            isLog = strcmp(state.yScale, 'log');
        end

        if isLog && all(limits > 0)
            center = mean(log10(limits));
            halfRange = diff(log10(limits)) * factor / 2;
            newLimits = 10 .^ [center - halfRange, center + halfRange];
        else
            center = mean(limits);
            halfRange = diff(limits) * factor / 2;
            newLimits = [center - halfRange, center + halfRange];
        end

        if axisName == 'x'
            xlim(ax, newLimits);
        else
            ylim(ax, newLimits);
        end
    end

    function step = offsetStep()
        step = str2double(offsetStepEdit.String);
        if ~isfinite(step) || step <= 0
            step = 1e-5;
            offsetStepEdit.String = '1e-5';
        end
    end

    function bumpOffset(delta)
        state.manualOffset = state.manualOffset + delta;
        offsetEdit.String = sprintf('%.6g', state.manualOffset);
        updateFromControls();
    end

    function updateStatus()
        if ~state.hasData
            set(statusText, 'String', 'No file loaded.');
            return;
        end

        rawStd = std(state.raw - state.finalSignal, 'omitnan');
        if state.autoBaseline
            baselineText = sprintf('%s baseline %.4g from %.4g to %.4g us', ...
                state.baselineMethod, state.baselineValue, ...
                state.baselineWindowUs(1), state.baselineWindowUs(2));
        else
            baselineText = 'auto baseline off';
        end
        msg = sprintf(['Input: %s\nMethod: %s | Windows: [%d %d %d %d] points\n' ...
            '%s | manual offset %.4g | residual std(raw-final): %.4g'], ...
            state.inputFile, state.method, state.windowPoints(1), state.windowPoints(2), ...
            state.windowPoints(3), state.windowPoints(4), baselineText, ...
            state.manualOffset, rawStd);
        if strcmp(state.yScale, 'log') && any([state.raw(:); state.finalSignal(:)] <= 0)
            msg = sprintf('%s\nY log scale hides non-positive values.', msg);
        end
        if strcmp(state.xScale, 'log') && any(state.timeUs <= 0)
            msg = sprintf('%s\nX log scale shows only positive time values.', msg);
        end
        set(statusText, 'String', msg);
    end

    function exportData(~, ~)
        if ~state.hasData
            set(statusText, 'String', 'Load a file before exporting.');
            return;
        end
        [~, name] = fileparts(state.inputFile);
        defaultFolder = getFolderPref('lastSmoothExportPath', state.outputFolder);
        defaultName = fullfile(defaultFolder, [name '-smoothed.txt']);
        [fileName, pathName] = uiputfile('*.txt', 'Save smoothed data', defaultName);
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastSmoothExportPath', pathName);
        state.outputFolder = pathName;
        outFile = fullfile(pathName, fileName);
        out = [state.time(:), state.raw(:), state.smoothed(:), state.finalSignal(:)];
        writematrix(out, outFile, 'Delimiter', 'tab', 'FileType', 'text');
        set(statusText, 'String', sprintf('Saved smoothed data:\n%s', outFile));
    end

    function saveFigure(~, ~)
        if ~state.hasData
            set(statusText, 'String', 'Load a file before saving the figure.');
            return;
        end
        [~, name] = fileparts(state.inputFile);
        defaultFolder = getFolderPref('lastSmoothExportPath', state.outputFolder);
        defaultName = fullfile(defaultFolder, [name '-smooth-qc.png']);
        [fileName, pathName] = uiputfile('*.png', 'Save QC figure', defaultName);
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastSmoothExportPath', pathName);
        state.outputFolder = pathName;
        exportgraphics(fig, fullfile(pathName, fileName), 'Resolution', 180);
    end

    function folder = getFolderPref(name, fallback)
        folder = fallback;
        if ispref(prefGroup, name)
            candidate = getpref(prefGroup, name);
            if ischar(candidate) || isstring(candidate)
                if exist(candidate, 'dir')
                    folder = char(candidate);
                end
            end
        end
    end

    function setFolderPref(name, folder)
        if ischar(folder) || isstring(folder)
            if exist(folder, 'dir')
                setpref(prefGroup, name, char(folder));
            end
        end
    end

    function startFigureDrag(~, ~)
        hitObject = hittest(fig);
        if hitObject ~= fig
            return;
        end
        state.draggingFigure = true;
        state.dragStartPointer = get(0, 'PointerLocation');
        state.dragStartPosition = fig.Position;
    end

    function dragFigure(~, ~)
        if ~state.draggingFigure
            return;
        end
        pointer = get(0, 'PointerLocation');
        delta = pointer - state.dragStartPointer;
        fig.Position = state.dragStartPosition + [delta 0 0];
    end

    function stopFigureDrag(~, ~)
        state.draggingFigure = false;
    end
end
