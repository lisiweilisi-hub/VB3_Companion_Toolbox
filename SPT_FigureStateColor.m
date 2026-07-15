function c = SPT_FigureStateColor(state, stateColors)
% SPT_FigureStateColor
% Resolve one state color for Figure Framework v2.
% MATLAB R2016b compatible.

if nargin < 2 || isempty(stateColors)
    c = [0 0 0];
    return;
end

if isempty(state) || ~isfinite(state) || state < 1
    c = [0 0 0];
    return;
end

idx = mod(state - 1, size(stateColors, 1)) + 1;
c = stateColors(idx, :);

c = double(c);
c(c < 0) = 0;
c(c > 1) = 1;

end