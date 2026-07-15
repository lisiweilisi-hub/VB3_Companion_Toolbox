function [x, y, s] = SPT_FigureGetLocalizationXYZS(T)
% SPT_FigureGetLocalizationXYZS
% Extract x, y, and state columns from a localization table.
% MATLAB R2016b compatible.

x = localGetColumn(T, {'X', 'x'});
y = localGetColumn(T, {'Y', 'y'});
s = localGetColumn(T, {'State', 'state'});

end

% =====================================================================
function v = localGetColumn(T, names)

v = [];
if ~istable(T)
    return;
end

if ischar(names)
    names = {names};
end

for i = 1:numel(names)
    if ismember(names{i}, T.Properties.VariableNames)
        v = T.(names{i});
        return;
    end
end

end