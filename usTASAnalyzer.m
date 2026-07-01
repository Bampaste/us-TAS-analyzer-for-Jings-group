function app = usTASAnalyzer()
%USTASANALYZER Main launcher for the us-TAS analysis workflow.

state = struct();
state.abGeneratorApp = [];
state.smoothApp = [];
state.compareApp = [];
state.spectrumApp = [];

fig = figure('Name', 'us-TAS analyzer', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [180 160 720 420], ...
    'MenuBar', 'none', 'ToolBar', 'none');

fileMenu = uimenu(fig, 'Text', 'File');
uimenu(fileMenu, 'Text', 'Open A-B generator', 'MenuSelectedFcn', @openABGenerator);
uimenu(fileMenu, 'Text', 'Open smoothing viewer', 'MenuSelectedFcn', @openSmooth);
uimenu(fileMenu, 'Text', 'Open kinetics compare', 'MenuSelectedFcn', @openCompare);
uimenu(fileMenu, 'Text', 'Open spectrum builder', 'MenuSelectedFcn', @openSpectrum);
uimenu(fileMenu, 'Text', 'Close tool windows', 'Separator', 'on', ...
    'MenuSelectedFcn', @closeToolWindows);
uimenu(fileMenu, 'Text', 'Exit analyzer', 'Separator', 'on', ...
    'MenuSelectedFcn', @closeAnalyzer);

uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.78 0.84 0.12], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'FontSize', 18, 'FontWeight', 'bold', ...
    'String', 'us-TAS analyzer');

uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.68 0.84 0.08], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'FontSize', 10, ...
    'String', 'One entry point for A-B generation, smoothing kinetics, comparing kinetics, and building spectra.');

makeToolButton('1. Generate A-B from tracks', ...
    'Create A-B text files directly from A-track and B-track CSV files.', ...
    [0.08 0.51 0.84 0.105], @openABGenerator);

makeToolButton('2. Smooth A-B kinetics', ...
    'Tune segmented smoothing, optional baseline/offset, and export processed kinetics.', ...
    [0.08 0.38 0.84 0.105], @openSmooth);

makeToolButton('3. Compare kinetics', ...
    'Overlay multiple smoothed kinetics, show/hide traces, normalize, zoom, and export plotted data.', ...
    [0.08 0.25 0.84 0.105], @openCompare);

makeToolButton('4. Build spectra', ...
    'Combine kinetics into wavelength spectra at time points or averaged time windows.', ...
    [0.08 0.12 0.84 0.105], @openSpectrum);

statusText = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.08 0.03 0.84 0.05], 'BackgroundColor', 'w', ...
    'HorizontalAlignment', 'left', 'String', 'Ready.');

app = struct();
app.figure = fig;

    function makeToolButton(titleText, detailText, position, callback)
        panel = uipanel(fig, 'Units', 'normalized', 'Position', position, ...
            'BackgroundColor', [0.97 0.98 0.99], 'BorderType', 'line');
        uicontrol(panel, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.03 0.50 0.70 0.38], 'BackgroundColor', [0.97 0.98 0.99], ...
            'HorizontalAlignment', 'left', 'FontSize', 11, 'FontWeight', 'bold', ...
            'String', titleText);
        uicontrol(panel, 'Style', 'text', 'Units', 'normalized', ...
            'Position', [0.03 0.10 0.70 0.36], 'BackgroundColor', [0.97 0.98 0.99], ...
            'HorizontalAlignment', 'left', 'FontSize', 9, 'String', detailText);
        uicontrol(panel, 'Style', 'pushbutton', 'Units', 'normalized', ...
            'Position', [0.77 0.22 0.18 0.52], 'String', 'Open', ...
            'Callback', callback);
    end

    function openABGenerator(~, ~)
        if isValidApp(state.abGeneratorApp)
            figure(state.abGeneratorApp.figure);
        else
            state.abGeneratorApp = usTASABGeneratorViewer();
        end
        set(statusText, 'String', 'A-B generator opened.');
    end

    function openSmooth(~, ~)
        if isValidApp(state.smoothApp)
            figure(state.smoothApp.figure);
        else
            outputFolder = fullfile(fileparts(mfilename('fullpath')), 'smoothed_output');
            if ~exist(outputFolder, 'dir')
                mkdir(outputFolder);
            end
            state.smoothApp = usTASSmoothViewer('', outputFolder);
        end
        set(statusText, 'String', 'Smoothing viewer opened.');
    end

    function openCompare(~, ~)
        if isValidApp(state.compareApp)
            figure(state.compareApp.figure);
        else
            state.compareApp = usTASKineticsCompareViewer();
        end
        set(statusText, 'String', 'Kinetics compare viewer opened.');
    end

    function openSpectrum(~, ~)
        if isValidApp(state.spectrumApp)
            figure(state.spectrumApp.figure);
        else
            state.spectrumApp = usTASSpectrumViewer();
        end
        set(statusText, 'String', 'Spectrum builder opened.');
    end

    function tf = isValidApp(toolApp)
        tf = isstruct(toolApp) && isfield(toolApp, 'figure') && isgraphics(toolApp.figure);
    end

    function closeToolWindows(~, ~)
        closeIfValid(state.abGeneratorApp);
        closeIfValid(state.smoothApp);
        closeIfValid(state.compareApp);
        closeIfValid(state.spectrumApp);
        state.abGeneratorApp = [];
        state.smoothApp = [];
        state.compareApp = [];
        state.spectrumApp = [];
        set(statusText, 'String', 'Tool windows closed.');
    end

    function closeIfValid(toolApp)
        if isValidApp(toolApp)
            close(toolApp.figure);
        end
    end

    function closeAnalyzer(~, ~)
        closeToolWindows();
        if isgraphics(fig)
            close(fig);
        end
    end
end
