function usTASSyncAxisLimitControls(controls)
%USTASSYNCAXISLIMITCONTROLS Update edit boxes from current axes limits.

if ~isstruct(controls) || ~isfield(controls, 'ax') || ~isgraphics(controls.ax)
    return;
end

xLimits = xlim(controls.ax);
yLimits = ylim(controls.ax);

setIfValid(controls.xMinEdit, xLimits(1));
setIfValid(controls.xMaxEdit, xLimits(2));
setIfValid(controls.yMinEdit, yLimits(1));
setIfValid(controls.yMaxEdit, yLimits(2));
end

function setIfValid(handle, value)
if isgraphics(handle)
    handle.String = sprintf('%.6g', value);
end
end
