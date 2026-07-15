function Project = SPT_Localization(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Localization
%
% VB3 Companion Toolbox v4.1
%
% Build Localization Table
%
% Input
%   Project.Dataset
%
% Output
%   Project.Tables.Localization
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Localization\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

if nargin < 2 || isempty(Config)
    if isfield(Project, 'Config') && ~isempty(Project.Config)
        Config = Project.Config;
    else
        error('Config is required.');
    end
end

if ~isfield(Project, 'Flags') || ~isfield(Project.Flags, 'Dataset') || ~Project.Flags.Dataset
    error('Dataset has not been created.');
end

if ~isfield(Project, 'Validation') || ...
        ~isfield(Project.Validation, 'DatasetOK') || ...
        ~Project.Validation.DatasetOK
    error('Dataset validation failed.');
end

if ~isfield(Project, 'Dataset') || isempty(Project.Dataset.Trajectory)
    error('Dataset contains no trajectories.');
end

if ~isfield(Project, 'HMM') || ~isfield(Project.HMM, 'nStates') || Project.HMM.nStates < 1
    error('Project.HMM.nStates is invalid.');
end

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;
dt = Dataset.dt;
nStates = Project.HMM.nStates;

%% --------------------------------------------------------
%% State Engine
%% --------------------------------------------------------

Engine = VB3_StateEngine(Project, Config);

%% --------------------------------------------------------
%% Initialize Localization Table
%% --------------------------------------------------------

Localization = table();
TotalRows = 0;
TrajectoryRows = zeros(nTraj, 1);

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building localization table ...\n');

%% --------------------------------------------------------
%% Main Loop
%% --------------------------------------------------------

for i = 1:nTraj

    trj = Dataset.Trajectory{i};
    state = Dataset.State{i};
    tid = Dataset.Tid(i);
    rawIndex = Dataset.RawIndex(i);

    if isempty(trj) || isempty(state)
        continue
    end

    nPoint = size(trj, 1);
    nStatePoint = length(state);

    % Align to the shorter one
    n = min(nPoint, nStatePoint);

    if n < 1
        continue
    end

    x = trj(1:n, 1);
    y = trj(1:n, 2);
    frame = (1:n)';
    time = (0:n-1)' * dt;
    state = state(1:n);

    % Posterior
    pst = [];
    if isfield(Dataset, 'Posterior') && numel(Dataset.Posterior) >= i
        pst = Dataset.Posterior{i};
    end
    [pMat, pNames] = parsePosterior(pst, n, nStates);

    % Optional step length from Geometry
    stepLength = nan(n, 1);
    if isfield(Project, 'Geometry') && isfield(Project.Geometry, 'StepLength') ...
            && numel(Project.Geometry.StepLength) >= i
        step = Project.Geometry.StepLength{i};
        if ~isempty(step)
            step = step(:);
            m = min(length(step), n);
            stepLength(1:m) = step(1:m);
        end
    end

    % Build one trajectory block
    tmp = table();
    tmp.DatasetIndex = repmat(i, n, 1);
    tmp.RawIndex = repmat(rawIndex, n, 1);
    tmp.Tid = repmat(tid, n, 1);
    tmp.Frame = frame;
    tmp.Time = time;
    tmp.X = x;
    tmp.Y = y;
    tmp.State = state(:);
    tmp.StepLength = stepLength;

    for k = 1:nStates
        tmp.(pNames{k}) = pMat(:, k);
    end

    Localization = [Localization; tmp]; %#ok<AGROW>
    TrajectoryRows(i) = n;
    TotalRows = TotalRows + n;

end

%% --------------------------------------------------------
%% Finalize
%% --------------------------------------------------------

if ~isempty(Localization)
    Localization = sortrows(Localization, {'DatasetIndex', 'Frame'});
end

Project.Tables.Localization = Localization;
Project.Validation.LocalizationOK = true;
Project.Flags.Localization = true;

validRows = TrajectoryRows(TrajectoryRows > 0);
if isempty(validRows)
    meanRows = NaN;
else
    meanRows = mean(validRows);
end

fprintf('\n');
fprintf('Localization rows : %d\n', height(Localization));
fprintf('Trajectories      : %d\n', nTraj);
fprintf('Mean rows/traj    : %.2f\n', meanRows);
fprintf('Total rows        : %d\n', TotalRows);

fprintf('\n');
fprintf('Localization table created successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function [T, names] = parsePosterior(pst, n, nStates)

names = cell(1, nStates);
for k = 1:nStates
    names{k} = ['pState' num2str(k)];
end

A = nan(n, nStates);

if isempty(pst)
    T = A;
    return;
end

if iscell(pst)
    pst = pst{1};
end

if ~isnumeric(pst)
    T = A;
    return;
end

% Try to interpret orientation robustly
if size(pst, 1) >= n && size(pst, 2) >= nStates
    A(1:n, 1:nStates) = pst(1:n, 1:nStates);

elseif size(pst, 2) >= n && size(pst, 1) >= nStates
    pst = pst.';
    if size(pst, 1) >= n && size(pst, 2) >= nStates
        A(1:n, 1:nStates) = pst(1:n, 1:nStates);
    end

else
    r = min(size(pst, 1), n);
    c = min(size(pst, 2), nStates);
    A(1:r, 1:c) = pst(1:r, 1:c);
end

T = A;

end