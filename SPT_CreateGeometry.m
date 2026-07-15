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

if nargin < 2 || isempty(Config)
    if isfield(Project, 'Config') && ~isempty(Project.Config)
        Config = Project.Config;
    else
        Config = struct();
    end
end

if ~isfield(Project, 'Flags') || ~isfield(Project.Flags, 'Dataset') || ~Project.Flags.Dataset
    error('Dataset has not been created.');
end

if ~isfield(Project, 'Validation') || ~isfield(Project.Validation, 'DatasetOK') || ~Project.Validation.DatasetOK
    error('Dataset validation failed.');
end

if ~isfield(Project, 'Dataset') || isempty(Project.Dataset.Trajectory)
    error('Project.Dataset is empty.');
end

if ~isfield(Project.Dataset, 'Trajectory') || isempty(Project.Dataset.Trajectory)
    error('Project.Dataset.Trajectory not found.');
end

if ~isfield(Project.Dataset, 'nTraj')
    error('Project.Dataset.nTraj not found.');
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

    if isempty(trj) || ~isnumeric(trj) || ~ismatrix(trj)
        continue
    end

    % Most vbSPT-derived trajectories in your data are N x 3:
    % col1 = x, col2 = y, col3 = usually zero / unused
    if size(trj,2) < 2
        error('Trajectory %d has fewer than 2 columns.', i);
    end

    x = trj(:,1);
    y = trj(:,2);

    x = x(:);
    y = y(:);

    nPoint = numel(x);

    Geometry.X{i} = x;
    Geometry.Y{i} = y;

    Geometry.TrackLength(i) = nPoint;
    Geometry.CentroidX(i) = mean(x);
    Geometry.CentroidY(i) = mean(y);

    Geometry.Time{i} = (0:nPoint-1)' * dt;

    if nPoint < 2
        Geometry.DX{i} = [];
        Geometry.DY{i} = [];
        Geometry.StepLength{i} = [];
        Geometry.Direction{i} = [];
        Geometry.Velocity{i} = [];
        Geometry.Acceleration{i} = [];
        Geometry.NetDisplacement(i) = 0;
        Geometry.CumulativeDistance(i) = 0;
        Geometry.NSteps(i) = 0;
        continue
    end

    dx = diff(x);
    dy = diff(y);

    step = sqrt(dx.^2 + dy.^2);
    direction = atan2d(dy, dx);
    vel = step / dt;

    if numel(vel) > 1
        acc = diff(vel) / dt;
    else
        acc = [];
    end

    Geometry.DX{i} = dx;
    Geometry.DY{i} = dy;
    Geometry.StepLength{i} = step;
    Geometry.Direction{i} = direction;
    Geometry.Velocity{i} = vel;
    Geometry.Acceleration{i} = acc;

    Geometry.NetDisplacement(i) = sqrt((x(end) - x(1))^2 + (y(end) - y(1))^2);
    Geometry.CumulativeDistance(i) = sum(step);

    Geometry.NSteps(i) = numel(step);

    totalSteps = totalSteps + numel(step);
    totalDistance = totalDistance + sum(step);
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