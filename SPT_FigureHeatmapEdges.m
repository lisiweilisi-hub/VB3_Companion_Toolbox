function [xEdges, yEdges] = SPT_FigureHeatmapEdges(x, y, nBins)
% SPT_FigureHeatmapEdges
% Build padded heatmap bin edges for x and y.
% MATLAB R2016b compatible.

xmin = min(x);
xmax = max(x);
ymin = min(y);
ymax = max(y);

if xmin == xmax
    xmin = xmin - 0.5;
    xmax = xmax + 0.5;
else
    pad = 0.03 * (xmax - xmin);
    if ~isfinite(pad) || pad <= 0
        pad = 0.5;
    end
    xmin = xmin - pad;
    xmax = xmax + pad;
end

if ymin == ymax
    ymin = ymin - 0.5;
    ymax = ymax + 0.5;
else
    pad = 0.03 * (ymax - ymin);
    if ~isfinite(pad) || pad <= 0
        pad = 0.5;
    end
    ymin = ymin - pad;
    ymax = ymax + pad;
end

xEdges = linspace(xmin, xmax, nBins + 1);
yEdges = linspace(ymin, ymax, nBins + 1);

end