function y = SPT_FigureSmoothVector(x, sigma)
% SPT_FigureSmoothVector
% One-dimensional Gaussian smoothing for frozen Figure Framework v2.
% MATLAB R2016b compatible.

x = x(:);

if nargin < 2 || isempty(sigma) || ~isfinite(sigma) || sigma <= 0
    y = x;
    return;
end

halfWidth = max(1, ceil(3 * sigma));
t = -halfWidth:halfWidth;

k = exp(-(t.^2) ./ (2 * sigma^2));
k = k ./ sum(k);

y = conv(double(x), k(:), 'same');

end