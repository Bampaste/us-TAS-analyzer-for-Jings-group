function app = usTASKineticsCompareViewer(inputFiles)
%USTASKINETICSCOMPAREVIEWER Compare multiple smoothed us-TAS kinetics.

if nargin < 1
    inputFiles = {};
end
if ischar(inputFiles) || isstring(inputFiles)
    inputFiles = cellstr(inputFiles);
end

state = struct();
state.traces = struct('filePath', {}, 'label', {}, 'time', {}, 'timeUs', {}, ...
    'signal', {}, 'visible', {}, 'normFactor', {}, 'normalized', {});
state.normalizeOn = false;
state.normalizeMode = 'none';
state.normalizeValue = 1;
state.xScale = 'linear';
state.yScale = 'linear';
state.autoAxis = true;
state.showZeroLine = true;
state.colors = lines(32);
state.draggingFigure = false;
state.dragStartPointer = [];
state.dragStartPosition = [];
prefGroup = 'usTASPipeline';

fig = figure('Name', 'us-TAS kinetics compare', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [120 90 1280 760], ...
    'WindowScrollWheelFcn', @scrollZoom, ...
    'WindowButtonDownFcn', @startFigureDrag, ...
    'WindowButtonMotionFcn', @dragFigure, ...
    'WindowButtonUpFcn', @stopFigureDrag);

fileMenu = uimenu(fig, 'Text', 'File');
uimenu(fileMenu, 'Text', 'Add kinetics files...', 'MenuSelectedFcn', @addFilesFromDialog);
uimenu(fileMenu, 'Text', 'Export plotted data...', 'MenuSelectedFcn', @exportPlottedData);
uimenu(fileMenu, 'Text', 'Clear all', 'MenuSelectedFcn', @clearAll);
uimenu(fileMenu, 'Text', 'Save figure...', 'MenuSelectedFcn', @saveFigure);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.33 0.66 0.60]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Time (\mus)');
ylabel(ax, 'Signal');
hold(ax, 'on');
usTASUpdateZeroLine(ax, state.showZeroLine);
text(ax, 0.5, 0.5, 'Add smoothed kinetics files to compare', ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 16, 'Color', [0.35 0.35 0.35]);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.91 0.17 0.045], 'String', 'Add kinetics files', ...
    'Callback', @addFilesFromDialog);

makeLabel('Show / label', 0.78, 0.86);
traceTable = uitable(fig, 'Units', 'normalized', 'Position', [0.78 0.54 0.19 0.31], ...
    'Data', cell(0, 2), 'ColumnName', {'Show', 'Label'}, ...
    'ColumnFormat', {'logical', 'char'}, 'ColumnEditable', [true true], ...
    'ColumnWidth', {45, 165}, 'CellEditCallback', @tableEdited);

normalizeCheck = uicontrol(fig, 'Style', 'checkbox', 'Units', 'normalized', ...
    'Position', [0.78 0.49 0.17 0.035], 'String', 'Normalize', ...
    'BackgroundColor', 'w', 'Value', state.normalizeOn, ...
    'Callback', @updateFromControls);

makeLabel('Normalize by', 0.78, 0.45);
normalizePopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.78 0.415 0.17 0.035], ...
    'String', {'fixed value', 'signal at time (us)'}, ...
    'Callback', @updateFromControls);

normalizeEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.78 0.375 0.11 0.035], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'center', 'String', '1', ...
    'Callback', @updateFromControls);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.90 0.375 0.05 0.035], 'String', 'Apply', ...
    'Callback', @updateFromControls);

makeLabel('Axes', 0.78, 0.325);
xPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.78 0.290 0.080 0.035], 'String', {'linear X', 'log X'}, ...
    'Callback', @scaleChanged);
yPopup = uicontrol(fig, 'Style', 'popupmenu', 'Units', 'normalized', ...
    'Position', [0.87 0.290 0.080 0.035], 'String', {'linear Y', 'log Y'}, ...
    'Callback', @scaleChanged);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.245 0.052 0.035], 'String', 'Zoom +', ...
    'Callback', @(~, ~) zoomAxes(0.75));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.838 0.245 0.052 0.035], 'String', 'Zoom -', ...
    'Callback', @(~, ~) zoomAxes(1.35));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.896 0.245 0.052 0.035], 'String', 'Auto', ...
    'Callback', @autoScaleAxes);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.195 0.080 0.035], 'String', 'Show all', ...
    'Callback', @(~, ~) setAllVisible(true));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.87 0.195 0.080 0.035], 'String', 'Hide all', ...
    'Callback', @(~, ~) setAllVisible(false));

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.145 0.080 0.035], 'String', 'Clear', ...
    'Callback', @clearAll);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.87 0.145 0.080 0.035], 'String', 'Export', ...
    'Callback', @exportPlottedData);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.100 0.170 0.035], 'String', 'Save figure', ...
    'Callback', @saveFigure);

