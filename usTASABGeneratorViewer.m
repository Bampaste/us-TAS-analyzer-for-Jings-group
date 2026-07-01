function app = usTASABGeneratorViewer()
%USTASABGENERATORVIEWER Generate A-B files directly from A/B track CSV files.

state = struct();
prefGroup = 'usTASPipeline';
state.aFile = '';
state.bFile = '';
state.outputFolder = getFolderPref('lastABExportPath', pwd);
state.lastInputFolder = getFolderPref('lastABInputPath', pwd);
state.result = [];
state.showZeroLine = true;
state.draggingFigure = false;
state.dragStartPointer = [];
state.dragStartPosition = [];

fig = figure('Name', 'us-TAS A-B generator', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [220 180 900 520], ...
    'WindowButtonDownFcn', @startFigureDrag, ...
    'WindowButtonMotionFcn', @dragFigure, ...
    'WindowButtonUpFcn', @stopFigureDrag);

fileMenu = uimenu(fig, 'Text', 'File');
uimenu(fileMenu, 'Text', 'Select wavelength folder...', 'MenuSelectedFcn', @selectFolder);
uimenu(fileMenu, 'Text', 'Select A track...', 'MenuSelectedFcn', @selectAFile);
uimenu(fileMenu, 'Text', 'Select B track...', 'MenuSelectedFcn', @selectBFile);
uimenu(fileMenu, 'Text', 'Generate A-B', 'Separator', 'on', 'MenuSelectedFcn', @generateAB);
uimenu(fileMenu, 'Text', 'Save figure...', 'MenuSelectedFcn', @saveFigure);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.34 0.62 0.55]);
grid(ax, 'on');
box(ax, 'on');
xlabel(ax, 'Time (\mus)');
ylabel(ax, 'Signal (V)');
hold(ax, 'on');
usTASUpdateZeroLine(ax, state.showZeroLine);
text(ax, 0.5, 0.5, 'Select A/B track files or a wavelength folder', ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'Color', [0.35 0.35 0.35]);

uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.91 0.86 0.05], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'FontSize', 14, 'FontWeight', 'bold', ...
    'String', 'Generate A-B = A track - B track');

uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.74 0.82 0.20 0.05], 'String', 'Select folder', ...
    'Callback', @selectFolder);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.74 0.74 0.20 0.05], 'String', 'Select A track', ...
    'Callback', @selectAFile);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.74 0.66 0.20 0.05], 'String', 'Select B track', ...
    'Callback', @selectBFile);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.74 0.56 0.20 0.06], 'String', 'Generate A-B', ...
    'Callback', @generateAB);
uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
    'Position', [0.74 0.48 0.20 0.05], 'String', 'Save figure', ...
    'Callback', @saveFigure);

aText = makeInfoText(0.74, 0.36, 'A: none');
bText = makeInfoText(0.74, 0.28, 'B: none');
outText = makeInfoText(0.74, 0.20, sprintf('Output: %s', state.outputFolder));

statusText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.07 0.86 0.12], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'Ready.');
axisControls = usTASCreateAxisLimitControls(fig, ax, [0.08 0.200 0.62 0.060], ...
    [], [], @setZeroLineVisible, state.showZeroLine);

