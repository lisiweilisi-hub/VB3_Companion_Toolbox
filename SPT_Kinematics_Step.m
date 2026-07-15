function Project = SPT_Kinematics_Step(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_Step
%
% Build step-resolved kinematics from the Localization table.
%
% Input
%   Project.Tables.Localization
%
% Output
%   Project.Analysis.Kinematics.Step
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_Step:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for interface consistency with the other SPT analysis modules.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables) || ...
        ~isscalar(Project.Tables) || ...
        ~isfield(Project.Tables, 'Localization')
    error('SPT_Kinematics_Step:MissingLocalization', ...
        'Project.Tables.Localization not found.');
end

L = Project.Tables.Localization;

if ~istable(L)
    error('SPT_Kinematics_Step:InvalidLocalization', ...
        'Project.Tables.Localization must be a table.');
end

% SPT_Localization publishes StepLength from SPT_CreateGeometry. Copy that
% canonical value; do not reconstruct displacement from X/Y here.
required = {'DatasetIndex','RawIndex','Tid','Frame','Time','State', ...
    'StepLength'};

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, L.Properties.VariableNames)
        error('SPT_Kinematics_Step:MissingColumn', ...
            'Localization table missing column: %s', name);
    end
    value = L.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(L)
        error('SPT_Kinematics_Step:InvalidColumn', ...
            'Localization column %s must be a real numeric vector.', name);
    end
end

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Step\n');
fprintf('=====================================================\n');

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.RequiredColumns = required;
Validation.Source = 'Project.Tables.Localization';
Validation.CanonicalStepLengthSource = 'Localization.StepLength';
Validation.StepOwnership = 'outgoing';
Validation.NInputRows = height(L);
Validation.SortedInternally = false;

if ~isempty(L)
    [L, order] = sortrows(L, {'DatasetIndex','Frame'});
    Validation.SortedInternally = ~isequal(order(:), (1:height(L))');
end

if any(~isfinite(L.DatasetIndex)) || ...
        any(L.DatasetIndex ~= floor(L.DatasetIndex))
    Validation = addIssue(Validation, ...
        'DatasetIndex must contain finite integer values.');
end

if any(~isfinite(L.Frame)) || any(L.Frame ~= floor(L.Frame))
    Validation = addIssue(Validation, ...
        'Frame must contain finite integer values.');
end

Table = buildStepTable(L);
Validation.NStepRows = height(Table);

if height(L) > 1
    sameTrack = L.DatasetIndex(1:end-1) == L.DatasetIndex(2:end);
    consecutive = L.Frame(2:end) == L.Frame(1:end-1) + 1;
    if any(sameTrack & ~consecutive)
        Validation = addIssue(Validation, ...
            'Localization contains duplicate or nonconsecutive frames within a track.');
    end
    if any(sameTrack & (L.RawIndex(1:end-1) ~= L.RawIndex(2:end))) || ...
            any(sameTrack & (L.Tid(1:end-1) ~= L.Tid(2:end)))
        Validation = addIssue(Validation, ...
            'RawIndex and Tid must remain constant within each DatasetIndex.');
    end
end

if ~isempty(Table) && any(~isfinite(Table.DeltaTime) | Table.DeltaTime <= 0)
    Validation = addIssue(Validation, ...
        'Each step must have a positive finite time interval.');
end

ByTrack = summarizeByTrack(Table);
ByState = summarizeByState(Table);
Ensemble = summarizeEnsemble(Table);

Summary = struct();
Summary.nInputRows = height(L);
Summary.nInputTracks = numel(unique(L.DatasetIndex));
Summary.nTracksWithSteps = height(ByTrack);
Summary.nStatesWithSteps = height(ByState);
Summary.nSteps = height(Table);
Summary.nFiniteStepLengths = sum(isfinite(Table.StepLength));
Summary.nFiniteSpeeds = sum(isfinite(Table.Speed));
Summary.nFiniteAccelerations = sum(isfinite(Table.Acceleration));
Summary.TotalDistance = Ensemble.TotalDistance;
Summary.MeanStepLength = Ensemble.MeanStepLength;
Summary.MeanSpeed = Ensemble.MeanSpeed;

Step = struct();
Step.Table = Table;
Step.ByTrack = ByTrack;
Step.ByState = ByState;
Step.Ensemble = Ensemble;
Step.Summary = Summary;
Step.Validation = Validation;

if ~isfield(Project, 'Analysis') || ~isstruct(Project.Analysis) || ...
        ~isscalar(Project.Analysis)
    Project.Analysis = struct();
end
if ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics)
    Project.Analysis.Kinematics = struct();
