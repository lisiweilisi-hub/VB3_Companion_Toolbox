function Project = SPT_Kinematics_TrajectorySamples(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_TrajectorySamples
%
% Publish ordered trajectory samples for position-resolved analyses.
%
% Input
%   Project.Tables.Localization
%   Project.Validation.LocalizationOK
%
% Output
%   Project.Analysis.Kinematics.TrajectorySamples
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_TrajectorySamples:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for interface consistency with the other SPT analysis modules.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables) || ...
        ~isscalar(Project.Tables) || ...
        ~isfield(Project.Tables, 'Localization')
    error('SPT_Kinematics_TrajectorySamples:MissingLocalization', ...
        'Project.Tables.Localization not found.');
end

Localization = Project.Tables.Localization;
if ~istable(Localization)
    error('SPT_Kinematics_TrajectorySamples:InvalidLocalization', ...
        'Project.Tables.Localization must be a table.');
end

required = {'DatasetIndex','RawIndex','Tid','Frame','Time','X','Y'};
validateLocalization(Localization, required);

Samples = Localization(:, required);
sortedInternally = false;
if ~isempty(Samples)
    [Samples, order] = sortrows(Samples, {'DatasetIndex','Frame'});
    sortedInternally = ~isequal(order(:), (1:height(Samples))');
end

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.Source = 'Project.Tables.Localization';
Validation.Upstream = readUpstreamValidation(Project);
Validation.RequiredColumns = required;
Validation.JoinKey = 'DatasetIndex';
Validation.SampleKey = {'DatasetIndex','Frame'};
Validation.NInputRows = height(Localization);
Validation.NSampleRows = height(Samples);
Validation.SortedInternally = sortedInternally;

identifierColumns = {'DatasetIndex','RawIndex','Tid','Frame'};
for i = 1:numel(identifierColumns)
    name = identifierColumns{i};
    if any(~isfinite(Samples.(name)))
        Validation = addIssue(Validation, ...
            sprintf('%s must contain finite identifiers.', name));
    end
end

if any(Samples.DatasetIndex ~= floor(Samples.DatasetIndex))
    Validation = addIssue(Validation, ...
        'DatasetIndex must contain integer values.');
end
if any(Samples.Frame ~= floor(Samples.Frame))
    Validation = addIssue(Validation, ...
        'Frame must contain integer values.');
end
if any(~isfinite(Samples.Time))
    Validation = addIssue(Validation, ...
        'Time must contain finite values.');
end
if any(~isfinite(Samples.X)) || any(~isfinite(Samples.Y))
    Validation = addIssue(Validation, ...
        'X and Y must contain finite coordinates.');
end

if height(Samples) > 1
    keys = [Samples.DatasetIndex Samples.Frame];
    if size(unique(keys, 'rows'), 1) ~= height(Samples)
        Validation = addIssue(Validation, ...
            '(DatasetIndex, Frame) rows must be unique.');
    end
end

[orderingOK, identifiersOK] = validateWithinTracks(Samples);
if ~orderingOK
    Validation = addIssue(Validation, ...
        'Frame and Time must be strictly increasing within each DatasetIndex.');
end
if ~identifiersOK
    Validation = addIssue(Validation, ...
        'RawIndex and Tid must remain constant within each DatasetIndex.');
end

Validation.LocalOK = Validation.OK;
if ~Validation.Upstream.OK
    Validation = addIssue(Validation, ...
        'Upstream localization validation is missing, invalid, or failed.');
end
Validation.OK = Validation.LocalOK && Validation.Upstream.OK;

ByTrack = summarizeByTrack(Samples);
ByTrack = addCoreCalculations(ByTrack, Samples, ...
    Validation.Upstream.OK);
Ensemble = summarizeEnsemble(Samples, ByTrack);

Summary = struct();
Summary.nSamples = Ensemble.NSamples;
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nFinitePositions = Ensemble.NFinitePositions;
Summary.nPairs = Ensemble.NPairs;
Summary.nFinitePairs = Ensemble.NFinitePairs;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.MeanTimeInterval = Ensemble.MeanTimeInterval;
Summary.TotalDuration = Ensemble.TotalDuration;
Summary.JoinKey = 'DatasetIndex';

TrajectorySamples = struct();
TrajectorySamples.Samples = Samples;
TrajectorySamples.ByTrack = ByTrack;
TrajectorySamples.Ensemble = Ensemble;
TrajectorySamples.Summary = Summary;
TrajectorySamples.Validation = Validation;

if ~isfield(Project, 'Analysis') || ~isstruct(Project.Analysis) || ...
        ~isscalar(Project.Analysis)
    Project.Analysis = struct();
end
if ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics)
    Project.Analysis.Kinematics = struct();
