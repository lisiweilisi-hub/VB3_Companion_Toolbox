function Project = SPT_Kinematics_MSD(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_MSD
%
% Initialize MSD analysis from trajectory-sample kinematics.
%
% Input
%   Project.Analysis.Kinematics.TrajectorySamples
%
% Output
%   Project.Analysis.Kinematics.MSD
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_MSD:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for future MSD configuration.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Analysis') || ...
        ~isstruct(Project.Analysis) || ~isscalar(Project.Analysis) || ...
        ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics) || ...
        ~isfield(Project.Analysis.Kinematics, 'TrajectorySamples') || ...
        ~isstruct(Project.Analysis.Kinematics.TrajectorySamples) || ...
        ~isscalar(Project.Analysis.Kinematics.TrajectorySamples)
    error('SPT_Kinematics_MSD:MissingTrajectorySamples', ...
        ['Project.Analysis.Kinematics.TrajectorySamples ' ...
        'not found.']);
end

TrajectorySamples = Project.Analysis.Kinematics.TrajectorySamples;
if ~isfield(TrajectorySamples, 'Samples') || ...
        ~istable(TrajectorySamples.Samples)
    error('SPT_Kinematics_MSD:InvalidSamples', ...
        'TrajectorySamples.Samples must be a table.');
end
if ~isfield(TrajectorySamples, 'ByTrack') || ...
        ~istable(TrajectorySamples.ByTrack)
    error('SPT_Kinematics_MSD:InvalidByTrack', ...
        'TrajectorySamples.ByTrack must be a table.');
end

requiredSamples = ...
    {'DatasetIndex','RawIndex','Tid','Frame','Time','X','Y'};
requiredByTrack = {'DatasetIndex','RawIndex','Tid','NSamples', ...
    'NFinitePositions','NPairs','NFinitePairs','MaxLag', ...
    'MeanTimeInterval','MSDEligible'};
validateNumericColumns(TrajectorySamples.Samples, requiredSamples, ...
    'Samples');
validateByTrack(TrajectorySamples.ByTrack, requiredByTrack);

[Samples, samplesSortedInternally] = ...
    normalizeTable(TrajectorySamples.Samples(:, requiredSamples), ...
    {'DatasetIndex','Frame'});
[ByTrack, tracksSortedInternally] = ...
    normalizeTable(TrajectorySamples.ByTrack(:, requiredByTrack), ...
    {'DatasetIndex'});

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.Source = ...
    'Project.Analysis.Kinematics.TrajectorySamples';
Validation.Upstream = readUpstreamValidation(TrajectorySamples);
Validation.RequiredSampleColumns = requiredSamples;
Validation.RequiredByTrackColumns = requiredByTrack;
Validation.NInputSamples = height(Samples);
Validation.NInputTrajectories = height(ByTrack);
Validation.SamplesSortedInternally = samplesSortedInternally;
Validation.TracksSortedInternally = tracksSortedInternally;

if any(~isfinite(Samples.DatasetIndex)) || ...
        any(Samples.DatasetIndex ~= floor(Samples.DatasetIndex))
    Validation = addIssue(Validation, ...
        'Samples.DatasetIndex must contain finite integer values.');
end
if any(~isfinite(Samples.Frame)) || ...
        any(Samples.Frame ~= floor(Samples.Frame))
    Validation = addIssue(Validation, ...
        'Samples.Frame must contain finite integer values.');
end
if any(~isfinite(Samples.RawIndex)) || any(~isfinite(Samples.Tid))
    Validation = addIssue(Validation, ...
        'Samples.RawIndex and Samples.Tid must contain finite values.');
end
if any(~isfinite(Samples.Time))
    Validation = addIssue(Validation, ...
        'Samples.Time must contain finite values.');
end
if any(~isfinite(Samples.X)) || any(~isfinite(Samples.Y))
    Validation = addIssue(Validation, ...
        'Samples.X and Samples.Y must contain finite coordinates.');
end

