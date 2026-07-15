function SPT_FigureStyleAxes(ax, F)
% SPT_FigureStyleAxes
% Apply frozen Figure Framework v2 axis styling.
% MATLAB R2016b compatible.

if nargin < 1 || isempty(ax) || ~ishandle(ax)
    return;
end

if nargin < 2 || isempty(F) || ~isstruct(F)
    F = struct();
end

if ~isfield(F, 'FontName') || isempty(F.FontName)
    F.FontName = 'Arial';
end
if ~isfield(F, 'FontSize') || isempty(F.FontSize)
    F.FontSize = 10;
end
if ~isfield(F, 'AxisLineWidth') || isempty(F.AxisLineWidth)
    F.AxisLineWidth = 1.0;
end
if ~isfield(F, 'BackgroundColor') || isempty(F.BackgroundColor)
    F.BackgroundColor = [1 1 1];
end

set(ax, ...
    'FontName', F.FontName, ...
    'FontSize', F.FontSize, ...
    'LineWidth', F.AxisLineWidth, ...
    'TickDir', 'out', ...
    'Color', F.BackgroundColor);

box(ax, 'on');

end