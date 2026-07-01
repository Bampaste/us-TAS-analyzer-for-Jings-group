% run_smoothing_viewer
% Open an empty viewer, then load an existing A-B file from the menu/button.

outputFolder = fullfile(fileparts(mfilename('fullpath')), 'smoothed_output');

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

usTASSmoothViewer('', outputFolder);