end
Project.Analysis.Kinematics.Step = Step;

fprintf('Localization rows : %d\n', Summary.nInputRows);
fprintf('Step rows         : %d\n', Summary.nSteps);
fprintf('Tracks with steps : %d\n', Summary.nTracksWithSteps);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function T = buildStepTable(L)

if height(L) < 2
    T = emptyStepTable();
    return
end

sameTrack = L.DatasetIndex(1:end-1) == L.DatasetIndex(2:end);
consecutive = L.Frame(2:end) == L.Frame(1:end-1) + 1;
startRows = find(sameTrack & consecutive);

if isempty(startRows)
    T = emptyStepTable();
    return
end

endRows = startRows + 1;

T = table();
T.DatasetIndex = L.DatasetIndex(startRows);
T.RawIndex = L.RawIndex(startRows);
T.Tid = L.Tid(startRows);
T.StartFrame = L.Frame(startRows);
T.EndFrame = L.Frame(endRows);
T.StartTime = L.Time(startRows);
T.EndTime = L.Time(endRows);
T.DeltaTime = T.EndTime - T.StartTime;
T.State = L.State(startRows);
T.StepLength = L.StepLength(startRows);

T.Speed = nan(height(T), 1);
validTime = isfinite(T.DeltaTime) & T.DeltaTime > 0;
T.Speed(validTime) = T.StepLength(validTime) ./ T.DeltaTime(validTime);

T.Acceleration = nan(height(T), 1);
if height(T) > 1
    adjacentStep = T.DatasetIndex(1:end-1) == T.DatasetIndex(2:end) & ...
        T.EndFrame(1:end-1) == T.StartFrame(2:end);
    elapsed = T.StartTime(2:end) - T.StartTime(1:end-1);
    validAcceleration = adjacentStep & isfinite(elapsed) & elapsed > 0;
    idx = find(validAcceleration);
    T.Acceleration(idx) = (T.Speed(idx + 1) - T.Speed(idx)) ./ elapsed(idx);
end

end

% =====================================================================
function T = emptyStepTable()

T = table();
T.DatasetIndex = zeros(0, 1);
T.RawIndex = zeros(0, 1);
T.Tid = zeros(0, 1);
T.StartFrame = zeros(0, 1);
T.EndFrame = zeros(0, 1);
T.StartTime = zeros(0, 1);
T.EndTime = zeros(0, 1);
T.DeltaTime = zeros(0, 1);
T.State = zeros(0, 1);
T.StepLength = zeros(0, 1);
T.Speed = zeros(0, 1);
T.Acceleration = zeros(0, 1);

end

% =====================================================================
function T = summarizeByTrack(S)

T = emptyTrackTable();
trackIDs = unique(S.DatasetIndex);

for i = 1:numel(trackIDs)
    idx = S.DatasetIndex == trackIDs(i);
    row = table();
    first = find(idx, 1, 'first');
    row.DatasetIndex = trackIDs(i);
    row.RawIndex = S.RawIndex(first);
    row.Tid = S.Tid(first);
    row.NSteps = sum(idx);
    row.NFiniteSteps = sum(isfinite(S.StepLength(idx)));
    row.TotalDistance = sumIgnoringNaN(S.StepLength(idx));
    row.MeanStepLength = meanIgnoringNaN(S.StepLength(idx));
    row.MedianStepLength = medianIgnoringNaN(S.StepLength(idx));
    row.MeanSpeed = meanIgnoringNaN(S.Speed(idx));
    row.MedianSpeed = medianIgnoringNaN(S.Speed(idx));
    row.MeanAcceleration = meanIgnoringNaN(S.Acceleration(idx));
    T = [T; row]; %#ok<AGROW>