end
Project.Analysis.Kinematics.TrajectorySamples = TrajectorySamples;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Trajectory Samples\n');
fprintf('=====================================================\n');
fprintf('Sample rows       : %d\n', Summary.nSamples);
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateLocalization(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_TrajectorySamples:MissingColumn', ...
            'Localization table missing column: %s', name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_TrajectorySamples:InvalidColumn', ...
            'Localization column %s must be a real numeric vector.', name);
    end
end

end

% =====================================================================
function Upstream = readUpstreamValidation(Project)

Upstream = struct();
Upstream.Source = 'Project.Validation.LocalizationOK';
Upstream.Available = false;
Upstream.OK = false;
Upstream.Issues = {};

if ~isfield(Project, 'Validation') || ...
        ~isstruct(Project.Validation) || ~isscalar(Project.Validation) || ...
        ~isfield(Project.Validation, 'LocalizationOK')
    Upstream.Issues{end + 1, 1} = ...
        'Project.Validation.LocalizationOK not found.';
    return
end

value = Project.Validation.LocalizationOK;
Upstream.Available = true;
if ~isscalar(value) || ...
        ~(islogical(value) || (isnumeric(value) && isreal(value))) || ...
        (isnumeric(value) && (~isfinite(value) || ...
        ~(value == 0 || value == 1)))
    Upstream.Issues{end + 1, 1} = ...
        'Project.Validation.LocalizationOK must be a logical scalar.';
    return
end

Upstream.OK = logical(value);
if ~Upstream.OK
    Upstream.Issues{end + 1, 1} = ...
        'Project.Validation.LocalizationOK is false.';
end

end

% =====================================================================
function [orderingOK, identifiersOK] = validateWithinTracks(T)

orderingOK = true;
identifiersOK = true;
trackIDs = unique(T.DatasetIndex(isfinite(T.DatasetIndex)));

for i = 1:numel(trackIDs)
    idx = T.DatasetIndex == trackIDs(i);
    frames = T.Frame(idx);
    times = T.Time(idx);
    if numel(frames) > 1 && ...
            (any(diff(frames) <= 0) || any(diff(times) <= 0))
        orderingOK = false;
    end
    if numel(unique(T.RawIndex(idx))) ~= 1 || ...
            numel(unique(T.Tid(idx))) ~= 1
        identifiersOK = false;
    end
end

end

% =====================================================================
function T = summarizeByTrack(S)

T = emptyByTrackTable();
trackIDs = unique(S.DatasetIndex(isfinite(S.DatasetIndex)));

for i = 1:numel(trackIDs)
    idx = S.DatasetIndex == trackIDs(i);
    rows = find(idx);
    row = table();
    row.DatasetIndex = trackIDs(i);
    row.RawIndex = S.RawIndex(rows(1));
    row.Tid = S.Tid(rows(1));
    row.NSamples = numel(rows);
    row.NFinitePositions = sum(isfinite(S.X(rows)) & isfinite(S.Y(rows)));
    row.StartFrame = S.Frame(rows(1));
    row.EndFrame = S.Frame(rows(end));
    row.StartTime = S.Time(rows(1));
    row.EndTime = S.Time(rows(end));
    row.Duration = row.EndTime - row.StartTime;
    T = [T; row]; %#ok<AGROW>
end

end

% =====================================================================
function T = emptyByTrackTable()

