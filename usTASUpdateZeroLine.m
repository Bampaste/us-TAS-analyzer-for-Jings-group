function usTASUpdateZeroLine(ax, showLine)
%USTASUPDATEZEROLINE Show or hide a light y=0 reference line.

if ~isgraphics(ax)
    return;
end

delete(findall(ax, 'Tag', 'usTASZeroLine'));

if ~showLine || strcmp(ax.YScale, 'log')
    return;
end

yline(ax, 0, '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 0.8, ...
    'HandleVisibility', 'off', 'Tag', 'usTASZeroLine');
end
