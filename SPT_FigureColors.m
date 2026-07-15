function [stateColors, nStates] = SPT_FigureColors(Project, Config)
% SPT_FigureColors
% Resolve state colors for Figure Framework v2.
% MATLAB R2016b compatible.

nStates = 1;
stateColors = [];

if nargin < 1
    Project = struct();
end
if nargin < 2
    Config = struct();
end

% ------------------------------------------------------------
% Infer number of states
% ------------------------------------------------------------
if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && ...
        isnumeric(Project.HMM.nStates) && isscalar(Project.HMM.nStates) && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
elseif isfield(Project, 'Dataset') && isfield(Project.Dataset, 'State') && iscell(Project.Dataset.State)
    allStates = [];
    for i = 1:numel(Project.Dataset.State)
        if isempty(Project.Dataset.State{i})
            continue;
        end
        allStates = [allStates; Project.Dataset.State{i}(:)]; %#ok<AGROW>
    end
    if ~isempty(allStates)
        nStates = max(allStates);
    end
end

if ~isfinite(nStates) || nStates < 1
    nStates = 1;
end

% ------------------------------------------------------------
% Try VB3_StateEngine first
% ------------------------------------------------------------
if exist('VB3_StateEngine', 'file') == 2
    try
        Engine = VB3_StateEngine(Project, Config);
        if isfield(Engine, 'Color') && ~isempty(Engine.Color)
            stateColors = Engine.Color;
        end
    catch
        stateColors = [];
    end
end

% ------------------------------------------------------------
% Fallbacks
% ------------------------------------------------------------
if isempty(stateColors)
    if isfield(Config, 'ColorMap') && ~isempty(Config.ColorMap)
        stateColors = Config.ColorMap;
    else
        stateColors = lines(max(nStates, 1));
    end
end

if size(stateColors, 1) < nStates
    stateColors = lines(nStates);
end

% Force numeric RGB in [0,1]
stateColors = double(stateColors);
stateColors(stateColors < 0) = 0;
stateColors(stateColors > 1) = 1;

end