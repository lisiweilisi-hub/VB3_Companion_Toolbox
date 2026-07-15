function Project = SPT_Segment(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Segment
%
% VB3 Companion Toolbox v4.1
%
% Build Segment Table
%
% Input
%   Project.Dataset
%
% Output
%   Project.Tables.Segment
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Segment\n');
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

%% --------------------------------------------------------
%% Initialize Segment Table
%% --------------------------------------------------------

SegmentTable = table();
TotalSegments = 0;
SegmentsPerTraj = zeros(nTraj, 1);

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building segment table ...\n');

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

for i = 1:nTraj

    trj = Dataset.Trajectory{i};
    state = Dataset.State{i};
    tid = Dataset.Tid(i);
    rawIndex = Dataset.RawIndex(i);

    if isempty(trj) || isempty(state)
        continue
    end

    trj = trj(:,1:2); % x,y only
    state = state(:);

    nPoint = size(trj, 1);
    nStatePoint = length(state);

    n = min(nPoint, nStatePoint);

    if n < 1
        continue
    end

    x = trj(1:n, 1);
    y = trj(1:n, 2);
    state = state(1:n);

    % Posterior for this trajectory
    pst = [];
    if isfield(Dataset, 'Posterior') && numel(Dataset.Posterior) >= i
        pst = Dataset.Posterior{i};
    end
    pMat = normalizePosteriorMatrix(pst, n, nStates);

    % Segment boundaries
    cut = [1; find(diff(state) ~= 0) + 1; n + 1];

    for k = 1:(numel(cut)-1)

        s0 = cut(k);
        s1 = cut(k+1) - 1;

        segState = state(s0);

        segLen = s1 - s0 + 1;
        segDuration = segLen * dt;

        startFrame = s0;
        endFrame = s1;

        startTime = (s0 - 1) * dt;
        endTime = (s1 - 1) * dt;

        startX = x(s0);
        startY = y(s0);
        endX = x(s1);
        endY = y(s1);

        meanX = mean(x(s0:s1));
        meanY = mean(y(s0:s1));

        % Geometry-like metrics computed directly from trajectory
        meanStepLength = NaN;
        meanVelocity = NaN;
        meanDirection = NaN;

        if segLen > 1
            dx = diff(x(s0:s1));
            dy = diff(y(s0:s1));

            step = sqrt(dx.^2 + dy.^2);
            vel = step / dt;
            direction = atan2d(dy, dx);

            meanStepLength = mean(step);
            meanVelocity = mean(vel);
            meanDirection = circularMeanDeg(direction);
        end

        % Posterior mean within this segment
        meanP = nan(1, nStates);
        if ~isempty(pMat)
            if s0 <= size(pMat,1) && s1 <= size(pMat,1)
                meanP = meanIgnoringNaN(pMat(s0:s1, :));
            end
        end

        tmp = table();

        tmp.DatasetIndex = repmat(i, 1, 1);
        tmp.RawIndex = repmat(rawIndex, 1, 1);
        tmp.Tid = repmat(tid, 1, 1);
        tmp.SegmentID = repmat(k, 1, 1);
        tmp.State = repmat(segState, 1, 1);
        tmp.StartFrame = repmat(startFrame, 1, 1);
        tmp.EndFrame = repmat(endFrame, 1, 1);
        tmp.StartTime_s = repmat(startTime, 1, 1);
        tmp.EndTime_s = repmat(endTime, 1, 1);
        tmp.NPoints = repmat(segLen, 1, 1);
        tmp.Duration_s = repmat(segDuration, 1, 1);
        tmp.StartX = repmat(startX, 1, 1);
        tmp.StartY = repmat(startY, 1, 1);
        tmp.EndX = repmat(endX, 1, 1);
        tmp.EndY = repmat(endY, 1, 1);
        tmp.MeanX = repmat(meanX, 1, 1);
        tmp.MeanY = repmat(meanY, 1, 1);
        tmp.MeanStepLength = repmat(meanStepLength, 1, 1);
        tmp.MeanVelocity = repmat(meanVelocity, 1, 1);
        tmp.MeanDirection = repmat(meanDirection, 1, 1);

        for s = 1:nStates
            tmp.(['meanPState' num2str(s)]) = repmat(meanP(s), 1, 1);
        end

        SegmentTable = [SegmentTable; tmp]; %#ok<AGROW>

    end

    SegmentsPerTraj(i) = sum(cut(2:end) - cut(1:end-1) > 0);
    TotalSegments = height(SegmentTable);

end

%% --------------------------------------------------------
%% Finalize
%% --------------------------------------------------------

if ~isempty(SegmentTable)
    SegmentTable = sortrows(SegmentTable, {'DatasetIndex', 'SegmentID'});
end

Project.Tables.Segment = SegmentTable;
Project.Validation.SegmentOK = true;
Project.Flags.Segmentation = true;

fprintf('\n');
fprintf('Segment rows      : %d\n', height(SegmentTable));
fprintf('Trajectories      : %d\n', nTraj);
fprintf('Total segments    : %d\n', TotalSegments);

fprintf('\n');
fprintf('Segment table created successfully.\n');
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
function P = normalizePosteriorMatrix(pst, n, nStates)

P = nan(n, nStates);

if isempty(pst)
    return;
end

if iscell(pst)
    pst = pst{1};
end

if ~isnumeric(pst)
    return;
end

% Try direct orientation first
if size(pst,1) >= n && size(pst,2) >= nStates
    P(1:n,1:nStates) = pst(1:n,1:nStates);
    return;
end

% Try transposed orientation
if size(pst,2) >= n && size(pst,1) >= nStates
    pst = pst.';
    if size(pst,1) >= n && size(pst,2) >= nStates
        P(1:n,1:nStates) = pst(1:n,1:nStates);
        return;
    end
end

% Fallback partial copy
r = min(size(pst,1), n);
c = min(size(pst,2), nStates);
P(1:r,1:c) = pst(1:r,1:c);

end

% =====================================================================
function m = meanIgnoringNaN(X)

if isempty(X)
    m = nan(1, size(X,2));
    return;
end

m = nan(1, size(X,2));
for k = 1:size(X,2)
    col = X(:,k);
    col = col(~isnan(col));
    if isempty(col)
        m(k) = NaN;
    else
        m(k) = mean(col);
    end
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