if height(Samples) > 1
    sampleKeys = [double(Samples.DatasetIndex) double(Samples.Frame)];
    if size(unique(sampleKeys, 'rows'), 1) ~= height(Samples)
        Validation = addIssue(Validation, ...
            'Samples must have unique (DatasetIndex, Frame) rows.');
    end
end

[orderingOK, identifiersOK] = validateWithinTracks(Samples);
if ~orderingOK
    Validation = addIssue(Validation, ...
        ['Samples.Frame and Samples.Time must be strictly increasing ' ...
        'within each DatasetIndex.']);
end
if ~identifiersOK
    Validation = addIssue(Validation, ...
        ['Samples.RawIndex and Samples.Tid must remain constant ' ...
        'within each DatasetIndex.']);
end

if any(~isfinite(ByTrack.DatasetIndex)) || ...
        any(ByTrack.DatasetIndex ~= floor(ByTrack.DatasetIndex))
    Validation = addIssue(Validation, ...
        'ByTrack.DatasetIndex must contain finite integer values.');
end
if numel(unique(ByTrack.DatasetIndex)) ~= height(ByTrack)
    Validation = addIssue(Validation, ...
        'ByTrack.DatasetIndex must be unique for each trajectory.');
end

countColumns = {'NSamples','NFinitePositions','NPairs', ...
    'NFinitePairs','MaxLag'};
for i = 1:numel(countColumns)
    value = ByTrack.(countColumns{i});
    if any(~isfinite(value)) || any(value < 0) || ...
            any(value ~= floor(value))
        Validation = addIssue(Validation, sprintf( ...
            'ByTrack.%s must contain nonnegative integer values.', ...
            countColumns{i}));
    end
end
if any(ByTrack.NFinitePositions > ByTrack.NSamples) || ...
        any(ByTrack.NFinitePairs > ByTrack.NPairs) || ...
        any(ByTrack.NPairs > max(ByTrack.NSamples - 1, 0)) || ...
        any(ByTrack.MaxLag > max(ByTrack.NSamples - 1, 0))
    Validation = addIssue(Validation, ...
        'ByTrack sample, pair, and lag counts are inconsistent.');
end
if any(ByTrack.NSamples > 1 & ...
        (~isfinite(ByTrack.MeanTimeInterval) | ...
        ByTrack.MeanTimeInterval <= 0))
    Validation = addIssue(Validation, ...
        ['ByTrack.MeanTimeInterval must be positive and finite when ' ...
        'multiple samples are present.']);
end

if sum(ByTrack.NSamples) ~= height(Samples)
    Validation = addIssue(Validation, ...
        'ByTrack.NSamples must account for every Samples row.');
end
if ~trackIdentifiersMatch(Samples, ByTrack)
    Validation = addIssue(Validation, ...
        'Samples and ByTrack must contain the same DatasetIndex values.');
end
if ~trackMetadataMatchesSamples(Samples, ByTrack)
    Validation = addIssue(Validation, ...
        'ByTrack sample metadata must agree with Samples.');
end

Validation.LocalOK = Validation.OK;
if ~Validation.Upstream.OK
    Validation = addIssue(Validation, ...
        'Upstream TrajectorySamples validation is missing, invalid, or failed.');
end
Validation.OK = Validation.LocalOK && Validation.Upstream.OK;

[ByTrack, Ensemble, coreNumericsOK] = ...
    calculateCoreMSD(Samples, ByTrack, Validation.OK);
if ~coreNumericsOK
    Validation = addIssue(Validation, ...
        ['MSD displacement, squared-distance, and lag-time ' ...
        'calculations must remain finite.']);
    Validation.LocalOK = false;
    Validation.OK = false;
    [ByTrack, Ensemble] = calculateCoreMSD(Samples, ByTrack, false);
end

