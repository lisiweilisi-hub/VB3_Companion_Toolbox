function Project = SPT_TurningAngle(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_TurningAngle
%
% VB3 Companion Toolbox v4.1
%
% Build Turning Angle Analysis
%
% Input
%   Project.Dataset
%   Project.Geometry (optional, used if available)
%
% Output
%   Project.Analysis.TurningAngle
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Turning Angle\n');
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

if ~isfield(Project, 'Validation') || ...
        ~isfield(Project.Validation, 'DatasetOK') || ...
        ~Project.Validation.DatasetOK
    error('Dataset validation failed.');
end

if ~isfield(Project, 'Dataset') || isempty(Project.Dataset.Trajectory)
    error('Project.Dataset is empty.');
end

if ~isfield(Project.Dataset, 'State') || isempty(Project.Dataset.State)
    error('Project.Dataset.State not found.');
end

%% --------------------------------------------------------
%% Configuration
%% --------------------------------------------------------

if ~isfield(Config, 'TurningAngle') || ~isstruct(Config.TurningAngle)
    Config.TurningAngle = struct();
end

if ~isfield(Config.TurningAngle, 'Bin') || isempty(Config.TurningAngle.Bin)
    Config.TurningAngle.Bin = 5;
end

if ~isfield(Config.TurningAngle, 'Range') || isempty(Config.TurningAngle.Range)
    Config.TurningAngle.Range = [-180 180];
end

if ~isfield(Config.TurningAngle, 'MinPoints') || isempty(Config.TurningAngle.MinPoints)
    Config.TurningAngle.MinPoints = 3;
end

binSize = Config.TurningAngle.Bin;
rangeDeg = Config.TurningAngle.Range;
minPoints = Config.TurningAngle.MinPoints;

if numel(rangeDeg) ~= 2
    error('Config.TurningAngle.Range must be a 1x2 vector.');
end

if rangeDeg(1) >= rangeDeg(2)
    error('Config.TurningAngle.Range must be increasing.');
end

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = inferNStatesFromStateCell(Dataset.State);
end

hasGeometry = isfield(Project, 'Geometry') && isstruct(Project.Geometry);

%% --------------------------------------------------------
%% Initialize
%% --------------------------------------------------------

TA = struct();
TA.Config = Config.TurningAngle;
TA.PerTrajectory = cell(nTraj, 1);
TA.Ensemble = struct();
TA.ByState = struct();
TA.Summary = struct();
TA.Table = table();

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Bin size               : %d deg\n', binSize);
fprintf('Angle range            : [%d, %d] deg\n', rangeDeg(1), rangeDeg(2));
fprintf('\n');
fprintf('Building turning angle analysis ...\n');

allAngles = [];
allAbsAngles = [];
allStateLabels = [];
allTrackIndex = [];
allFrameIndex = [];
allTime_s = [];

trajCounts = zeros(nTraj, 1);
trajMean = nan(nTraj, 1);
trajMeanAbs = nan(nTraj, 1);
trajResultant = nan(nTraj, 1);
trajCircVar = nan(nTraj, 1);

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

for i = 1:nTraj

    trj = Dataset.Trajectory{i};
    state = Dataset.State{i};
    tid = Dataset.Tid(i);
    rawIndex = Dataset.RawIndex(i);

    if isempty(trj) || isempty(state)
        TA.PerTrajectory{i} = struct();
        continue
    end

    trj = trj(:, 1:2);
    state = state(:);

    nPoint = size(trj, 1);
    nStatePoint = length(state);

    % turning angle needs at least 3 points and 2 step-states
    nSteps = min(nPoint - 1, nStatePoint);

    if nSteps < 2
        TA.PerTrajectory{i} = struct();
        continue
    end

    % use nSteps+1 positions to generate nSteps directions
    x = trj(1:(nSteps+1), 1);
    y = trj(1:(nSteps+1), 2);
    state = state(1:nSteps);

    % Direction of each step
    if hasGeometry && isfield(Project.Geometry, 'Direction') && numel(Project.Geometry.Direction) >= i
        dirDeg = Project.Geometry.Direction{i};
        if isempty(dirDeg)
            [dirDeg, stepLen] = localDirectionAndStep(x, y);
        else
            dirDeg = dirDeg(:);
            [~, stepLen] = localDirectionAndStep(x, y);
        end
    else
        [dirDeg, stepLen] = localDirectionAndStep(x, y);
    end

    if isempty(dirDeg) || numel(dirDeg) < 2
        TA.PerTrajectory{i} = struct();
        continue
    end

    % Turning angle between successive displacement vectors
    turnDeg = localWrapAngle180(diff(dirDeg(:)));
    absTurnDeg = abs(turnDeg);

    nAngles = numel(turnDeg);

    % angle index corresponds to the vertex between step j and j+1
    turnIndex = (1:nAngles)';
    frameIndex = (2:(nSteps))';
    time_s = frameIndex * Dataset.dt;

    % step-state aligned to the turning vertex
    stateAtTurn = state(1:nAngles);


    % Save per-trajectory data
    T = struct();
    T.DatasetIndex = i;
    T.RawIndex = rawIndex;
    T.Tid = tid;
    T.NPoints = nSteps + 1;
    T.NAngles = nAngles;
    T.Frame = frameIndex;
    T.Time_s = time_s;
    T.Angle_deg = turnDeg(:);
    T.AbsAngle_deg = absTurnDeg(:);
    T.State = stateAtTurn(:);

    TA.PerTrajectory{i} = T;

    % Trajectory-level stats
    trajCounts(i) = nAngles;
    trajMean(i) = localCircularMeanDeg(turnDeg);
    trajMeanAbs(i) = mean(absTurnDeg);
    trajResultant(i) = localResultantLengthDeg(turnDeg);
    trajCircVar(i) = 1 - trajResultant(i);

    % Accumulate ensemble
    allAngles = [allAngles; turnDeg(:)];
    allAbsAngles = [allAbsAngles; absTurnDeg(:)];
    allStateLabels = [allStateLabels; stateAtTurn(:)];
    allTrackIndex = [allTrackIndex; repmat(i, nAngles, 1)];
    allFrameIndex = [allFrameIndex; frameIndex];
    allTime_s = [allTime_s; time_s];

end

%% --------------------------------------------------------
%% Build localization-like table of turning angles
%% --------------------------------------------------------

if ~isempty(allAngles)

    TA.Table = table();
    TA.Table.DatasetIndex = allTrackIndex;
    TA.Table.Frame = allFrameIndex;
    TA.Table.Time_s = allTime_s;
    TA.Table.Angle_deg = allAngles;
    TA.Table.AbsAngle_deg = allAbsAngles;
    TA.Table.State = allStateLabels;

end

%% --------------------------------------------------------
%% Ensemble statistics
%% --------------------------------------------------------

Ensemble = struct();

Ensemble.nAngles = numel(allAngles);
Ensemble.MeanAngle_deg = localCircularMeanDeg(allAngles);
Ensemble.MeanAbsAngle_deg = mean(allAbsAngles);
Ensemble.ResultantLength = localResultantLengthDeg(allAngles);
Ensemble.CircularVariance = 1 - Ensemble.ResultantLength;
Ensemble.MedianAngle_deg = localCircularMedianDeg(allAngles);

% Histogram
edges = rangeDeg(1):binSize:rangeDeg(2);
if edges(end) < rangeDeg(2)
    edges = [edges rangeDeg(2)];
end

if isempty(allAngles)
    counts = zeros(1, numel(edges)-1);
else
    counts = localHistCounts(allAngles, edges);
end

Ensemble.HistogramCounts = counts;
Ensemble.HistogramEdges = edges;
Ensemble.HistogramCenters = (edges(1:end-1) + edges(2:end)) / 2;

TA.Ensemble = Ensemble;

%% --------------------------------------------------------
%% State-specific statistics
%% --------------------------------------------------------

ByState = repmat(struct( ...
    'State', [], ...
    'nAngles', [], ...
    'MeanAngle_deg', [], ...
    'MeanAbsAngle_deg', [], ...
    'ResultantLength', [], ...
    'CircularVariance', [], ...
    'MedianAngle_deg', [], ...
    'HistogramCounts', [], ...
    'HistogramEdges', [], ...
    'HistogramCenters', []), nStates, 1);

for k = 1:nStates

    idx = (allStateLabels == k);
    ang = allAngles(idx);
    absAng = allAbsAngles(idx);

    ByState(k).State = k;
    ByState(k).nAngles = numel(ang);
    ByState(k).MeanAngle_deg = localCircularMeanDeg(ang);
    ByState(k).MeanAbsAngle_deg = mean(absAng);
    ByState(k).ResultantLength = localResultantLengthDeg(ang);
    ByState(k).CircularVariance = 1 - ByState(k).ResultantLength;
    ByState(k).MedianAngle_deg = localCircularMedianDeg(ang);

    if isempty(ang)
        ByState(k).HistogramCounts = zeros(1, numel(edges)-1);
    else
        ByState(k).HistogramCounts = localHistCounts(ang, edges);
    end

    ByState(k).HistogramEdges = edges;
    ByState(k).HistogramCenters = (edges(1:end-1) + edges(2:end)) / 2;

end

TA.ByState = ByState;

%% --------------------------------------------------------
%% Summary
%% --------------------------------------------------------

Summary = struct();
Summary.nTraj = nTraj;
Summary.nAngles = numel(allAngles);
Summary.nStates = nStates;
Summary.BinSize_deg = binSize;
Summary.Range_deg = rangeDeg;
Summary.MinPoints = minPoints;
Summary.MeanAngle_deg = Ensemble.MeanAngle_deg;
Summary.MeanAbsAngle_deg = Ensemble.MeanAbsAngle_deg;
Summary.ResultantLength = Ensemble.ResultantLength;
Summary.CircularVariance = Ensemble.CircularVariance;

Summary.TrajectoryMeanAngle_deg = trajMean;
Summary.TrajectoryMeanAbsAngle_deg = trajMeanAbs;
Summary.TrajectoryResultantLength = trajResultant;
Summary.TrajectoryCircularVariance = trajCircVar;
Summary.TrajectoryNAngles = trajCounts;

TA.Summary = Summary;

%% --------------------------------------------------------
%% Save
%% --------------------------------------------------------

Project.Analysis.TurningAngle = TA;

if ~isfield(Project.Validation, 'AnalysisOK')
    Project.Validation.AnalysisOK = false;
end
Project.Validation.AnalysisOK = true;

Project.Flags.Analysis = true;

%% --------------------------------------------------------
%% Display
%% --------------------------------------------------------

fprintf('Total angles          : %d\n', Ensemble.nAngles);
fprintf('Mean angle (deg)      : %.4f\n', Ensemble.MeanAngle_deg);
fprintf('Mean abs angle (deg)  : %.4f\n', Ensemble.MeanAbsAngle_deg);
fprintf('Resultant length      : %.4f\n', Ensemble.ResultantLength);
fprintf('Circular variance     : %.4f\n', Ensemble.CircularVariance);

fprintf('\n');
fprintf('Turning angle analysis created successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function nStates = inferNStatesFromStateCell(stateCell)

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
function [dirDeg, stepLen] = localDirectionAndStep(x, y)

if numel(x) < 2
    dirDeg = [];
    stepLen = [];
    return;
end

dx = diff(x);
dy = diff(y);
stepLen = sqrt(dx.^2 + dy.^2);
dirDeg = atan2d(dy, dx);

end

% =====================================================================
function ang = localWrapAngle180(ang)
% Wrap degrees to [-180, 180)

ang = mod(ang + 180, 360) - 180;

end

% =====================================================================
function r = localResultantLengthDeg(theta)

theta = theta(:);
theta = theta(~isnan(theta));

if isempty(theta)
    r = NaN;
    return;
end

C = mean(cosd(theta));
S = mean(sind(theta));
r = sqrt(C.^2 + S.^2);

end

% =====================================================================
function m = localCircularMeanDeg(theta)

theta = theta(:);
theta = theta(~isnan(theta));

if isempty(theta)
    m = NaN;
    return;
end

m = atan2d(mean(sind(theta)), mean(cosd(theta)));

end

% =====================================================================
function m = localCircularMedianDeg(theta)

theta = theta(:);
theta = theta(~isnan(theta));

if isempty(theta)
    m = NaN;
    return;
end

% Simple linear median after wrapping to keep value stable
theta = localWrapAngle180(theta);
m = median(theta);

end

% =====================================================================
function counts = localHistCounts(x, edges)

x = x(:);
x = x(~isnan(x));

if isempty(x)
    counts = zeros(1, numel(edges)-1);
    return;
end

if exist('histcounts', 'file') == 2
    counts = histcounts(x, edges);
else
    % Fallback for very old environments
    counts = histc(x, edges);
    counts(end-1) = counts(end-1) + counts(end);
    counts = counts(1:end-1);
end

end