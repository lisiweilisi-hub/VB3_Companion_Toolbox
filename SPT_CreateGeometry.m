function Project = SPT_CreateGeometry(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_CreateGeometry
%
% VB3 Companion Toolbox v4.1
%
% Build Geometry Layer
%
% Input
%   Project.Dataset
%
% Output
%   Project.Geometry
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Create Geometry\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

if ~isstruct(Project) || ~isscalar(Project)
    error('Project must be a scalar structure.');
end

if nargin < 2 || isempty(Config)
    if isfield(Project, 'Config') && ~isempty(Project.Config)
        Config = Project.Config;
    else
        Config = struct();
    end
end

if ~isfield(Project, 'Flags') || ~isstruct(Project.Flags) || ...
        ~isscalar(Project.Flags) || ...
        ~isfield(Project.Flags, 'Dataset') || ...
        ~isscalar(Project.Flags.Dataset) || ~Project.Flags.Dataset
    error('Dataset has not been created.');
end

if ~isfield(Project, 'Validation') || ~isstruct(Project.Validation) || ...
        ~isscalar(Project.Validation) || ...
        ~isfield(Project.Validation, 'DatasetOK') || ...
        ~isscalar(Project.Validation.DatasetOK) || ~Project.Validation.DatasetOK
    error('Dataset validation failed.');
end

if ~isfield(Project, 'Dataset') || ~isstruct(Project.Dataset) || ...
        ~isscalar(Project.Dataset)
    error('Project.Dataset not found.');
end

if ~isfield(Project.Dataset, 'Trajectory') || isempty(Project.Dataset.Trajectory)
    error('Project.Dataset.Trajectory not found.');
end

if ~iscell(Project.Dataset.Trajectory)
    error('Project.Dataset.Trajectory must be a cell array.');
end

if ~isfield(Project.Dataset, 'nTraj') || ...
        ~isnumeric(Project.Dataset.nTraj) || ...
        ~isscalar(Project.Dataset.nTraj) || ...
        ~isreal(Project.Dataset.nTraj) || ...
        ~isfinite(Project.Dataset.nTraj) || ...
        Project.Dataset.nTraj < 0 || ...
        Project.Dataset.nTraj ~= floor(Project.Dataset.nTraj)
    error('Project.Dataset.nTraj must be a nonnegative integer scalar.');
end

if numel(Project.Dataset.Trajectory) ~= Project.Dataset.nTraj
    error('Project.Dataset.Trajectory length does not match Project.Dataset.nTraj.');
end

if ~isfield(Project.Dataset, 'dt') || ...
        ~isnumeric(Project.Dataset.dt) || ...
        ~isscalar(Project.Dataset.dt) || ...
        ~isreal(Project.Dataset.dt) || ...
        ~isfinite(Project.Dataset.dt) || Project.Dataset.dt <= 0
    error('Project.Dataset.dt must be a positive finite numeric scalar.');
end

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;
dt = Dataset.dt;

%% --------------------------------------------------------
%% Initialize Geometry
%% --------------------------------------------------------

Geometry = struct();

Geometry.X = cell(nTraj, 1);
Geometry.Y = cell(nTraj, 1);

Geometry.DX = cell(nTraj, 1);
Geometry.DY = cell(nTraj, 1);
Geometry.Displacement = cell(nTraj, 1);

Geometry.StepLength = cell(nTraj, 1);
Geometry.Direction = cell(nTraj, 1);

Geometry.Velocity = cell(nTraj, 1);
Geometry.Acceleration = cell(nTraj, 1);

Geometry.Time = cell(nTraj, 1);

Geometry.CentroidX = nan(nTraj, 1);
Geometry.CentroidY = nan(nTraj, 1);

Geometry.NetDisplacement = nan(nTraj, 1);
Geometry.CumulativeDistance = nan(nTraj, 1);

Geometry.TrackLength = zeros(nTraj, 1);
Geometry.NSteps = zeros(nTraj, 1);

Geometry.Summary = struct();

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building geometry layer ...\n');

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

totalSteps = 0;
totalDistance = 0;
validTracks = 0;

for i = 1:nTraj

    trj = Dataset.Trajectory{i};

    if isempty(trj)
        continue
    end

    if ~isnumeric(trj) || ~ismatrix(trj)
        error('Trajectory %d must be a numeric matrix.', i);
    end

    % Geometry owns the canonical coordinate vectors and all primitives
    % derived from them. Downstream modules should consume these fields
    % instead of independently extracting coordinates and recomputing
    % whole-trajectory displacement quantities.
    [x, y] = canonicalCoordinates(trj, i);

    nPoint = numel(x);

    Geometry.X{i} = x;
    Geometry.Y{i} = y;

    Geometry.TrackLength(i) = nPoint;
    Geometry.CentroidX(i) = mean(x);
    Geometry.CentroidY(i) = mean(y);

    Geometry.Time{i} = (0:nPoint-1)' * dt;

    primitives = trajectoryPrimitives(x, y, dt);

    Geometry.DX{i} = primitives.DX;
    Geometry.DY{i} = primitives.DY;
    Geometry.Displacement{i} = primitives.Displacement;
    Geometry.StepLength{i} = primitives.StepLength;
    Geometry.Direction{i} = primitives.Direction;
    Geometry.Velocity{i} = primitives.Velocity;
    Geometry.Acceleration{i} = primitives.Acceleration;

    Geometry.NetDisplacement(i) = primitives.NetDisplacement;
    Geometry.CumulativeDistance(i) = primitives.CumulativeDistance;
    Geometry.NSteps(i) = numel(primitives.StepLength);

    if nPoint < 2
        continue
    end

    totalSteps = totalSteps + Geometry.NSteps(i);
    totalDistance = totalDistance + Geometry.CumulativeDistance(i);
    validTracks = validTracks + 1;

end

%% --------------------------------------------------------
%% Summary
%% --------------------------------------------------------

Summary = struct();

Summary.nTraj = nTraj;
Summary.nValidTraj = validTracks;
Summary.TotalSteps = totalSteps;
Summary.TotalDistance = totalDistance;
Summary.MeanTrackLength = meanIgnoringNaN(Geometry.TrackLength);
Summary.MedianTrackLength = medianIgnoringNaN(Geometry.TrackLength);
Summary.MeanNetDisplacement = meanIgnoringNaN(Geometry.NetDisplacement);
Summary.MedianNetDisplacement = medianIgnoringNaN(Geometry.NetDisplacement);
Summary.MeanCumulativeDistance = meanIgnoringNaN(Geometry.CumulativeDistance);
Summary.MedianCumulativeDistance = medianIgnoringNaN(Geometry.CumulativeDistance);
Summary.MeanCentroidX = meanIgnoringNaN(Geometry.CentroidX);
Summary.MeanCentroidY = meanIgnoringNaN(Geometry.CentroidY);
Summary.dt = dt;

Geometry.Summary = Summary;

%% --------------------------------------------------------
%% Save
%% --------------------------------------------------------

Project.Geometry = Geometry;

if ~isfield(Project.Validation, 'GeometryOK')
    Project.Validation.GeometryOK = false;
end
Project.Validation.GeometryOK = true;

Project.Flags.Geometry = true;

%% --------------------------------------------------------
%% Display
%% --------------------------------------------------------

fprintf('Valid trajectories     : %d\n', validTracks);
fprintf('Total steps            : %d\n', totalSteps);
fprintf('Mean track length      : %.2f\n', Summary.MeanTrackLength);
fprintf('Mean net displacement  : %.6g\n', Summary.MeanNetDisplacement);
fprintf('Mean cumulative dist.  : %.6g\n', Summary.MeanCumulativeDistance);

fprintf('\n');
fprintf('Geometry layer created successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function [x, y] = canonicalCoordinates(trj, trajectoryIndex)

% Most vbSPT-derived trajectories are N x 3. The first two columns are
% canonical X/Y; additional columns are intentionally ignored.
if size(trj, 2) < 2
    error('Trajectory %d has fewer than 2 columns.', trajectoryIndex);
end

x = trj(:, 1);
y = trj(:, 2);
x = x(:);
y = y(:);

end


% =====================================================================
function primitives = trajectoryPrimitives(x, y, dt)

primitives = struct();
primitives.DX = [];
primitives.DY = [];
primitives.Displacement = [];
primitives.StepLength = [];
primitives.Direction = [];
primitives.Velocity = [];
primitives.Acceleration = [];
primitives.NetDisplacement = 0;
primitives.CumulativeDistance = 0;

if numel(x) < 2
    return
end

dx = diff(x);
dy = diff(y);
displacement = [dx dy];
step = sqrt(dx.^2 + dy.^2);
direction = atan2d(dy, dx);
velocity = step / dt;

if numel(velocity) > 1
    acceleration = diff(velocity) / dt;
else
    acceleration = [];
end

primitives.DX = dx;
primitives.DY = dy;
primitives.Displacement = displacement;
primitives.StepLength = step;
primitives.Direction = direction;
primitives.Velocity = velocity;
primitives.Acceleration = acceleration;
primitives.NetDisplacement = sqrt((x(end) - x(1))^2 + ...
    (y(end) - y(1))^2);
primitives.CumulativeDistance = sum(step);

end


% =====================================================================
function y = meanIgnoringNaN(x)

if isempty(x)
    y = NaN;
    return;
end

x = x(:);
x = x(~isnan(x));

if isempty(x)
    y = NaN;
else
    y = mean(x);
end

end

% =====================================================================
function y = medianIgnoringNaN(x)

if isempty(x)
    y = NaN;
    return;
end

x = x(:);
x = x(~isnan(x));

if isempty(x)
    y = NaN;
else
    y = median(x);
end

end