Summary = struct();
Summary.nSamples = Ensemble.NSamples;
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nPairs = Ensemble.NPairs;
Summary.nFinitePairs = Ensemble.NFinitePairs;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.MaxLagAvailable = Ensemble.MaxLagAvailable;
Summary.nComputedTrajectories = Ensemble.NComputedTrajectories;
Summary.nComputedLags = numel(Ensemble.Lag);
Summary.nMSDPairs = sum(Ensemble.PairsByLag);
Summary.Status = 'Core';

MSD = struct();
MSD.ByTrack = ByTrack;
MSD.Ensemble = Ensemble;
MSD.Summary = Summary;
MSD.Validation = Validation;

Project.Analysis.Kinematics.MSD = MSD;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics MSD\n');
fprintf('=====================================================\n');
fprintf('Sample rows       : %d\n', Summary.nSamples);
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('MSD status        : %s\n', Summary.Status);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateNumericColumns(T, required, tableName)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_MSD:MissingColumn', ...
            'TrajectorySamples.%s missing column: %s', ...
            tableName, name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_MSD:InvalidColumn', ...
            ['TrajectorySamples.%s column %s must be a real ' ...
            'numeric vector.'], tableName, name);
    end
end

end

% =====================================================================
function validateByTrack(T, required)

numericColumns = required(1:end - 1);
validateNumericColumns(T, numericColumns, 'ByTrack');

name = required{end};
if ~ismember(name, T.Properties.VariableNames)
    error('SPT_Kinematics_MSD:MissingColumn', ...
        'TrajectorySamples.ByTrack missing column: %s', name);
end
value = T.(name);
validType = islogical(value) || (isnumeric(value) && isreal(value));
if ~validType || ~isvector(value) || numel(value) ~= height(T) || ...
        any(~isfinite(value)) || any(~(value == 0 | value == 1))
    error('SPT_Kinematics_MSD:InvalidColumn', ...
        ['TrajectorySamples.ByTrack column MSDEligible must be a ' ...
        'logical vector.']);
end

end

% =====================================================================
function [T, sortedInternally] = normalizeTable(T, columns)

sortedInternally = false;
if isempty(T)
    return
end

