function Project = SPT_Track(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Track
%
% VB3 Companion Toolbox v4.1
%
% Build Track Table
%
% Input
%   Project.Dataset
%   Project.Geometry (optional, used if available)
%
% Output
%   Project.Tables.Track
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Track\n');
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
    error('Project.Dataset is empty.');
end

if ~isfield(Project.Dataset, 'State') || isempty(Project.Dataset.State)
    error('Dataset.State not found.');
end

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;
dt = Dataset.dt;

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = inferNStates(Dataset.State);
end

hasGeometry = isfield(Project, 'Geometry') && isstruct(Project.Geometry);

%% --------------------------------------------------------
%% Initialize Track Table
%% --------------------------------------------------------

TrackTable = table();

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building track table ...\n');

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

for i = 1:nTraj

    trj = Dataset.Trajectory{i};
    state = Dataset.State{i};
    tid = Dataset.Tid(i);
    rawIndex = Dataset.RawIndex(i);
    length_i = Dataset.Length(i);

    if isempty(trj) || isempty(state)
        continue
    end

    trj = trj(:,1:2);
    state = state(:);

    nPoint = size(trj,1);
    nStatePoint = length(state);
    n = min(nPoint, nStatePoint);

    if n < 1
        continue
    end

    x = trj(1:n,1);
    y = trj(1:n,2);
    state = state(1:n);

    duration_s = (n-1) * dt;

    % Track-level state statistics
    nSwitches = sum(diff(state) ~= 0);
    dominantState = mode(state);

    stateFractions = zeros(1, nStates);
    for k = 1:nStates
        stateFractions(k) = sum(state == k) / n;
    end

    % Geometry metrics
    if hasGeometry
        if isfield(Project.Geometry, 'StepLength') && numel(Project.Geometry.StepLength) >= i
            step = Project.Geometry.StepLength{i};
        else
            step = [];
        end

        if isfield(Project.Geometry, 'NetDisplacement') && numel(Project.Geometry.NetDisplacement) >= i
            netDisplacement = Project.Geometry.NetDisplacement(i);
        else
            netDisplacement = sqrt((x(end)-x(1)).^2 + (y(end)-y(1)).^2);
        end

        if isfield(Project.Geometry, 'CumulativeDistance') && numel(Project.Geometry.CumulativeDistance) >= i
            totalDistance = Project.Geometry.CumulativeDistance(i);
        else
            totalDistance = localCumulativeDistance(x, y);
        end

        if isfield(Project.Geometry, 'Velocity') && numel(Project.Geometry.Velocity) >= i
            vel = Project.Geometry.Velocity{i};
        else
            vel = localVelocityFromTrajectory(x, y, dt);
        end

        if isfield(Project.Geometry, 'Direction') && numel(Project.Geometry.Direction) >= i
            dirDeg = Project.Geometry.Direction{i};
        else
            dirDeg = localDirectionFromTrajectory(x, y);
        end
    else
        step = localStepLengthFromTrajectory(x, y);
        netDisplacement = sqrt((x(end)-x(1)).^2 + (y(end)-y(1)).^2);
        totalDistance = sum(step);
        vel = step / dt;
        dirDeg = localDirectionFromTrajectory(x, y);
    end

    if isempty(step)
        meanStepLength = NaN;
    else
        meanStepLength = mean(step);
    end

    if isempty(vel)
        meanVelocity = NaN;
    else
        meanVelocity = mean(vel);
    end

    if isempty(dirDeg)
        meanDirection = NaN;
    else
        meanDirection = circularMeanDeg(dirDeg);
    end

    confinementRatio = NaN;
    if totalDistance > 0
        confinementRatio = netDisplacement / totalDistance;
    end

    % Build one row
    tmp = table();

    tmp.DatasetIndex = i;
    tmp.RawIndex = rawIndex;
    tmp.Tid = tid;
    tmp.NPoints = n;
    tmp.Length = length_i;
    tmp.Duration_s = duration_s;
    tmp.NStates = numel(unique(state));
    tmp.DominantState = dominantState;
    tmp.NSwitches = nSwitches;
    tmp.NetDisplacement = netDisplacement;
    tmp.TotalDistance = totalDistance;
    tmp.ConfinementRatio = confinementRatio;
    tmp.MeanStepLength = meanStepLength;
    tmp.MeanVelocity = meanVelocity;
    tmp.MeanDirection_deg = meanDirection;

    for k = 1:nStates
        tmp.(['state' num2str(k) '_fraction']) = stateFractions(k);
    end

    TrackTable = [TrackTable; tmp]; %#ok<AGROW>

end

%% --------------------------------------------------------
%% Finalize
%% --------------------------------------------------------

if ~isempty(TrackTable)
    TrackTable = sortrows(TrackTable, {'DatasetIndex'});
end

Project.Tables.Track = TrackTable;
Project.Validation.TrackOK = true;
Project.Flags.Track = true;

fprintf('\n');
fprintf('Track rows        : %d\n', height(TrackTable));
fprintf('Trajectories      : %d\n', nTraj);

fprintf('\n');
fprintf('Track table created successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function nStates = inferNStates(stateCell)

allStates = [];
for i = 1:numel(stateCell)
    if isempty(stateCell{i})
        continue
    end
    allStates = [allStates; stateCell{i}(:)]; %#ok<AGROW>
end

if isempty(allStates)
    nStates = 1;
else
    nStates = max(allStates);
end

end

% =====================================================================
function s = localStepLengthFromTrajectory(x, y)

if numel(x) < 2
    s = [];
    return;
end

dx = diff(x);
dy = diff(y);
s = sqrt(dx.^2 + dy.^2);

end

% =====================================================================
function v = localVelocityFromTrajectory(x, y, dt)

step = localStepLengthFromTrajectory(x, y);

if isempty(step)
    v = [];
else
    v = step / dt;
end

end

% =====================================================================
function d = localDirectionFromTrajectory(x, y)

if numel(x) < 2
    d = [];
    return;
end

dx = diff(x);
dy = diff(y);
d = atan2d(dy, dx);

end

% =====================================================================
function c = localCumulativeDistance(x, y)

step = localStepLengthFromTrajectory(x, y);

if isempty(step)
    c = NaN;
else
    c = sum(step);
end

end

% =====================================================================
function ang = circularMeanDeg(theta)

theta = theta(:);
theta = theta(~isnan(theta));

if isempty(theta)
    ang = NaN;
    return;
end

ang = atan2d(mean(sind(theta)), mean(cosd(theta)));

end