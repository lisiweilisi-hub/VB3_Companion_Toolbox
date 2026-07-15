function Engine = VB3_StateEngine(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% VB3_StateEngine
%
% VB3 Companion Toolbox v4.1
%
% Build state-dependent names / colors for N-state models
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' VB3 State Engine\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

if nargin < 1 || isempty(Project)
    error('Project is required.');
end

if nargin < 2 || isempty(Config)
    if isfield(Project, 'Config') && ~isempty(Project.Config)
        Config = Project.Config;
    else
        Config = struct();
    end
end

%% --------------------------------------------------------
%% Determine number of states
%% --------------------------------------------------------

nStates = inferNStates(Project);

if nStates < 1
    nStates = 1;
end

%% --------------------------------------------------------
%% Color map
%% --------------------------------------------------------

if isfield(Config, 'ColorMap') && ~isempty(Config.ColorMap)
    cmap = Config.ColorMap;
else
    cmap = lines(max(nStates, 1));
end

if size(cmap, 1) < nStates
    cmap = lines(nStates);
end

%% --------------------------------------------------------
%% Names
%% --------------------------------------------------------

Engine = struct();
Engine.nStates = nStates;
Engine.Color = cmap(1:nStates, :);

Engine.Name = cell(nStates, 1);
Engine.PosteriorName = cell(nStates, 1);
Engine.SegmentPosteriorName = cell(nStates, 1);
Engine.StateFractionName = cell(nStates, 1);

for k = 1:nStates
    Engine.Name{k} = ['State' num2str(k)];
    Engine.PosteriorName{k} = ['pState' num2str(k)];
    Engine.SegmentPosteriorName{k} = ['meanPState' num2str(k)];
    Engine.StateFractionName{k} = ['state' num2str(k) '_fraction'];
end

%% --------------------------------------------------------
%% Figure defaults
%% --------------------------------------------------------

Engine.LineWidth = getFieldOrDefault(Config, {'Figure', 'LineWidth'}, 1.5);
Engine.MarkerSize = getFieldOrDefault(Config, {'Figure', 'MarkerSize'}, 8);
Engine.StartMarker = getFieldOrDefault(Config, {'Figure', 'StartMarker'}, 'o');
Engine.EndMarker = getFieldOrDefault(Config, {'Figure', 'EndMarker'}, 's');

%% --------------------------------------------------------
%% Display
%% --------------------------------------------------------

fprintf('Number of states : %d\n', Engine.nStates);
fprintf('Color map size   : %d x %d\n', size(Engine.Color,1), size(Engine.Color,2));
fprintf('=====================================================\n');

end

% =====================================================================
function nStates = inferNStates(Project)

nStates = 1;

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && ...
        isnumeric(Project.HMM.nStates) && isscalar(Project.HMM.nStates) && ...
        isfinite(Project.HMM.nStates) && Project.HMM.nStates >= 1
    nStates = Project.HMM.nStates;
    return;
end

if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'State') && iscell(Project.Dataset.State)
    allStates = [];

    for i = 1:numel(Project.Dataset.State)
        if isempty(Project.Dataset.State{i})
            continue
        end
        allStates = [allStates; Project.Dataset.State{i}(:)]; %#ok<AGROW>
    end

    if ~isempty(allStates)
        nStates = max(allStates);
    end
end

end

% =====================================================================
function val = getFieldOrDefault(S, pathCells, defaultVal)

val = defaultVal;

try
    tmp = S;
    for i = 1:numel(pathCells)
        if ~isstruct(tmp) || ~isfield(tmp, pathCells{i})
            return;
        end
        tmp = tmp.(pathCells{i});
    end
    if ~isempty(tmp)
        val = tmp;
    end
catch
    val = defaultVal;
end

end