statusText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.06 0.66 0.13], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'No kinetics loaded.');
axisControls = usTASCreateAxisLimitControls(fig, ax, [0.08 0.195 0.66 0.050], ...
    @setManualAxisMode, @autoScaleFromAxisControls, @setZeroLineVisible, state.showZeroLine);

if ~isempty(inputFiles)
    addFiles(inputFiles);
end

app = struct();
app.figure = fig;
app.axes = ax;

    function makeLabel(textValue, x, y)
        uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [x y 0.17 0.026], 'BackgroundColor', 'w', ...
            'HorizontalAlignment', 'left', 'String', textValue);
    end

    function addFilesFromDialog(~, ~)
        startFolder = getFolderPref('lastCompareInputPath', pwd);
        [fileName, pathName] = uigetfile({'*.txt;*.dat;*.csv', 'Kinetics files'}, ...
            'Select smoothed kinetics files', startFolder, 'MultiSelect', 'on');
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastCompareInputPath', pathName);
        if ischar(fileName)
            fileName = {fileName};
        end
        files = cellfun(@(name) fullfile(pathName, name), fileName, 'UniformOutput', false);
        addFiles(files);
    end

    function addFiles(files)
        for i = 1:numel(files)
            try
                trace = usTASReadSmoothedKinetics(files{i});
                state.traces(end + 1) = trace;
            catch ME
                set(statusText, 'String', sprintf('Failed to load:\n%s\n%s', files{i}, ME.message));
            end
        end
        state.autoAxis = true;
        refreshTable();
        updateFromControls();
    end

    function refreshTable()
        data = cell(numel(state.traces), 2);
        for i = 1:numel(state.traces)
            data{i, 1} = state.traces(i).visible;
            data{i, 2} = state.traces(i).label;
        end
        traceTable.Data = data;
    end

    function tableEdited(source, event)
        row = event.Indices(1);
        col = event.Indices(2);
        if row > numel(state.traces)
            return;
        end
        if col == 1
            state.traces(row).visible = logical(source.Data{row, col});
        elseif col == 2
            state.traces(row).label = char(source.Data{row, col});
        end
        state.autoAxis = true;
        plotTraces();
    end

    function updateFromControls(~, ~)
        state.normalizeOn = logical(normalizeCheck.Value);
        modes = normalizePopup.String;
        selectedMode = modes{normalizePopup.Value};
        if contains(selectedMode, 'time')
            state.normalizeMode = 'time';
        else
            state.normalizeMode = 'fixed';
        end
        value = str2double(normalizeEdit.String);
        if ~isfinite(value)
            value = state.normalizeValue;
        end
        state.normalizeValue = value;
        normalizeEdit.String = sprintf('%.6g', state.normalizeValue);
        state.xScale = popupScale(xPopup);
        state.yScale = popupScale(yPopup);

        applyNormalization();
        plotTraces();
    end

    function applyNormalization()
        for i = 1:numel(state.traces)
            y = state.traces(i).signal;
            factor = 1;
            if state.normalizeOn
                if strcmp(state.normalizeMode, 'fixed')
                    factor = state.normalizeValue;
                else
                    [~, idx] = min(abs(state.traces(i).timeUs - state.normalizeValue));
                    factor = y(idx);
                end
            end
            if ~isfinite(factor) || factor == 0
                factor = 1;
            end
            state.traces(i).normFactor = factor;
            state.traces(i).normalized = y ./ factor;
        end
    end

    function plotTraces()
        cla(ax);
        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'Time (\mus)');
        if state.normalizeOn
            ylabel(ax, 'Normalized signal');
        else
            ylabel(ax, 'Signal');
        end

        visibleCount = 0;
        for i = 1:numel(state.traces)
            if ~state.traces(i).visible
                continue;
            end
            color = state.colors(mod(i - 1, size(state.colors, 1)) + 1, :);
            plot(ax, state.traces(i).timeUs, state.traces(i).normalized, ...
                'LineWidth', 1.25, 'Color', color, 'DisplayName', state.traces(i).label);
            visibleCount = visibleCount + 1;
        end

        if visibleCount == 0
            text(ax, 0.5, 0.5, 'No visible kinetics selected', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 14, 'Color', [0.35 0.35 0.35]);
        else
            legend(ax, 'Location', 'best');
        end

        set(ax, 'XScale', state.xScale, 'YScale', state.yScale);
        usTASUpdateZeroLine(ax, state.showZeroLine);
        if state.autoAxis
            autoscaleCurrentData();
        end
        usTASSyncAxisLimitControls(axisControls);
        updateStatus();
        drawnow limitrate;
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

    function scale = popupScale(popup)
        value = popup.String{popup.Value};
        if contains(value, 'log')
            scale = 'log';
        else
            scale = 'linear';
        end
    end

    function setAllVisible(value)
        for i = 1:numel(state.traces)
            state.traces(i).visible = value;
        end
        state.autoAxis = true;
        refreshTable();
        plotTraces();
    end

    function clearAll(~, ~)
        state.traces = state.traces([]);
        state.autoAxis = true;
        refreshTable();
        cla(ax);
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'Time (\mus)');
        ylabel(ax, 'Signal');
        usTASUpdateZeroLine(ax, state.showZeroLine);
        text(ax, 0.5, 0.5, 'Add smoothed kinetics files to compare', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 16, 'Color', [0.35 0.35 0.35]);
        set(statusText, 'String', 'No kinetics loaded.');
    end

    function autoscaleCurrentData(axisMode)
        if nargin < 1
            axisMode = 'all';
        end
        allX = [];
        allY = [];
        for i = 1:numel(state.traces)
            if ~state.traces(i).visible
                continue;
            end
            allX = [allX; state.traces(i).timeUs(:)]; %#ok<AGROW>
            allY = [allY; state.traces(i).normalized(:)]; %#ok<AGROW>
        end
        if isempty(allX)
            return;
        end
        scaleX = strcmp(axisMode, 'x') || strcmp(axisMode, 'all');
        scaleY = strcmp(axisMode, 'y') || strcmp(axisMode, 'all');
        if strcmp(state.xScale, 'log')
            allX = allX(allX > 0 & isfinite(allX));
        else
            allX = allX(isfinite(allX));
        end
        if strcmp(state.yScale, 'log')
            allY = allY(allY > 0 & isfinite(allY));
        else
            allY = allY(isfinite(allY));
        end
        if scaleX && ~isempty(allX)
            xlim(ax, paddedLimits(allX, strcmp(state.xScale, 'log')));
        end
        if scaleY && ~isempty(allY)
            ylim(ax, paddedLimits(allY, strcmp(state.yScale, 'log')));
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
        if isempty(state.traces)
            return;
        end
        if event.VerticalScrollCount > 0
            zoomAxes(1.25);
        else
            zoomAxes(0.80);
        end
    end

    function zoomAxes(factor)
        if isempty(state.traces)
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

    function updateStatus()
        count = numel(state.traces);
        visibleCount = sum([state.traces.visible]);
        if count == 0
            set(statusText, 'String', 'No kinetics loaded.');
            return;
        end
        if state.normalizeOn && strcmp(state.normalizeMode, 'time')
            normText = sprintf('normalized by signal at %.6g us', state.normalizeValue);
        elseif state.normalizeOn
            normText = sprintf('normalized by fixed value %.6g', state.normalizeValue);
        else
            normText = 'normalization off';
        end
        msg = sprintf('%d kinetics loaded, %d visible | %s', count, visibleCount, normText);
        if strcmp(state.yScale, 'log')
            msg = sprintf('%s\nY log scale hides non-positive values.', msg);
        end
        if strcmp(state.xScale, 'log')
            msg = sprintf('%s\nX log scale shows only positive time values.', msg);
        end
        set(statusText, 'String', msg);
    end

    function exportPlottedData(~, ~)
        visibleIdx = find([state.traces.visible]);
        if isempty(visibleIdx)
            set(statusText, 'String', 'No visible kinetics to export.');
            return;
        end

        defaultFolder = getFolderPref('lastCompareExportPath', pwd);
        defaultName = fullfile(defaultFolder, 'kinetics-comparison-data.txt');
        [fileName, pathName] = uiputfile('*.txt', 'Export plotted kinetics data', defaultName);
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastCompareExportPath', pathName);

        maxLen = 0;
        for k = visibleIdx
            maxLen = max(maxLen, numel(state.traces(k).timeUs));
        end

        out = nan(maxLen, numel(visibleIdx) * 2);
        headers = cell(1, numel(visibleIdx) * 2);
        for i = 1:numel(visibleIdx)
            k = visibleIdx(i);
            n = numel(state.traces(k).timeUs);
            col = (i - 1) * 2 + 1;
            label = matlab.lang.makeValidName(state.traces(k).label);
            out(1:n, col) = state.traces(k).timeUs(:);
            out(1:n, col + 1) = state.traces(k).normalized(:);
            headers{col} = [label '_time_us'];
            headers{col + 1} = [label '_signal'];
        end

        outFile = fullfile(pathName, fileName);
        writeTableWithHeader(outFile, headers, out);
        set(statusText, 'String', sprintf('Exported visible plotted data:\n%s', outFile));
    end

    function saveFigure(~, ~)
        defaultFolder = getFolderPref('lastCompareExportPath', pwd);
        [fileName, pathName] = uiputfile('*.png', 'Save comparison figure', ...
            fullfile(defaultFolder, 'kinetics-comparison.png'));
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastCompareExportPath', pathName);
        exportgraphics(fig, fullfile(pathName, fileName), 'Resolution', 180);
    end

    function writeTableWithHeader(filePath, headers, data)
        fid = fopen(filePath, 'w');
        if fid < 0
            error('usTAS:ExportFailed', 'Unable to open %s for writing.', filePath);
        end
        cleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '%s\n', strjoin(headers, sprintf('\t')));
        format = [repmat('%.15g\t', 1, size(data, 2) - 1), '%.15g\n'];
        for row = 1:size(data, 1)
            fprintf(fid, format, data(row, :));
        end
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
