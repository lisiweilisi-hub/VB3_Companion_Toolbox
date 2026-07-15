function Z = SPT_FigureHeatmapMatrix(x, y, xEdges, yEdges, normalizeFlag, useLogFlag, smoothingSigma)
% SPT_FigureHeatmapMatrix
% Build a 2D heatmap matrix for Figure Framework v2.
% MATLAB R2016b compatible.

xi = discretize(x, xEdges);
yi = discretize(y, yEdges);

good = ~isnan(xi) & ~isnan(yi);

if ~any(good)
    Z = zeros(numel(yEdges) - 1, numel(xEdges) - 1);
    return;
end

H = accumarray([yi(good), xi(good)], 1, ...
    [numel(yEdges) - 1, numel(xEdges) - 1], @sum, 0);

H = double(H);

if nargin >= 7 && ~isempty(smoothingSigma) && isfinite(smoothingSigma) && smoothingSigma > 0
    H = localGaussianSmooth2D(H, smoothingSigma);
end

if useLogFlag
    Z = log10(H + 1);
elseif normalizeFlag
    total = sum(H(:));
    if total > 0
        Z = H ./ total;
    else
        Z = H;
    end
else
    Z = H;
end

end

% =====================================================================
function Z = localGaussianSmooth2D(Z, sigma)
% localGaussianSmooth2D
% Internal helper for heatmap smoothing.

halfWidth = max(1, ceil(3 * sigma));
[r, c] = meshgrid(-halfWidth:halfWidth, -halfWidth:halfWidth);

K = exp(-(r.^2 + c.^2) ./ (2 * sigma^2));
K = K ./ sum(K(:));

Z = conv2(Z, K, 'same');

end