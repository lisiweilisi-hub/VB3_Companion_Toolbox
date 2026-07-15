function SPT_FigureEnsureDir(d)
% SPT_FigureEnsureDir
% Create directory if it does not exist.

if nargin < 1 || isempty(d)
    return;
end

if exist(d, 'dir') == 7
    return;
end

[ok, msg] = mkdir(d);
if ~ok
    error('SPT_FigureEnsureDir:mkdirFailed', ...
        'Failed to create directory: %s\nReason: %s', d, msg);
end

end