T = table();
T.DatasetIndex = zeros(0, 1);
T.RawIndex = zeros(0, 1);
T.Tid = zeros(0, 1);
T.NSamples = zeros(0, 1);
T.NFinitePositions = zeros(0, 1);
T.StartFrame = zeros(0, 1);
T.EndFrame = zeros(0, 1);
T.StartTime = zeros(0, 1);
T.EndTime = zeros(0, 1);
T.Duration = zeros(0, 1);

end

% =====================================================================
function T = addCoreCalculations(T, S, upstreamOK)

n = height(T);
T.NPairs = zeros(n, 1);
T.NFinitePairs = zeros(n, 1);
T.MaxLag = zeros(n, 1);
T.MeanFrameInterval = nan(n, 1);
T.MeanTimeInterval = nan(n, 1);
T.UniformFrameInterval = false(n, 1);
T.UniformTimeInterval = false(n, 1);
T.MSDEligible = false(n, 1);

for i = 1:n
    rows = find(S.DatasetIndex == T.DatasetIndex(i));
    frameIntervals = diff(S.Frame(rows));
    timeIntervals = diff(S.Time(rows));
    finitePosition = isfinite(S.X(rows)) & isfinite(S.Y(rows));

    T.NPairs(i) = max(numel(rows) - 1, 0);
    if numel(rows) > 1
        T.NFinitePairs(i) = sum(finitePosition(1:end-1) & ...
            finitePosition(2:end));
        T.MaxLag(i) = numel(rows) - 1;
        T.MeanFrameInterval(i) = mean(frameIntervals);
        T.MeanTimeInterval(i) = mean(timeIntervals);
        T.UniformFrameInterval(i) = isUniformInterval(frameIntervals);
        T.UniformTimeInterval(i) = isUniformInterval(timeIntervals);
    else
        T.NFinitePairs(i) = 0;
        T.MaxLag(i) = 0;
        T.MeanFrameInterval(i) = NaN;
        T.MeanTimeInterval(i) = NaN;
        T.UniformFrameInterval(i) = false;
        T.UniformTimeInterval(i) = false;
    end

    identifiersValid = isfinite(T.DatasetIndex(i)) && ...
        T.DatasetIndex(i) == floor(T.DatasetIndex(i)) && ...
        all(isfinite(S.RawIndex(rows))) && ...
        all(isfinite(S.Tid(rows))) && ...
        numel(unique(S.RawIndex(rows))) == 1 && ...
        numel(unique(S.Tid(rows))) == 1;
    orderingValid = all(isfinite(S.Frame(rows))) && ...
        all(S.Frame(rows) == floor(S.Frame(rows))) && ...
        all(isfinite(S.Time(rows))) && ...
        all(frameIntervals > 0) && all(timeIntervals > 0);
    positionsValid = all(finitePosition);

    T.MSDEligible(i) = logical(upstreamOK) && numel(rows) >= 2 && ...
        identifiersValid && orderingValid && positionsValid;
end

end

% =====================================================================
function tf = isUniformInterval(intervals)

if isempty(intervals) || any(~isfinite(intervals)) || ...
        any(intervals <= 0)
    tf = false;
    return
end

reference = intervals(1);
scale = max(1, max(abs(intervals)));
tf = all(abs(intervals - reference) <= 1e-12 * scale);

end

% =====================================================================
function E = summarizeEnsemble(S, T)

E = struct();
E.NSamples = height(S);
E.NTrajectories = height(T);
E.NFinitePositions = sum(isfinite(S.X) & isfinite(S.Y));
E.NPairs = sum(T.NPairs);
E.NFinitePairs = sum(T.NFinitePairs);
E.NEligibleTrajectories = sum(T.MSDEligible);
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
else
    E.EligibleFraction = E.NEligibleTrajectories / E.NTrajectories;
end
E.MeanFrameInterval = meanIgnoringNaN(T.MeanFrameInterval);
E.MeanTimeInterval = meanIgnoringNaN(T.MeanTimeInterval);
E.TotalDuration = sum(T.Duration(isfinite(T.Duration)));

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
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end