end

end

% =====================================================================
function T = emptyTrackTable()

T = table();
T.DatasetIndex = zeros(0, 1);
T.RawIndex = zeros(0, 1);
T.Tid = zeros(0, 1);
T.NSteps = zeros(0, 1);
T.NFiniteSteps = zeros(0, 1);
T.TotalDistance = zeros(0, 1);
T.MeanStepLength = zeros(0, 1);
T.MedianStepLength = zeros(0, 1);
T.MeanSpeed = zeros(0, 1);
T.MedianSpeed = zeros(0, 1);
T.MeanAcceleration = zeros(0, 1);

end

% =====================================================================
function T = summarizeByState(S)

T = emptyStateTable();
states = unique(S.State(isfinite(S.State)));

for i = 1:numel(states)
    idx = S.State == states(i);
    row = table();
    row.State = states(i);
    row.NSteps = sum(idx);
    row.NTracks = numel(unique(S.DatasetIndex(idx)));
    row.NFiniteSteps = sum(isfinite(S.StepLength(idx)));
    row.TotalDistance = sumIgnoringNaN(S.StepLength(idx));
    row.MeanStepLength = meanIgnoringNaN(S.StepLength(idx));
    row.MedianStepLength = medianIgnoringNaN(S.StepLength(idx));
    row.MeanSpeed = meanIgnoringNaN(S.Speed(idx));
    row.MedianSpeed = medianIgnoringNaN(S.Speed(idx));
    row.MeanAcceleration = meanIgnoringNaN(S.Acceleration(idx));
    T = [T; row]; %#ok<AGROW>
end

end

% =====================================================================
function T = emptyStateTable()

T = table();
T.State = zeros(0, 1);
T.NSteps = zeros(0, 1);
T.NTracks = zeros(0, 1);
T.NFiniteSteps = zeros(0, 1);
T.TotalDistance = zeros(0, 1);
T.MeanStepLength = zeros(0, 1);
T.MedianStepLength = zeros(0, 1);
T.MeanSpeed = zeros(0, 1);
T.MedianSpeed = zeros(0, 1);
T.MeanAcceleration = zeros(0, 1);

end

% =====================================================================
function E = summarizeEnsemble(S)

E = struct();
E.NSteps = height(S);
E.NTracks = numel(unique(S.DatasetIndex));
E.NStates = numel(unique(S.State(isfinite(S.State))));
E.NFiniteSteps = sum(isfinite(S.StepLength));
E.TotalDistance = sumIgnoringNaN(S.StepLength);
E.MeanStepLength = meanIgnoringNaN(S.StepLength);
E.MedianStepLength = medianIgnoringNaN(S.StepLength);
E.StdStepLength = stdIgnoringNaN(S.StepLength);
E.MeanSpeed = meanIgnoringNaN(S.Speed);
E.MedianSpeed = medianIgnoringNaN(S.Speed);
E.StdSpeed = stdIgnoringNaN(S.Speed);
E.MeanAcceleration = meanIgnoringNaN(S.Acceleration);
E.MedianAcceleration = medianIgnoringNaN(S.Acceleration);
E.StdAcceleration = stdIgnoringNaN(S.Acceleration);

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end

% =====================================================================
function y = sumIgnoringNaN(x)

x = x(:);
x = x(~isnan(x));
if isempty(x)
    y = 0;
else
    y = sum(x);
end

end

% =====================================================================
function y = meanIgnoringNaN(x)

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

x = x(:);
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = median(x);
end

end

% =====================================================================
function y = stdIgnoringNaN(x)

x = x(:);
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = std(x);
end

end