app = struct();
app.figure = fig;

    function handle = makeInfoText(x, y, label)
        handle = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [x y 0.20 0.07], 'BackgroundColor', 'w', ...
            'HorizontalAlignment', 'left', 'String', label);
    end

    function selectFolder(~, ~)
        folder = uigetdir(state.lastInputFolder, 'Select wavelength folder containing A/B tracks');
        if isequal(folder, 0)
            return;
        end
        state.lastInputFolder = folder;
        setFolderPref('lastABInputPath', folder);
        aCandidate = findTrackFile(folder, 'A track.csv');
        bCandidate = findTrackFile(folder, 'B track.csv');
        if ~isempty(aCandidate)
            state.aFile = aCandidate;
        end
        if ~isempty(bCandidate)
            state.bFile = bCandidate;
        end
        if isempty(state.outputFolder) || ~exist(state.outputFolder, 'dir')
            state.outputFolder = folder;
        end
        refreshFileText();
    end

    function selectAFile(~, ~)
        filePath = selectTrackFile('Select A track CSV');
        if isempty(filePath)
            return;
        end
        state.aFile = filePath;
        refreshFileText();
    end

    function selectBFile(~, ~)
        filePath = selectTrackFile('Select B track CSV');
        if isempty(filePath)
            return;
        end
        state.bFile = filePath;
        refreshFileText();
    end

    function filePath = selectTrackFile(titleText)
        [fileName, pathName] = uigetfile({'*.csv', 'CSV files'}, titleText, state.lastInputFolder);
        if isequal(fileName, 0)
            filePath = '';
            return;
        end
        state.lastInputFolder = pathName;
        setFolderPref('lastABInputPath', pathName);
        filePath = fullfile(pathName, fileName);
    end

    function generateAB(~, ~)
        if isempty(state.aFile) || isempty(state.bFile)
            set(statusText, 'String', 'Select both A track and B track first.');
            return;
        end

        defaultFolder = getFolderPref('lastABExportPath', fileparts(state.aFile));
        defaultName = defaultOutputName(state.aFile);
        [fileName, pathName] = uiputfile('*.txt', 'Save generated A-B file', ...
            fullfile(defaultFolder, defaultName));
        if isequal(fileName, 0)
            return;
        end
        state.outputFolder = pathName;
        setFolderPref('lastABExportPath', pathName);

        outFile = fullfile(pathName, fileName);
        try
            state.result = usTASGenerateAB(state.aFile, state.bFile, outFile);
        catch ME
            set(statusText, 'String', sprintf('A-B generation failed:\n%s', ME.message));
            return;
        end
        refreshFileText();
        plotResult();
        set(statusText, 'String', sprintf('Generated A-B file:\n%s', outFile));
    end

    function plotResult()
        cla(ax);
        hold(ax, 'on');
        grid(ax, 'on');
        box(ax, 'on');
        tUs = state.result.time .* 1e6;
        plot(ax, tUs, state.result.aSignal, 'Color', [0.55 0.55 0.55], 'DisplayName', 'A track');
        plot(ax, tUs, state.result.bSignal, 'Color', [0.85 0.35 0.15], 'DisplayName', 'B track');
        plot(ax, tUs, state.result.abSignal, 'Color', [0 0.25 0.95], 'LineWidth', 1.2, ...
            'DisplayName', 'A-B');
        xlabel(ax, 'Time (\mus)');
        ylabel(ax, 'Signal (V)');
        legend(ax, 'Location', 'best');
        usTASUpdateZeroLine(ax, state.showZeroLine);
        axis(ax, 'tight');
        usTASSyncAxisLimitControls(axisControls);
    end

    function setZeroLineVisible(showLine)
        state.showZeroLine = showLine;
        usTASUpdateZeroLine(ax, state.showZeroLine);
    end

    function saveFigure(~, ~)
        if isempty(state.result)
            set(statusText, 'String', 'Generate A-B before saving the figure.');
            return;
        end
        defaultFolder = getFolderPref('lastABExportPath', state.outputFolder);
        [fileName, pathName] = uiputfile('*.png', 'Save A-B QC figure', ...
            fullfile(defaultFolder, 'generated-A-B-QC.png'));
        if isequal(fileName, 0)
            return;
        end
        setFolderPref('lastABExportPath', pathName);
        exportgraphics(fig, fullfile(pathName, fileName), 'Resolution', 180);
    end

    function refreshFileText()
        set(aText, 'String', sprintf('A: %s', shortName(state.aFile)));
        set(bText, 'String', sprintf('B: %s', shortName(state.bFile)));
        set(outText, 'String', sprintf('Output: %s', state.outputFolder));
    end

    function name = shortName(filePath)
        if isempty(filePath)
            name = 'none';
        else
            [~, nameOnly, ext] = fileparts(filePath);
            name = [nameOnly ext];
        end
    end

    function filePath = findTrackFile(folder, suffix)
        files = dir(fullfile(folder, ['*' suffix]));
        if isempty(files)
            filePath = '';
        else
            filePath = fullfile(folder, files(1).name);
        end
    end

    function name = defaultOutputName(aFile)
        [~, baseName] = fileparts(aFile);
        name = regexprep(baseName, '\s*A track$', '', 'ignorecase');
        name = regexprep(name, '-A track$', '', 'ignorecase');
        if isempty(name)
            name = 'generated';
        end
        name = [name '-A-B.txt'];
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
