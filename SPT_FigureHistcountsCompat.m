function counts = SPT_FigureHistcountsCompat(x, edges)
% SPT_FigureHistcountsCompat
% Histogram counts wrapper compatible with MATLAB R2016b.
% Falls back to histc if histcounts is unavailable.

x = x(:);
x = x(isfinite(x));

if isempty(x)
    counts = zeros(numel(edges) - 1, 1);
    return;
end

if exist('histcounts', 'file') == 2
    counts = histcounts(x, edges);
else
    counts = histc(x, edges);
    counts(end-1) = counts(end-1) + counts(end);
    counts = counts(1:end-1);
end

counts = counts(:);

end