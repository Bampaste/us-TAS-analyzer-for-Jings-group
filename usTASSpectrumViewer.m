function app = usTASSpectrumViewer(inputFiles)
%USTASSPECTRUMVIEWER Build wavelength spectra from multiple kinetics.

if nargin < 1
    inputFiles = {};
end
if ischar(inputFiles) || isstring(inputFiles)
    inputFiles = cellstr(inputFiles);
end

state = struct();
state.traces = struct('filePath', {}, 'label', {}, 'wavelengthNm', {}, ...
    'timeUs', {}, 'signal', {}, 'keep', {});
state.requests = struct('kind', {'point', 'point', 'point', 'point', 'point'}, ...
    'startUs', {0, 1, 10, 50, 100}, 'endUs', {0, 1, 10, 50, 100}, ...
    'label', {'0 us', '1 us', '10 us', '50 us', '100 us'});
state.colors = lines(32);
state.autoAxis = true;
state.showZeroLine = true;
state.draggingFigure = false;
state.dragStartPointer = [];
state.dragStartPosition = [];
prefGroup = 'usTASPipeline';

fig = figure('Name', 'us-TAS spectrum builder', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [140 80 1280 760], ...
    'WindowScrollWheelFcn', @scrollZoom, ...
    'WindowButtonDownFcn', @startFigureDrag, ...
    'WindowButtonMotionFcn', @dragFigure, ...
    'WindowButtonUpFcn', @stopFigureDrag);

fileMenu = uimenu(fig, 'Text', 'File');
uimenu(fileMenu, 'Text', 'Add kinetics files...', 'MenuSelectedFcn', @addFilesFromDialog);
uimenu(fileMenu, 'Text', 'Export spectrum data...', 'MenuSelectedFcn', @exportSpectrumData);
uimenu(fileMenu, 'Text', 'Clear all', 'MenuSelectedFcn', @clearAll);
uimenu(fileMenu, 'Text', 'Save figure...', 'MenuSelectedFcn', @saveFigure);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.33 0.66 0.60]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Wavelength (nm)');
ylabel(ax, '\DeltaOD');
hold(ax, 'on');
usTASUpdateZeroLine(ax, state.showZeroLine);
text(ax, 0.5, 0.5, 'Add smoothed kinetics files to build spectra', ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 16, 'Color', [0.35 0.35 0.35]);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.91 0.17 0.045], 'String', 'Add kinetics files', ...
    'Callback', @addFilesFromDialog);

makeLabel('Keep / wavelength / label', 0.78, 0.86);
traceTable = uitable(fig, 'Units', 'normalized', 'Position', [0.78 0.48 0.20 0.37], ...
    'Data', cell(0, 3), 'ColumnName', {'Keep', 'nm', 'Label'}, ...
    'ColumnFormat', {'logical', 'numeric', 'char'}, ...
    'ColumnEditable', [true true true], 'ColumnWidth', {45, 55, 170}, ...
    'CellEditCallback', @tableEdited);

makeLabel('Spectrum times/windows (us)', 0.78, 0.43);
timesEdit = uicontrol(fig, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.78 0.315 0.17 0.115], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'Max', 8, 'Min', 1, ...
    'String', sprintf('1 2\n3 5\n10\n50\n100'), 'Callback', @updateFromControls);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.955 0.395 0.025 0.035], 'String', 'Go', ...
    'Callback', @updateFromControls);

