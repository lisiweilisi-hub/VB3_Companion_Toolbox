function [x, y] = SPT_FigureExtractXY(trj)
% SPT_FigureExtractXY
% Extract x and y coordinates from a trajectory matrix.
% MATLAB R2016b compatible.

if isempty(trj) || ~isnumeric(trj) || ~ismatrix(trj)
    x = [];
    y = [];
    return;
end

[r, c] = size(trj);

if c >= 2 && r >= c
    x = trj(:, 1);
    y = trj(:, 2);
elseif r >= 2
    x = trj(1, :)';
    y = trj(2, :)';
else
    x = [];
    y = [];
end

x = x(:);
y = y(:);

end