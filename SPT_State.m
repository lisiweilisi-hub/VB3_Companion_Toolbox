function Project = SPT_State(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_State
%
% VB3 Companion Toolbox v4.1
%
% Build State Table
%
% Input
%   Project.Dataset
%   Project.Tables.Localization
%   Project.Tables.Segment
%
% Output
%   Project.Tables.State
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT State\n');
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

if ~isfield(Project, 'Tables') || ...
        ~isfield(Project.Tables, 'Localization') || isempty(Project.Tables.Localization)
    error('Project.Tables.Localization not found. Run SPT_Localization first.');
end

if ~isfield(Project.Tables, 'Segment') || isempty(Project.Tables.Segment)
    error('Project.Tables.Segment not found. Run SPT_Segment first.');
end

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
L = Project.Tables.Localization;
S = Project.Tables.Segment;

nTraj = Dataset.nTraj;
dt = Dataset.dt;

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = inferNStatesFromStateCell(Dataset.State);
end

%% --------------------------------------------------------
%% Initialize
%% --------------------------------------------------------

StateTable = table();

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building state table ...\n');

totalLocalizationRows = height(L);
totalSegmentRows = height(S);

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

for k = 1:nStates

    idxL = (L.State == k);
    idxS = (S.State == k);

    nPoints = sum(idxL);
    nSegments = sum(idxS);

    if totalLocalizationRows > 0
        fracPoints = nPoints / totalLocalizationRows;
    else
        fracPoints = NaN;
    end

    if totalSegmentRows > 0
        fracSegments = nSegments / totalSegmentRows;
    else
        fracSegments = NaN;
    end

    % Track count: number of trajectories that contain this state at least once
    if ~isempty(L)
        tracksWithState = unique(L.DatasetIndex(idxL));
        nTracksWithState = numel(tracksWithState);
    else
        nTracksWithState = 0;
    end

    if nTraj > 0
        fracTracksWithState = nTracksWithState / nTraj;
    else
        fracTracksWithState = NaN;
    end

    % Dwell time from segments
    if ismember('Duration_s', S.Properties.VariableNames)
        dwellVals = S.Duration_s(idxS);
    elseif ismember('duration_s', S.Properties.VariableNames)
        dwellVals = S.duration_s(idxS);
    else
        dwellVals = [];
    end

    totalDwell_s = sumIgnoringNaN(dwellVals);
    meanDwell_s = meanIgnoringNaN(dwellVals);
    medianDwell_s = medianIgnoringNaN(dwellVals);

    % Segment lengths in points
    if ismember('NPoints', S.Properties.VariableNames)
        segPointVals = S.NPoints(idxS);
    elseif ismember('nPoints', S.Properties.VariableNames)
        segPointVals = S.nPoints(idxS);
    else
        segPointVals = [];
    end

    meanPointsPerSegment = meanIgnoringNaN(segPointVals);
    medianPointsPerSegment = medianIgnoringNaN(segPointVals);

    % Step length statistics from localization table if available
    if ismember('StepLength', L.Properties.VariableNames)
        stepVals = L.StepLength(idxL);
    else
        stepVals = [];
    end

    meanStepLength = meanIgnoringNaN(stepVals);
    medianStepLength = medianIgnoringNaN(stepVals);

    % Velocity if it exists in localization table
    if ismember('Velocity', L.Properties.VariableNames)
        velVals = L.Velocity(idxL);
    else
        velVals = [];
    end

    meanVelocity = meanIgnoringNaN(velVals);
    medianVelocity = medianIgnoringNaN(velVals);

    % Track-level occupancy fraction per state
    trackFracVals = zeros(nTraj,1);
    for i = 1:nTraj
        idxTrack = (L.DatasetIndex == i);
        nTrackPoints = sum(idxTrack);
        if nTrackPoints > 0
            trackFracVals(i) = sum(L.State(idxTrack) == k) / nTrackPoints;
        else
            trackFracVals(i) = NaN;
        end
    end
    meanTrackFraction = meanIgnoringNaN(trackFracVals);
    medianTrackFraction = medianIgnoringNaN(trackFracVals);

    % Build row
    tmp = table();

    tmp.State = k;
    tmp.nPoints = nPoints;
    tmp.fractionOfPoints = fracPoints;
    tmp.nSegments = nSegments;
    tmp.fractionOfSegments = fracSegments;
    tmp.nTracks = nTracksWithState;
    tmp.fractionOfTracks = fracTracksWithState;
    tmp.totalDwell_s = totalDwell_s;
    tmp.meanDwell_s = meanDwell_s;
    tmp.medianDwell_s = medianDwell_s;
    tmp.meanPointsPerSegment = meanPointsPerSegment;
    tmp.medianPointsPerSegment = medianPointsPerSegment;
    tmp.meanStepLength = meanStepLength;
    tmp.medianStepLength = medianStepLength;
    tmp.meanVelocity = meanVelocity;
    tmp.medianVelocity = medianVelocity;
    tmp.meanTrackFraction = meanTrackFraction;
    tmp.medianTrackFraction = medianTrackFraction;

    StateTable = [StateTable; tmp]; %#ok<AGROW>

end

%% --------------------------------------------------------
%% Finalize
%% --------------------------------------------------------

if ~isempty(StateTable)
    StateTable = sortrows(StateTable, {'State'});
end

Project.Tables.State = StateTable;

if ~isfield(Project.Validation, 'AnalysisOK')
    Project.Validation.AnalysisOK = false;
end
Project.Validation.AnalysisOK = true;

Project.Flags.Statistics = true;

fprintf('\n');
fprintf('State rows         : %d\n', height(StateTable));
fprintf('Number of states   : %d\n', nStates);

fprintf('\n');
fprintf('State table created successfully.\n');
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

% =====================================================================
function y = sumIgnoringNaN(x)

if isempty(x)
    y = NaN;
    return;
end

x = x(:);
x = x(~isnan(x));

if isempty(x)
    y = NaN;
else
    y = sum(x);
end

end