makeLabel('Axes', 0.78, 0.275);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.240 0.052 0.035], 'String', 'Zoom +', ...
    'Callback', @(~, ~) zoomAxes(0.75));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.838 0.240 0.052 0.035], 'String', 'Zoom -', ...
    'Callback', @(~, ~) zoomAxes(1.35));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.896 0.240 0.052 0.035], 'String', 'Auto', ...
    'Callback', @autoScaleAxes);

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.195 0.080 0.035], 'String', 'Keep all', ...
    'Callback', @(~, ~) setAllKeep(true));
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.87 0.195 0.080 0.035], 'String', 'Hide all', ...
    'Callback', @(~, ~) setAllKeep(false));

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.150 0.080 0.035], 'String', 'Export', ...
    'Callback', @exportSpectrumData);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.87 0.150 0.080 0.035], 'String', 'Save fig', ...
    'Callback', @saveFigure);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.78 0.105 0.17 0.035], 'String', 'Clear', ...
    'Callback', @clearAll);

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
            'Position', [x y 0.19 0.026], 'BackgroundColor', 'w', ...
            'HorizontalAlignment', 'left', 'String', textValue);
    end

    function addFilesFromDialog(~, ~)
        startFolder = getFolderPref('lastSpectrumInputPath', pwd);
        [fileName, pathName] = uigetfile({'*.txt;*.dat;*.csv', 'Kinetics files'}, ...
            'Select smoothed kinetics files', startFolder, 'MultiSelect', 'on');
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastSpectrumInputPath', pathName);
        if ischar(fileName)
            fileName = {fileName};
        end
        files = cellfun(@(name) fullfile(pathName, name), fileName, 'UniformOutput', false);
        addFiles(files);
    end

    function addFiles(files)
        for i = 1:numel(files)
            try
                kinetic = usTASReadSmoothedKinetics(files{i});
                trace = struct();
                trace.filePath = kinetic.filePath;
                trace.label = kinetic.label;
                trace.wavelengthNm = usTASParseWavelength(kinetic.filePath);
                trace.timeUs = kinetic.timeUs;
                trace.signal = kinetic.signal;
                trace.keep = true;
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
        data = cell(numel(state.traces), 3);
        for i = 1:numel(state.traces)
            data{i, 1} = state.traces(i).keep;
            data{i, 2} = state.traces(i).wavelengthNm;
            data{i, 3} = state.traces(i).label;
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
            state.traces(row).keep = logical(source.Data{row, col});
        elseif col == 2
            value = source.Data{row, col};
            if isnumeric(value) && isfinite(value)
                state.traces(row).wavelengthNm = value;
            end
        elseif col == 3
            state.traces(row).label = char(source.Data{row, col});
        end
        state.autoAxis = true;
        plotSpectra();
    end

    function updateFromControls(~, ~)
        requests = parseSpectrumRequests(timesEdit.String);
        if isempty(requests)
            requests = state.requests;
        end
        state.requests = requests;
        timesEdit.String = requestsToText(state.requests);
        state.autoAxis = true;
        plotSpectra();
    end

    function spectra = buildSpectra()
        kept = find([state.traces.keep] & isfinite([state.traces.wavelengthNm]));
        spectra = struct();
        spectra.wavelengths = [];
        spectra.labels = {};
        spectra.values = nan(0, numel(state.requests));
        if isempty(kept)
            return;
        end

        wavelengths = zeros(numel(kept), 1);
        values = nan(numel(kept), numel(state.requests));
        labels = cell(numel(kept), 1);
        for i = 1:numel(kept)
            k = kept(i);
            wavelengths(i) = state.traces(k).wavelengthNm;
            labels{i} = state.traces(k).label;
            for j = 1:numel(state.requests)
                request = state.requests(j);
                if strcmp(request.kind, 'point')
                    values(i, j) = interp1(state.traces(k).timeUs, state.traces(k).signal, ...
                        request.startUs, 'linear', NaN);
                else
                    inWindow = state.traces(k).timeUs >= request.startUs & ...
                        state.traces(k).timeUs <= request.endUs & ...
                        isfinite(state.traces(k).signal);
                    if any(inWindow)
                        values(i, j) = mean(state.traces(k).signal(inWindow), 'omitnan');
                    end
                end
            end
        end

        [wavelengths, order] = sort(wavelengths);
        spectra.wavelengths = wavelengths;
        spectra.values = values(order, :);
        spectra.labels = labels(order);
    end

    function plotSpectra()
        cla(ax);
        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'Wavelength (nm)');
        ylabel(ax, '\DeltaOD');
        spectra = buildSpectra();

        if isempty(spectra.wavelengths)
            text(ax, 0.5, 0.5, 'No selected kinetics with valid wavelengths', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 14, 'Color', [0.35 0.35 0.35]);
            updateStatus();
            return;
        end

        for j = 1:numel(state.requests)
            color = state.colors(mod(j - 1, size(state.colors, 1)) + 1, :);
            if strcmp(state.requests(j).kind, 'window')
                lineStyle = '--s';
                lineWidth = 1.55;
            else
                lineStyle = '-o';
                lineWidth = 1.25;
            end
            plot(ax, spectra.wavelengths, spectra.values(:, j), lineStyle, ...
                'LineWidth', lineWidth, 'MarkerSize', 5, 'Color', color, ...
                'DisplayName', state.requests(j).label);
        end
        legend(ax, 'Location', 'best');
        usTASUpdateZeroLine(ax, state.showZeroLine);
        if state.autoAxis
            autoscaleCurrentData(spectra);
        end
        usTASSyncAxisLimitControls(axisControls);
        updateStatus();
        drawnow limitrate;
    end

    function autoscaleCurrentData(spectra, axisMode)
        if nargin < 1
            spectra = buildSpectra();
        end
        if nargin < 2
            axisMode = 'all';
        end
        if isempty(spectra.wavelengths)
            return;
        end
        scaleX = strcmp(axisMode, 'x') || strcmp(axisMode, 'all');
        scaleY = strcmp(axisMode, 'y') || strcmp(axisMode, 'all');
        if scaleX
            xlim(ax, paddedLimits(spectra.wavelengths));
        end
        y = spectra.values(isfinite(spectra.values));
        if scaleY && ~isempty(y)
            ylim(ax, paddedLimits(y));
        end
        usTASSyncAxisLimitControls(axisControls);
    end

    function limits = paddedLimits(values)
        values = values(isfinite(values));
        minValue = min(values);
        maxValue = max(values);
        if minValue == maxValue
            delta = max(abs(minValue) * 0.1, 1);
        else
            delta = (maxValue - minValue) * 0.06;
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
        autoscaleCurrentData(buildSpectra(), axisMode);
        usTASSyncAxisLimitControls(axisControls);
    end

    function setManualAxisMode()
        state.autoAxis = false;
    end

    function setZeroLineVisible(showLine)
        state.showZeroLine = showLine;
        usTASUpdateZeroLine(ax, state.showZeroLine);
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
        else
            limits = ylim(ax);
        end
        center = mean(limits);
        halfRange = diff(limits) * factor / 2;
        newLimits = [center - halfRange, center + halfRange];
        if axisName == 'x'
            xlim(ax, newLimits);
        else
            ylim(ax, newLimits);
        end
    end

    function setAllKeep(value)
        for i = 1:numel(state.traces)
            state.traces(i).keep = value;
        end
        state.autoAxis = true;
        refreshTable();
        plotSpectra();
    end

    function clearAll(~, ~)
        state.traces = state.traces([]);
        state.autoAxis = true;
        refreshTable();
        cla(ax);
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'Wavelength (nm)');
        ylabel(ax, '\DeltaOD');
        usTASUpdateZeroLine(ax, state.showZeroLine);
        text(ax, 0.5, 0.5, 'Add smoothed kinetics files to build spectra', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontSize', 16, 'Color', [0.35 0.35 0.35]);
        set(statusText, 'String', 'No kinetics loaded.');
    end

    function exportSpectrumData(~, ~)
        spectra = buildSpectra();
        if isempty(spectra.wavelengths)
            set(statusText, 'String', 'No selected spectrum data to export.');
            return;
        end

        defaultFolder = getFolderPref('lastSpectrumExportPath', pwd);
        defaultName = fullfile(defaultFolder, 'spectrum-by-time.txt');
        [fileName, pathName] = uiputfile('*.txt', 'Export spectrum data', defaultName);
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastSpectrumExportPath', pathName);

        headers = [{'wavelength_nm'}, requestHeaders()];
        out = [spectra.wavelengths(:), spectra.values];
        outFile = fullfile(pathName, fileName);
        writeTableWithHeader(outFile, headers, out);
        set(statusText, 'String', sprintf('Exported spectrum data:\n%s', outFile));
    end

    function saveFigure(~, ~)
        defaultFolder = getFolderPref('lastSpectrumExportPath', pwd);
        [fileName, pathName] = uiputfile('*.png', 'Save spectrum figure', ...
            fullfile(defaultFolder, 'spectrum-by-time.png'));
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastSpectrumExportPath', pathName);
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

    function updateStatus()
        count = numel(state.traces);
        kept = sum([state.traces.keep]);
        if count == 0
            set(statusText, 'String', 'No kinetics loaded.');
            return;
        end
        duplicateText = duplicateWavelengthText();
        msg = sprintf('%d kinetics loaded, %d kept | spectra: %s%s', ...
            count, kept, requestLabelsText(), duplicateText);
        set(statusText, 'String', msg);
    end

    function requests = parseSpectrumRequests(textValue)
        if iscell(textValue)
            requestLines = textValue;
        elseif isstring(textValue)
            requestLines = cellstr(textValue);
        elseif ischar(textValue) && size(textValue, 1) > 1
            requestLines = cellstr(textValue);
        else
            requestLines = regexp(char(textValue), '\r\n|\n|\r', 'split');
        end
        requests = struct('kind', {}, 'startUs', {}, 'endUs', {}, 'label', {});
        for lineIndex = 1:numel(requestLines)
            line = strtrim(requestLines{lineIndex});
            if isempty(line)
                continue;
            end
            values = parseRequestLine(line);
            values = values(isfinite(values));
            if isempty(values)
                continue;
            end
            request = struct();
            if numel(values) >= 2
                startUs = values(1);
                endUs = values(2);
                if startUs > endUs
                    temp = startUs;
                    startUs = endUs;
                    endUs = temp;
                end
                request.kind = 'window';
                request.startUs = startUs;
                request.endUs = endUs;
                request.label = sprintf('avg %.6g-%.6g us', startUs, endUs);
            else
                request.kind = 'point';
                request.startUs = values(1);
                request.endUs = values(1);
                request.label = sprintf('%.6g us', values(1));
            end
            requests(end + 1) = request; %#ok<AGROW>
        end
    end

    function textValue = requestsToText(requests)
        outputLines = cell(1, numel(requests));
        for i = 1:numel(requests)
            if strcmp(requests(i).kind, 'window')
                outputLines{i} = sprintf('%.6g %.6g', requests(i).startUs, requests(i).endUs);
            else
                outputLines{i} = sprintf('%.6g', requests(i).startUs);
            end
        end
        textValue = strjoin(outputLines, newline);
    end

    function values = parseRequestLine(line)
        numberPattern = '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?';
        rangePattern = ['^\s*(' numberPattern ')\s*-\s*(' numberPattern ')\s*$'];
        rangeTokens = regexp(line, rangePattern, 'tokens', 'once');
        if ~isempty(rangeTokens)
            values = [str2double(rangeTokens{1}), str2double(rangeTokens{2})];
            return;
        end

        values = sscanf(line, '%f').';
        if numel(values) >= 2
            values = values(1:2);
            return;
        end

        numbers = regexp(line, numberPattern, 'match');
        values = str2double(numbers);
    end

    function headers = requestHeaders()
        headers = cell(1, numel(state.requests));
        for i = 1:numel(state.requests)
            if strcmp(state.requests(i).kind, 'window')
                headers{i} = sprintf('mean_deltaOD_%.6g_to_%.6g_us', ...
                    state.requests(i).startUs, state.requests(i).endUs);
            else
                headers{i} = sprintf('deltaOD_at_%.6g_us', state.requests(i).startUs);
            end
        end
    end

    function textValue = requestLabelsText()
        labels = {state.requests.label};
        textValue = strjoin(labels, ', ');
    end

    function textValue = duplicateWavelengthText()
        wavelengths = [state.traces.wavelengthNm];
        wavelengths = wavelengths(isfinite(wavelengths));
        textValue = '';
        if isempty(wavelengths)
            return;
        end
        uniqueWavelengths = unique(wavelengths);
        duplicateWavelengths = uniqueWavelengths(arrayfun(@(x) sum(wavelengths == x) > 1, uniqueWavelengths));
        if ~isempty(duplicateWavelengths)
            textValue = sprintf('\nDuplicate wavelengths: %s. Select which replicate to keep in the table.', ...
                strtrim(sprintf('%.6g ', duplicateWavelengths)));
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