[T, order] = sortrows(T, columns);
sortedInternally = ~isequal(order(:), (1:height(T))');

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
function tf = trackIdentifiersMatch(Samples, ByTrack)

sampleIDs = unique(Samples.DatasetIndex(isfinite(Samples.DatasetIndex)));
trackIDs = unique(ByTrack.DatasetIndex(isfinite(ByTrack.DatasetIndex)));
tf = isequal(double(sampleIDs(:)), double(trackIDs(:)));

end

% =====================================================================
function Upstream = readUpstreamValidation(TrajectorySamples)

Upstream = struct();
Upstream.Source = ...
    'Project.Analysis.Kinematics.TrajectorySamples.Validation';
Upstream.Available = false;
Upstream.OK = false;
Upstream.Issues = {};

if ~isfield(TrajectorySamples, 'Validation') || ...
        ~isstruct(TrajectorySamples.Validation) || ...
        ~isscalar(TrajectorySamples.Validation) || ...
        ~isfield(TrajectorySamples.Validation, 'OK')
    Upstream.Issues{end + 1, 1} = ...
        'TrajectorySamples.Validation.OK not found.';
    return
end

value = TrajectorySamples.Validation.OK;
Upstream.Available = true;
if ~isscalar(value) || ...
        ~(islogical(value) || (isnumeric(value) && isreal(value))) || ...
        (isnumeric(value) && (~isfinite(value) || ...
        ~(value == 0 || value == 1)))
    Upstream.Issues{end + 1, 1} = ...
        'TrajectorySamples.Validation.OK must be a logical scalar.';
    return
end

Upstream.OK = logical(value);
if ~Upstream.OK
    Upstream.Issues{end + 1, 1} = ...
        'TrajectorySamples.Validation.OK is false.';
end

end

% =====================================================================
function tf = trackMetadataMatchesSamples(Samples, ByTrack)

tf = true;
for i = 1:height(ByTrack)
    rows = find(Samples.DatasetIndex == ByTrack.DatasetIndex(i));
    nSamples = numel(rows);
    nFinitePositions = sum(isfinite(Samples.X(rows)) & ...
        isfinite(Samples.Y(rows)));
    nPairs = max(nSamples - 1, 0);
    if nSamples > 1
        finitePosition = isfinite(Samples.X(rows)) & ...
            isfinite(Samples.Y(rows));
        nFinitePairs = sum(finitePosition(1:end - 1) & ...
            finitePosition(2:end));
    else
        nFinitePairs = 0;
    end

    if nSamples == 0 || ByTrack.NSamples(i) ~= nSamples || ...
            ByTrack.NFinitePositions(i) ~= nFinitePositions || ...
            ByTrack.NPairs(i) ~= nPairs || ...
            ByTrack.NFinitePairs(i) ~= nFinitePairs || ...
            ByTrack.MaxLag(i) ~= nPairs || ...
            ByTrack.RawIndex(i) ~= Samples.RawIndex(rows(1)) || ...
            ByTrack.Tid(i) ~= Samples.Tid(rows(1))
        tf = false;
        return
    end
end

end

% =====================================================================
function [ByTrack, E, coreNumericsOK] = ...
        calculateCoreMSD(Samples, ByTrack, validationOK)

nTracks = height(ByTrack);
ByTrack.Lag = cell(nTracks, 1);
ByTrack.LagTime = cell(nTracks, 1);
ByTrack.MSD = cell(nTracks, 1);
ByTrack.MSDX = cell(nTracks, 1);
ByTrack.MSDY = cell(nTracks, 1);
ByTrack.MSDPairCount = cell(nTracks, 1);
ByTrack.NComputedLags = zeros(nTracks, 1);
ByTrack.NMSDPairs = zeros(nTracks, 1);
ByTrack.MSDComputed = false(nTracks, 1);

calculationEligible = logical(ByTrack.MSDEligible) & ...
    logical(validationOK);
if any(calculationEligible)
    maxLagGlobal = max(ByTrack.MaxLag(calculationEligible));
else
    maxLagGlobal = 0;
end

sumSquared = zeros(maxLagGlobal, 1);
sumSquaredX = zeros(maxLagGlobal, 1);
sumSquaredY = zeros(maxLagGlobal, 1);
sumLagTime = zeros(maxLagGlobal, 1);
pairsByLag = zeros(maxLagGlobal, 1);
trajectoryMSD = nan(nTracks, maxLagGlobal);
coreNumericsOK = true;

for i = 1:nTracks
    if ~calculationEligible(i)
        ByTrack.Lag{i} = zeros(0, 1);
        ByTrack.LagTime{i} = zeros(0, 1);
        ByTrack.MSD{i} = zeros(0, 1);
        ByTrack.MSDX{i} = zeros(0, 1);
        ByTrack.MSDY{i} = zeros(0, 1);
        ByTrack.MSDPairCount{i} = zeros(0, 1);
        continue
    end

    rows = find(Samples.DatasetIndex == ByTrack.DatasetIndex(i));
    nLag = min(ByTrack.MaxLag(i), numel(rows) - 1);
    lag = (1:nLag)';
    lagTime = nan(nLag, 1);
    msd = nan(nLag, 1);
    msdX = nan(nLag, 1);
    msdY = nan(nLag, 1);
    pairCount = zeros(nLag, 1);

    x = double(Samples.X(rows));
    y = double(Samples.Y(rows));
    time = double(Samples.Time(rows));
    for j = 1:nLag
        dx = x(1 + j:end) - x(1:end - j);
        dy = y(1 + j:end) - y(1:end - j);
        deltaTime = time(1 + j:end) - time(1:end - j);
        finiteDifference = isfinite(dx) & isfinite(dy) & ...
            isfinite(deltaTime) & deltaTime > 0;
        squaredX = dx .^ 2;
        squaredY = dy .^ 2;
        squared = squaredX + squaredY;
        finiteSquared = isfinite(squaredX) & isfinite(squaredY) & ...
            isfinite(squared);
        if any(~finiteDifference) || ...
                any(finiteDifference & ~finiteSquared)
            coreNumericsOK = false;
        end
        validPair = finiteDifference & finiteSquared;
        pairCount(j) = sum(validPair);
        if pairCount(j) == 0
            continue
        end

        validSquaredX = squaredX(validPair);
        validSquaredY = squaredY(validPair);
        validSquared = squared(validPair);
        msd(j) = mean(validSquared);
        msdX(j) = mean(validSquaredX);
        msdY(j) = mean(validSquaredY);
        lagTime(j) = mean(deltaTime(validPair));

        sumSquared(j) = sumSquared(j) + sum(validSquared);
        sumSquaredX(j) = sumSquaredX(j) + sum(validSquaredX);
        sumSquaredY(j) = sumSquaredY(j) + sum(validSquaredY);
        sumLagTime(j) = sumLagTime(j) + sum(deltaTime(validPair));
        pairsByLag(j) = pairsByLag(j) + pairCount(j);
    end

    ByTrack.Lag{i} = lag;
    ByTrack.LagTime{i} = lagTime;
    ByTrack.MSD{i} = msd;
    ByTrack.MSDX{i} = msdX;
    ByTrack.MSDY{i} = msdY;
    ByTrack.MSDPairCount{i} = pairCount;
    ByTrack.NComputedLags(i) = sum(pairCount > 0);
    ByTrack.NMSDPairs(i) = sum(pairCount);
    ByTrack.MSDComputed(i) = ByTrack.NComputedLags(i) > 0;
    trajectoryMSD(i, 1:nLag) = msd(:)';
end

E = struct();
E.NSamples = height(Samples);
E.NTrajectories = height(ByTrack);
E.NPairs = sum(ByTrack.NPairs);
E.NFinitePairs = sum(ByTrack.NFinitePairs);
E.NEligibleTrajectories = sum(logical(ByTrack.MSDEligible));
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
else
    E.EligibleFraction = ...
        E.NEligibleTrajectories / E.NTrajectories;
end
if isempty(ByTrack)
    E.MaxLagAvailable = 0;
else
    E.MaxLagAvailable = max(ByTrack.MaxLag);
end
E.NComputedTrajectories = sum(ByTrack.MSDComputed);
E.Lag = (1:maxLagGlobal)';
E.LagTime = nan(maxLagGlobal, 1);
E.PooledMSD = nan(maxLagGlobal, 1);
E.PooledMSDX = nan(maxLagGlobal, 1);
E.PooledMSDY = nan(maxLagGlobal, 1);
E.PairsByLag = pairsByLag;
validLag = pairsByLag > 0;
E.LagTime(validLag) = sumLagTime(validLag) ./ pairsByLag(validLag);
E.PooledMSD(validLag) = sumSquared(validLag) ./ pairsByLag(validLag);
E.PooledMSDX(validLag) = ...
    sumSquaredX(validLag) ./ pairsByLag(validLag);
E.PooledMSDY(validLag) = ...
    sumSquaredY(validLag) ./ pairsByLag(validLag);
[E.TrajectoryMeanMSD, E.TrajectorySEMMSD, ...
    E.NTrajectoriesByLag] = summarizeTrajectoryMSD(trajectoryMSD);

end

% =====================================================================
function [meanMSD, semMSD, nByLag] = summarizeTrajectoryMSD(values)

nLag = size(values, 2);
meanMSD = nan(nLag, 1);
semMSD = nan(nLag, 1);
nByLag = zeros(nLag, 1);
for i = 1:nLag
    column = values(:, i);
    column = column(isfinite(column));
    nByLag(i) = numel(column);
    if isempty(column)
        continue
    end
    meanMSD(i) = mean(column);
    if numel(column) == 1
        semMSD(i) = 0;
    else
        semMSD(i) = std(column, 0) / sqrt(numel(column));
    end
end

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end
