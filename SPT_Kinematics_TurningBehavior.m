function Project = SPT_Kinematics_TurningBehavior(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_TurningBehavior
%
% Calculate angle-resolved and segment-resolved turning behavior from
% frozen kinematics outputs.  The final behavior-classification taxonomy
% is intentionally reserved for a later release.
%
% Input
%   Project.Analysis.Kinematics.TrajectorySamples
%   Project.Analysis.Kinematics.Trajectory
%
% Output
%   Project.Analysis.Kinematics.TurningBehavior
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_TurningBehavior:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for future turning-behavior configuration.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Analysis') || ...
        ~isstruct(Project.Analysis) || ~isscalar(Project.Analysis) || ...
        ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics)
    error('SPT_Kinematics_TurningBehavior:MissingKinematics', ...
        'Project.Analysis.Kinematics not found.');
end

Kinematics = Project.Analysis.Kinematics;
requiredModules = {'TrajectorySamples','Trajectory'};
for i = 1:numel(requiredModules)
    name = requiredModules{i};
    if ~isfield(Kinematics, name) || ...
            ~isstruct(Kinematics.(name)) || ...
            ~isscalar(Kinematics.(name))
        error('SPT_Kinematics_TurningBehavior:MissingInput', ...
            'Project.Analysis.Kinematics.%s not found.', name);
    end
end

TrajectorySamples = Kinematics.TrajectorySamples;
Trajectory = Kinematics.Trajectory;
validateContainer(TrajectorySamples, 'TrajectorySamples');
validateContainer(Trajectory, 'Trajectory');

sampleColumns = {'DatasetIndex','RawIndex','Tid','Frame','Time','X','Y'};
trajectoryColumns = {'DatasetIndex','RawIndex','Tid'};
validateNumericColumns(TrajectorySamples.Samples, sampleColumns, ...
    'TrajectorySamples.Samples');
validateNumericColumns(Trajectory.ByTrack, trajectoryColumns, ...
    'Trajectory.ByTrack');

[Samples, samplesSorted] = normalizeSamples( ...
    TrajectorySamples.Samples(:, sampleColumns));
[ByTrack, trajectoriesSorted] = normalizeByTrack( ...
    Trajectory.ByTrack(:, trajectoryColumns));

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.Source = ...
    'Project.Analysis.Kinematics.TrajectorySamples and Trajectory';
Validation.Upstream = readUpstreamValidation( ...
    TrajectorySamples, Trajectory);
Validation.RequiredModules = requiredModules;
Validation.RequiredSampleColumns = sampleColumns;
Validation.RequiredTrajectoryColumns = trajectoryColumns;
Validation.NInputSamples = height(Samples);
Validation.NInputTrajectories = height(ByTrack);
Validation.SortedInternally = struct( ...
    'Samples', samplesSorted, 'Trajectories', trajectoriesSorted);

if any(~isfinite(ByTrack.DatasetIndex)) || ...
        any(ByTrack.DatasetIndex ~= floor(ByTrack.DatasetIndex))
    Validation = addIssue(Validation, ...
        'Trajectory DatasetIndex must contain finite integer values.');
end
if numel(unique(ByTrack.DatasetIndex)) ~= height(ByTrack)
    Validation = addIssue(Validation, ...
        'Trajectory DatasetIndex must be unique.');
end
if any(~isfinite(ByTrack.RawIndex)) || any(~isfinite(ByTrack.Tid))
    Validation = addIssue(Validation, ...
        'Trajectory RawIndex and Tid must contain finite values.');
end

if any(~isfinite(Samples.DatasetIndex)) || ...
        any(Samples.DatasetIndex ~= floor(Samples.DatasetIndex)) || ...
        any(~isfinite(Samples.RawIndex)) || any(~isfinite(Samples.Tid))
    Validation = addIssue(Validation, ...
        'Sample identifiers must contain finite values and integer DatasetIndex values.');
end
if any(~isfinite(Samples.Frame)) || ...
        any(Samples.Frame ~= floor(Samples.Frame)) || ...
        any(~isfinite(Samples.Time)) || ...
        any(~isfinite(Samples.X)) || any(~isfinite(Samples.Y))
    Validation = addIssue(Validation, ...
        'Sample frame, time, and position values must be finite.');
end
if height(Samples) > 1 && ...
        size(unique([Samples.DatasetIndex Samples.Frame], 'rows'), 1) ~= ...
        height(Samples)
    Validation = addIssue(Validation, ...
        'Sample (DatasetIndex, Frame) keys must be unique.');
end

[sampleRows, samplesComplete] = mapSamples( ...
    ByTrack.DatasetIndex, Samples.DatasetIndex);
if ~samplesComplete
    Validation = addIssue(Validation, ...
        'Every trajectory must have at least one trajectory sample.');
end
if any(~ismember(Samples.DatasetIndex, ByTrack.DatasetIndex))
    Validation = addIssue(Validation, ...
        'Every trajectory sample must map to a trajectory.');
end
if ~identifiersMatch(ByTrack, Samples, sampleRows)
    Validation = addIssue(Validation, ...
        'RawIndex and Tid must agree across frozen kinematics outputs.');
end
if ~samplesOrdered(Samples)
    Validation = addIssue(Validation, ...
        'Frame and Time must be strictly increasing within each trajectory.');
end

ByTrack.NSamples = zeros(height(ByTrack), 1);
ByTrack.NTurningAnglesAvailable = zeros(height(ByTrack), 1);
for i = 1:height(ByTrack)
    nSamples = sum(Samples.DatasetIndex == ByTrack.DatasetIndex(i));
    ByTrack.NSamples(i) = nSamples;
    ByTrack.NTurningAnglesAvailable(i) = max(nSamples - 2, 0);
end

Validation.LocalOK = Validation.OK;
if ~Validation.Upstream.OK
    Validation = addIssue(Validation, ...
        'One or more frozen upstream validations are missing or failed.');
end
Validation.OK = Validation.LocalOK && Validation.Upstream.OK;

AngleTable = emptyAngleTable();
SegmentTable = emptySegmentTable();
if Validation.OK
    AngleTable = calculateAngles(Samples);
    SegmentTable = calculateSegments(AngleTable, Samples);
end

Validation.NAngleRows = height(AngleTable);
Validation.NSegmentRows = height(SegmentTable);
Validation.InPlaceNetDisplacementRatioThreshold = 0.25;

ByTrack = addCoreSummaries(ByTrack, AngleTable, SegmentTable);
ByTrack = addTrajectoryRefinement(ByTrack, SegmentTable, Validation.OK);
Validation.NIncompleteEvidenceTrajectories = ...
    sum(~ByTrack.TurningEvidenceComplete);
Validation.NRefinedTrajectories = ...
    sum(ByTrack.TurningBehaviorAvailable);

% Deterministic primary behavior decision engine.
ByTrack = classifyBehavior(ByTrack, Validation.OK);

Ensemble = summarizeEnsemble(ByTrack, Samples, AngleTable, SegmentTable);
Summary = struct();
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nSamples = Ensemble.NSamples;
Summary.nTurningAnglesAvailable = Ensemble.NTurningAnglesAvailable;
Summary.nTurningAnglesComputed = Ensemble.NTurningAnglesComputed;
Summary.nTurningSegments = Ensemble.NTurningSegments;
Summary.nClockwiseAngles = Ensemble.NClockwiseAngles;
Summary.nCounterclockwiseAngles = Ensemble.NCounterclockwiseAngles;
Summary.nInPlaceSegments = Ensemble.NInPlaceSegments;
Summary.nTurningBehaviorAvailable = Ensemble.NTurningBehaviorAvailable;
Summary.nInPlaceTurnTrajectories = Ensemble.NInPlaceTurnTrajectories;
Summary.nSpiralInTrajectories = Ensemble.NSpiralInTrajectories;
Summary.nSpiralOutTrajectories = Ensemble.NSpiralOutTrajectories;
Summary.nOscillatingTrajectories = Ensemble.NOscillatingTrajectories;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.nClassifiedTrajectories = Ensemble.NClassifiedTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.Status = 'Core';

TurningBehavior = struct();
TurningBehavior.AngleTable = AngleTable;
TurningBehavior.SegmentTable = SegmentTable;
TurningBehavior.ByTrack = ByTrack;
TurningBehavior.Ensemble = Ensemble;
TurningBehavior.Summary = Summary;
TurningBehavior.Validation = Validation;

Project.Analysis.Kinematics.TurningBehavior = TurningBehavior;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Turning Behavior\n');
fprintf('=====================================================\n');
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Angle rows        : %d\n', Summary.nTurningAnglesComputed);
fprintf('Segment rows      : %d\n', Summary.nTurningSegments);
fprintf('Status            : %s\n', Summary.Status);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateContainer(Module, moduleName)

if strcmp(moduleName, 'TrajectorySamples')
    fieldName = 'Samples';
else
    fieldName = 'ByTrack';
end
if ~isfield(Module, fieldName) || ~istable(Module.(fieldName))
    error('SPT_Kinematics_TurningBehavior:InvalidInput', ...
        '%s.%s must be a table.', moduleName, fieldName);
end

end

% =====================================================================
function validateNumericColumns(T, required, sourceName)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_TurningBehavior:MissingColumn', ...
            '%s missing column: %s', sourceName, name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_TurningBehavior:InvalidColumn', ...
            '%s column %s must be a real numeric vector.', ...
            sourceName, name);
    end
end

end

% =====================================================================
function [T, sortedInternally] = normalizeSamples(T)

sortedInternally = false;
if isempty(T)
    return
end
[T, order] = sortrows(T, {'DatasetIndex','Frame'});
sortedInternally = ~isequal(order(:), (1:height(T))');

end

% =====================================================================
function [T, sortedInternally] = normalizeByTrack(T)

sortedInternally = false;
if isempty(T)
    return
end
[T, order] = sortrows(T, 'DatasetIndex');
sortedInternally = ~isequal(order(:), (1:height(T))');

end

% =====================================================================
function Upstream = readUpstreamValidation(TrajectorySamples, Trajectory)

names = {'TrajectorySamples','Trajectory'};
modules = {TrajectorySamples, Trajectory};
Upstream = struct();
Upstream.Source = cell(numel(names), 1);
Upstream.Available = true;
Upstream.OK = true;
Upstream.Issues = {};

for i = 1:numel(names)
    name = names{i};
    Upstream.Source{i, 1} = ...
        ['Project.Analysis.Kinematics.' name '.Validation'];
    status = struct('Available', false, 'OK', false);
    Module = modules{i};
    if isfield(Module, 'Validation') && ...
            isstruct(Module.Validation) && ...
            isscalar(Module.Validation) && ...
            isfield(Module.Validation, 'OK')
        value = Module.Validation.OK;
        if isscalar(value) && ...
                (islogical(value) || ...
                (isnumeric(value) && isreal(value))) && ...
                (~isnumeric(value) || ...
                (isfinite(value) && (value == 0 || value == 1)))
            status.Available = true;
            status.OK = logical(value);
        end
    end
    Upstream.(name) = status;
    Upstream.Available = Upstream.Available && status.Available;
    Upstream.OK = Upstream.OK && status.OK;
    if ~status.Available
        Upstream.Issues{end + 1, 1} = ...
            [name '.Validation.OK is missing or invalid.'];
    elseif ~status.OK
        Upstream.Issues{end + 1, 1} = ...
            [name '.Validation.OK is false.'];
    end
end

end

% =====================================================================
function [rows, complete] = mapSamples(trajectoryIDs, sampleIDs)

rows = zeros(numel(trajectoryIDs), 1);
for i = 1:numel(trajectoryIDs)
    match = find(sampleIDs == trajectoryIDs(i), 1, 'first');
    if ~isempty(match)
        rows(i) = match;
    end
end
complete = all(rows > 0);

end

% =====================================================================
function tf = identifiersMatch(Trajectories, Samples, rows)

tf = true;
for i = 1:height(Trajectories)
    idx = Samples.DatasetIndex == Trajectories.DatasetIndex(i);
    if rows(i) == 0
        continue
    end
    if any(Samples.RawIndex(idx) ~= Trajectories.RawIndex(i)) || ...
            any(Samples.Tid(idx) ~= Trajectories.Tid(i))
        tf = false;
        return
    end
end

end

% =====================================================================
function tf = samplesOrdered(Samples)

tf = true;
trackIDs = unique(Samples.DatasetIndex);
for i = 1:numel(trackIDs)
    idx = Samples.DatasetIndex == trackIDs(i);
    if any(diff(Samples.Frame(idx)) <= 0) || ...
            any(diff(Samples.Time(idx)) <= 0)
        tf = false;
        return
    end
end

end

% =====================================================================
function T = emptyAngleTable()

T = table();
T.DatasetIndex = zeros(0, 1);
T.RawIndex = zeros(0, 1);
T.Tid = zeros(0, 1);
T.AngleIndex = zeros(0, 1);
T.StartFrame = zeros(0, 1);
T.CenterFrame = zeros(0, 1);
T.EndFrame = zeros(0, 1);
T.StartTime = zeros(0, 1);
T.CenterTime = zeros(0, 1);
T.EndTime = zeros(0, 1);
T.Duration = zeros(0, 1);
T.AngularDeltaTime = zeros(0, 1);
T.IncomingStepLength = zeros(0, 1);
T.OutgoingStepLength = zeros(0, 1);
T.ChordLength = zeros(0, 1);
T.SignedAngleRad = zeros(0, 1);
T.SignedAngleDeg = zeros(0, 1);
T.LocalCurvature = zeros(0, 1);
T.CumulativeRotation = zeros(0, 1);
T.RotationPersistence = zeros(0, 1);
T.RotationBias = zeros(0, 1);
T.DirectionCode = zeros(0, 1);
T.Direction = cell(0, 1);
T.Radius = zeros(0, 1);
T.AngularVelocityRadPerTime = zeros(0, 1);
T.AngularVelocityDegPerTime = zeros(0, 1);
T.InPlaceTurning = false(0, 1);
T.AngleValid = false(0, 1);

end

% =====================================================================
function T = calculateAngles(Samples)

T = emptyAngleTable();
trackIDs = unique(Samples.DatasetIndex);
angleTolerance = sqrt(eps);
inPlaceThreshold = 0.25;

for i = 1:numel(trackIDs)
    cumulativeRotation = 0;
    cumulativeAbsoluteRotation = 0;
    rows = find(Samples.DatasetIndex == trackIDs(i));
    for j = 2:(numel(rows) - 1)
        first = rows(j - 1);
        center = rows(j);
        last = rows(j + 1);
        incoming = [Samples.X(center) - Samples.X(first), ...
            Samples.Y(center) - Samples.Y(first)];
        outgoing = [Samples.X(last) - Samples.X(center), ...
            Samples.Y(last) - Samples.Y(center)];
        incomingLength = hypot(incoming(1), incoming(2));
        outgoingLength = hypot(outgoing(1), outgoing(2));
        chord = [Samples.X(last) - Samples.X(first), ...
            Samples.Y(last) - Samples.Y(first)];
        chordLength = hypot(chord(1), chord(2));
        crossValue = incoming(1) * outgoing(2) - ...
            incoming(2) * outgoing(1);
        dotValue = incoming(1) * outgoing(1) + ...
            incoming(2) * outgoing(2);
        valid = incomingLength > 0 && outgoingLength > 0;

        signedAngleRad = NaN;
        signedAngleDeg = NaN;
        localCurvature = NaN;
        cumulativeRotationValue = NaN;
        rotationPersistence = NaN;
        rotationBias = NaN;
        directionCode = 0;
        direction = 'Undefined';
        radius = NaN;
        angularVelocityRad = NaN;
        angularVelocityDeg = NaN;
        inPlaceTurning = false;
        duration = Samples.Time(last) - Samples.Time(first);
        angularDeltaTime = duration / 2;

        if valid
            signedAngleRad = atan2(crossValue, dotValue);
            signedAngleDeg = signedAngleRad * 180 / pi;
            cumulativeRotation = cumulativeRotation + signedAngleDeg;
            cumulativeAbsoluteRotation = cumulativeAbsoluteRotation + ...
                abs(signedAngleDeg);
            cumulativeRotationValue = cumulativeRotation;
            if cumulativeAbsoluteRotation > 0
                rotationBias = cumulativeRotation / ...
                    cumulativeAbsoluteRotation;
                rotationPersistence = abs(rotationBias);
            else
                rotationBias = 0;
                rotationPersistence = 0;
            end
            if chordLength > 0
                localCurvature = 2 * crossValue / ...
                    (incomingLength * outgoingLength * chordLength);
            end
            if signedAngleRad > angleTolerance
                directionCode = 1;
                direction = 'Counterclockwise';
            elseif signedAngleRad < -angleTolerance
                directionCode = -1;
                direction = 'Clockwise';
            else
                directionCode = 0;
                direction = 'Straight';
            end
            if abs(crossValue) > angleTolerance * ...
                    incomingLength * outgoingLength
                radius = incomingLength * outgoingLength * ...
                    chordLength / (2 * abs(crossValue));
            end
            if angularDeltaTime > 0
                angularVelocityRad = signedAngleRad / angularDeltaTime;
                angularVelocityDeg = signedAngleDeg / angularDeltaTime;
            end
            pathLength = incomingLength + outgoingLength;
            inPlaceTurning = pathLength > 0 && ...
                chordLength / pathLength <= inPlaceThreshold && ...
                directionCode ~= 0;
        end

        row = table();
        row.DatasetIndex = Samples.DatasetIndex(center);
        row.RawIndex = Samples.RawIndex(center);
        row.Tid = Samples.Tid(center);
        row.AngleIndex = j - 1;
        row.StartFrame = Samples.Frame(first);
        row.CenterFrame = Samples.Frame(center);
        row.EndFrame = Samples.Frame(last);
        row.StartTime = Samples.Time(first);
        row.CenterTime = Samples.Time(center);
        row.EndTime = Samples.Time(last);
        row.Duration = duration;
        row.AngularDeltaTime = angularDeltaTime;
        row.IncomingStepLength = incomingLength;
        row.OutgoingStepLength = outgoingLength;
        row.ChordLength = chordLength;
        row.SignedAngleRad = signedAngleRad;
        row.SignedAngleDeg = signedAngleDeg;
        row.LocalCurvature = localCurvature;
        row.CumulativeRotation = cumulativeRotationValue;
        row.RotationPersistence = rotationPersistence;
        row.RotationBias = rotationBias;
        row.DirectionCode = directionCode;
        row.Direction = {direction};
        row.Radius = radius;
        row.AngularVelocityRadPerTime = angularVelocityRad;
        row.AngularVelocityDegPerTime = angularVelocityDeg;
        row.InPlaceTurning = inPlaceTurning;
        row.AngleValid = valid;
        T = [T; row]; %#ok<AGROW>
    end
end

end

% =====================================================================
function T = emptySegmentTable()

T = table();
T.DatasetIndex = zeros(0, 1);
T.RawIndex = zeros(0, 1);
T.Tid = zeros(0, 1);
T.SegmentIndex = zeros(0, 1);
T.DirectionCode = zeros(0, 1);
T.Direction = cell(0, 1);
T.StartAngleIndex = zeros(0, 1);
T.EndAngleIndex = zeros(0, 1);
T.NAngles = zeros(0, 1);
T.StartFrame = zeros(0, 1);
T.EndFrame = zeros(0, 1);
T.StartTime = zeros(0, 1);
T.EndTime = zeros(0, 1);
T.Duration = zeros(0, 1);
T.CumulativeAbsoluteAngleDeg = zeros(0, 1);
T.MeanSignedAngleDeg = zeros(0, 1);
T.MeanAngularVelocityDegPerTime = zeros(0, 1);
T.RotationRateSTD = zeros(0, 1);
T.StartRadius = zeros(0, 1);
T.EndRadius = zeros(0, 1);
T.MeanRadius = zeros(0, 1);
T.RadiusSTD = zeros(0, 1);
T.RadiusTrendSlope = zeros(0, 1);
T.RadiusTrend = cell(0, 1);
T.SpiralScore = zeros(0, 1);
T.PathLength = zeros(0, 1);
T.NetDisplacement = zeros(0, 1);
T.InPlaceTurning = false(0, 1);

end

% =====================================================================
function T = calculateSegments(Angles, Samples)

T = emptySegmentTable();
trackIDs = unique(Angles.DatasetIndex);
inPlaceThreshold = 0.25;

for i = 1:numel(trackIDs)
    candidates = find(Angles.DatasetIndex == trackIDs(i) & ...
        Angles.AngleValid & Angles.DirectionCode ~= 0);
    if isempty(candidates)
        continue
    end
    segmentStart = 1;
    segmentIndex = 0;
    for j = 2:(numel(candidates) + 1)
        newSegment = j > numel(candidates);
        if ~newSegment
            previous = candidates(j - 1);
            current = candidates(j);
            newSegment = Angles.AngleIndex(current) ~= ...
                Angles.AngleIndex(previous) + 1 || ...
                Angles.DirectionCode(current) ~= ...
                Angles.DirectionCode(previous);
        end
        if newSegment
            segmentIndex = segmentIndex + 1;
            angleRows = candidates(segmentStart:(j - 1));
            row = summarizeSegment(Angles, angleRows, Samples, ...
                segmentIndex, inPlaceThreshold);
            T = [T; row]; %#ok<AGROW>
            segmentStart = j;
        end
    end
end

end

% =====================================================================
function row = summarizeSegment(A, angleRows, S, segmentIndex, threshold)

firstAngle = angleRows(1);
lastAngle = angleRows(end);
trackID = A.DatasetIndex(firstAngle);
sampleRows = find(S.DatasetIndex == trackID);
firstSample = sampleRows(find(S.Frame(sampleRows) == ...
    A.StartFrame(firstAngle), 1, 'first'));
lastSample = sampleRows(find(S.Frame(sampleRows) == ...
    A.EndFrame(lastAngle), 1, 'first'));
pathRows = firstSample:lastSample;
stepX = diff(S.X(pathRows));
stepY = diff(S.Y(pathRows));
pathLength = sum(hypot(stepX, stepY));
netDisplacement = hypot(S.X(lastSample) - S.X(firstSample), ...
    S.Y(lastSample) - S.Y(firstSample));
inPlaceTurning = pathLength > 0 && ...
    netDisplacement / pathLength <= threshold;
[radiusSlope, radiusTrend] = calculateRadiusTrend( ...
    A.CenterTime(angleRows), A.Radius(angleRows));
meanRadius = meanIgnoringNaN(A.Radius(angleRows));
radiusSTD = stdIgnoringNaN(A.Radius(angleRows));
spiralScore = NaN;
if isfinite(meanRadius) && meanRadius > 0 && ...
        isfinite(A.Radius(firstAngle)) && ...
        isfinite(A.Radius(lastAngle))
    spiralScore = (A.Radius(firstAngle) - ...
        A.Radius(lastAngle)) / meanRadius;
end

row = table();
row.DatasetIndex = trackID;
row.RawIndex = A.RawIndex(firstAngle);
row.Tid = A.Tid(firstAngle);
row.SegmentIndex = segmentIndex;
row.DirectionCode = A.DirectionCode(firstAngle);
row.Direction = A.Direction(firstAngle);
row.StartAngleIndex = A.AngleIndex(firstAngle);
row.EndAngleIndex = A.AngleIndex(lastAngle);
row.NAngles = numel(angleRows);
row.StartFrame = A.StartFrame(firstAngle);
row.EndFrame = A.EndFrame(lastAngle);
row.StartTime = A.StartTime(firstAngle);
row.EndTime = A.EndTime(lastAngle);
row.Duration = row.EndTime - row.StartTime;
row.CumulativeAbsoluteAngleDeg = ...
    sum(abs(A.SignedAngleDeg(angleRows)));
row.MeanSignedAngleDeg = mean(A.SignedAngleDeg(angleRows));
row.MeanAngularVelocityDegPerTime = meanIgnoringNaN( ...
    A.AngularVelocityDegPerTime(angleRows));
row.RotationRateSTD = stdIgnoringNaN( ...
    A.AngularVelocityDegPerTime(angleRows));
row.StartRadius = A.Radius(firstAngle);
row.EndRadius = A.Radius(lastAngle);
row.MeanRadius = meanRadius;
row.RadiusSTD = radiusSTD;
row.RadiusTrendSlope = radiusSlope;
row.RadiusTrend = {radiusTrend};
row.SpiralScore = spiralScore;
row.PathLength = pathLength;
row.NetDisplacement = netDisplacement;
row.InPlaceTurning = inPlaceTurning;

end

% =====================================================================
function [slope, label] = calculateRadiusTrend(time, radius)

valid = isfinite(time) & isfinite(radius);
time = time(valid);
radius = radius(valid);
slope = NaN;
label = 'Undefined';
if numel(radius) < 2 || max(time) <= min(time)
    return
end
coefficients = polyfit(time, radius, 1);
slope = coefficients(1);
timeScale = max(time) - min(time);
radiusScale = max(1, max(abs(radius)));
tolerance = 1e-12 * radiusScale / timeScale;
if slope > tolerance
    label = 'Increasing';
elseif slope < -tolerance
    label = 'Decreasing';
else
    label = 'Stable';
end

end

% =====================================================================
function T = addCoreSummaries(T, Angles, Segments)

n = height(T);
T.NTurningAnglesComputed = zeros(n, 1);
T.NClockwiseAngles = zeros(n, 1);
T.NCounterclockwiseAngles = zeros(n, 1);
T.NStraightAngles = zeros(n, 1);
T.MeanCWAngle = nan(n, 1);
T.MeanCCWAngle = nan(n, 1);
T.TotalRotation = nan(n, 1);
T.SpiralScore = nan(n, 1);
T.OscillationScore = nan(n, 1);
T.RotationPersistence = nan(n, 1);
T.RotationBias = nan(n, 1);
T.MeanAbsoluteAngleDeg = nan(n, 1);
T.NetSignedAngleDeg = nan(n, 1);
T.MeanRadius = nan(n, 1);
T.NTurningSegments = zeros(n, 1);
T.NInPlaceSegments = zeros(n, 1);

for i = 1:n
    angleRows = Angles.DatasetIndex == T.DatasetIndex(i) & ...
        Angles.AngleValid;
    segmentRows = Segments.DatasetIndex == T.DatasetIndex(i);
    clockwiseRows = angleRows & Angles.DirectionCode < 0;
    counterclockwiseRows = angleRows & Angles.DirectionCode > 0;
    T.NTurningAnglesComputed(i) = sum(angleRows);
    T.NClockwiseAngles(i) = sum(clockwiseRows);
    T.NCounterclockwiseAngles(i) = sum(counterclockwiseRows);
    T.NStraightAngles(i) = sum(angleRows & Angles.DirectionCode == 0);
    if any(clockwiseRows)
        T.MeanCWAngle(i) = mean(Angles.SignedAngleDeg(clockwiseRows));
    end
    if any(counterclockwiseRows)
        T.MeanCCWAngle(i) = ...
            mean(Angles.SignedAngleDeg(counterclockwiseRows));
    end
    if any(angleRows)
        T.TotalRotation(i) = sum(abs(Angles.SignedAngleDeg(angleRows)));
        T.MeanAbsoluteAngleDeg(i) = ...
            mean(abs(Angles.SignedAngleDeg(angleRows)));
        T.NetSignedAngleDeg(i) = sum(Angles.SignedAngleDeg(angleRows));
        if T.TotalRotation(i) > 0
            T.RotationBias(i) = ...
                T.NetSignedAngleDeg(i) / T.TotalRotation(i);
            T.RotationPersistence(i) = abs(T.RotationBias(i));
        else
            T.RotationBias(i) = 0;
            T.RotationPersistence(i) = 0;
        end
        turningDirections = Angles.DirectionCode(angleRows);
        turningDirections = turningDirections(turningDirections ~= 0);
        if numel(turningDirections) < 2
            T.OscillationScore(i) = 0;
        else
            T.OscillationScore(i) = sum( ...
                turningDirections(2:end) ~= ...
                turningDirections(1:end-1)) / ...
                (numel(turningDirections) - 1);
        end
        T.MeanRadius(i) = meanIgnoringNaN(Angles.Radius(angleRows));
    end
    finiteSpiral = segmentRows & isfinite(Segments.SpiralScore);
    if any(finiteSpiral)
        weights = Segments.NAngles(finiteSpiral);
        T.SpiralScore(i) = sum(Segments.SpiralScore(finiteSpiral) .* ...
            weights) / sum(weights);
    end
    T.NTurningSegments(i) = sum(segmentRows);
    T.NInPlaceSegments(i) = ...
        sum(Segments.InPlaceTurning(segmentRows));
end

end

% =====================================================================
function T = addTrajectoryRefinement(T, Segments, validationOK)

n = height(T);
T.TurningEvidenceComplete = ...
    T.NTurningAnglesComputed == T.NTurningAnglesAvailable;
T.TurningBehaviorEligible = logical(validationOK) & ...
    T.NTurningAnglesComputed > 0 & T.TurningEvidenceComplete;
T.TurningBehaviorAvailable = T.TurningBehaviorEligible;
T.PrimaryDirection = repmat({'Unavailable'}, n, 1);
T.TurningBehaviorClass = repmat({'Unavailable'}, n, 1);
T.HasInPlaceTurn = false(n, 1);
T.HasSpiralIn = false(n, 1);
T.HasSpiralOut = false(n, 1);
T.HasOscillation = false(n, 1);
T.NSegments = zeros(n, 1);
T.NClockwiseSegments = zeros(n, 1);
T.NCounterclockwiseSegments = zeros(n, 1);

for i = 1:n
    segmentRows = Segments.DatasetIndex == T.DatasetIndex(i);
    clockwiseRows = segmentRows & Segments.DirectionCode < 0;
    counterclockwiseRows = segmentRows & Segments.DirectionCode > 0;
    T.NSegments(i) = sum(segmentRows);
    T.NClockwiseSegments(i) = sum(clockwiseRows);
    T.NCounterclockwiseSegments(i) = sum(counterclockwiseRows);

    if ~T.TurningBehaviorAvailable(i)
        continue
    end

    T.HasInPlaceTurn(i) = any(Segments.InPlaceTurning(segmentRows));
    T.HasSpiralIn(i) = any(strcmp( ...
        Segments.RadiusTrend(segmentRows), 'Decreasing'));
    T.HasSpiralOut(i) = any(strcmp( ...
        Segments.RadiusTrend(segmentRows), 'Increasing'));
    T.HasOscillation(i) = T.NClockwiseSegments(i) > 0 && ...
        T.NCounterclockwiseSegments(i) > 0;

    clockwiseTurn = sum( ...
        Segments.CumulativeAbsoluteAngleDeg(clockwiseRows));
    counterclockwiseTurn = sum( ...
        Segments.CumulativeAbsoluteAngleDeg(counterclockwiseRows));
    directionTolerance = 1e-12 * max(1, ...
        max(clockwiseTurn, counterclockwiseTurn));
    if clockwiseTurn == 0 && counterclockwiseTurn == 0
        T.PrimaryDirection{i} = 'None';
    elseif abs(clockwiseTurn - counterclockwiseTurn) <= ...
            directionTolerance
        T.PrimaryDirection{i} = 'Balanced';
    elseif clockwiseTurn > counterclockwiseTurn
        T.PrimaryDirection{i} = 'Clockwise';
    else
        T.PrimaryDirection{i} = 'Counterclockwise';
    end

    if T.NSegments(i) == 0
        T.TurningBehaviorClass{i} = 'Straight';
    elseif T.HasSpiralIn(i) && T.HasSpiralOut(i)
        T.TurningBehaviorClass{i} = 'MixedRotation';
    elseif T.HasInPlaceTurn(i)
        T.TurningBehaviorClass{i} = 'InPlaceRotation';
    elseif T.HasSpiralIn(i)
        T.TurningBehaviorClass{i} = 'SpiralIn';
    elseif T.HasSpiralOut(i)
        T.TurningBehaviorClass{i} = 'SpiralOut';
    elseif T.HasOscillation(i) && T.OscillationScore(i) >= 0.5
        T.TurningBehaviorClass{i} = 'AlternatingRotation';
    elseif T.HasOscillation(i)
        T.TurningBehaviorClass{i} = 'Oscillation';
    elseif strcmp(T.PrimaryDirection{i}, 'Clockwise')
        T.TurningBehaviorClass{i} = 'ClockwiseRotation';
    elseif strcmp(T.PrimaryDirection{i}, 'Counterclockwise')
        T.TurningBehaviorClass{i} = 'CounterclockwiseRotation';
    else
        T.TurningBehaviorClass{i} = 'MixedRotation';
    end
end

end
% =====================================================================
function T = classifyBehavior(T, validationOK)

n = height(T);
T.BehaviorCode = zeros(n, 1);
T.BehaviorLabel = repmat({'Unclassified'}, n, 1);
T.BehaviorScore = zeros(n, 1);
T.BehaviorClassified = false(n, 1);

for i = 1:n
    validEvidence = logical(validationOK) && ...
        T.TurningBehaviorEligible(i) && ...
        T.TurningBehaviorAvailable(i) && ...
        T.TurningEvidenceComplete(i);
    if ~validEvidence
        continue
    end

    [code, label, score, validClass] = mapBehaviorClass(T, i);
    if validClass
        T.BehaviorCode(i) = code;
        T.BehaviorLabel{i} = label;
        T.BehaviorScore(i) = score;
        T.BehaviorClassified(i) = true;
    end
end

end

% =====================================================================
function [code, label, score, validClass] = mapBehaviorClass(T, i)

code = 0;
label = 'Unclassified';
score = 0;
validClass = true;
className = T.TurningBehaviorClass{i};

switch className
    case 'ClockwiseRotation'
        code = 1;
        label = 'ClockwiseRotation';
        score = 0.5 * (T.RotationPersistence(i) + ...
            abs(T.RotationBias(i)));
    case 'CounterclockwiseRotation'
        code = 2;
        label = 'CounterclockwiseRotation';
        score = 0.5 * (T.RotationPersistence(i) + ...
            abs(T.RotationBias(i)));
    case 'SpiralIn'
        code = 3;
        label = 'SpiralIn';
        score = max(absFinite(T.SpiralScore(i)), ...
            finiteOrZero(T.RotationPersistence(i)));
    case 'SpiralOut'
        code = 4;
        label = 'SpiralOut';
        score = max(absFinite(T.SpiralScore(i)), ...
            finiteOrZero(T.RotationPersistence(i)));
    case {'Oscillation','AlternatingRotation'}
        code = 5;
        label = 'Oscillation';
        score = max(finiteOrZero(T.OscillationScore(i)), ...
            finiteOrZero(1 - abs(T.RotationBias(i))));
    case 'InPlaceRotation'
        code = 6;
        label = 'InPlaceRotation';
        score = T.NInPlaceSegments(i) / ...
            max(T.NTurningSegments(i), 1);
    case {'MixedRotation','Mixed'}
        code = 7;
        label = 'Mixed';
        score = mixedEvidenceScore(T, i);
    case {'Straight','BrownianLike'}
        code = 8;
        label = 'BrownianLike';
        score = 1 - max(finiteOrZero(T.RotationPersistence(i)), ...
            absFinite(T.RotationBias(i)));
    otherwise
        validClass = false;
end

score = clampUnit(score);

end

% =====================================================================
function score = mixedEvidenceScore(T, i)

scores = zeros(0, 1);
if T.HasInPlaceTurn(i)
    scores(end + 1, 1) = T.NInPlaceSegments(i) / ...
        max(T.NTurningSegments(i), 1);
end
if T.HasSpiralIn(i) || T.HasSpiralOut(i)
    scores(end + 1, 1) = max(absFinite(T.SpiralScore(i)), ...
        finiteOrZero(T.RotationPersistence(i)));
end
if T.HasOscillation(i)
    scores(end + 1, 1) = max( ...
        finiteOrZero(T.OscillationScore(i)), ...
        finiteOrZero(1 - abs(T.RotationBias(i))));
end
if isempty(scores)
    score = max(finiteOrZero(T.RotationPersistence(i)), ...
        absFinite(T.RotationBias(i)));
else
    score = mean(scores);
end

end

% =====================================================================
function value = finiteOrZero(value)

if ~isfinite(value)
    value = 0;
end

end

% =====================================================================
function value = absFinite(value)

if isfinite(value)
    value = abs(value);
else
    value = 0;
end

end
% =====================================================================
function value = clampUnit(value)

if ~isfinite(value)
    value = 0;
else
    value = min(1, max(0, value));
end

end
% =====================================================================
function E = summarizeEnsemble(ByTrack, Samples, Angles, Segments)

E = struct();
E.NTrajectories = height(ByTrack);
E.NSamples = height(Samples);
E.NTurningAnglesAvailable = sum(ByTrack.NTurningAnglesAvailable);
E.NTurningAnglesComputed = sum(ByTrack.NTurningAnglesComputed);
E.NTurningSegments = height(Segments);
E.NClockwiseAngles = sum(Angles.AngleValid & Angles.DirectionCode < 0);
E.NCounterclockwiseAngles = ...
    sum(Angles.AngleValid & Angles.DirectionCode > 0);
E.NStraightAngles = sum(Angles.AngleValid & Angles.DirectionCode == 0);
E.NInPlaceAngles = sum(Angles.InPlaceTurning);
E.NInPlaceSegments = sum(Segments.InPlaceTurning);
E.NTurningBehaviorAvailable = sum(ByTrack.TurningBehaviorAvailable);
E.NInPlaceTurnTrajectories = sum(ByTrack.HasInPlaceTurn);
E.NSpiralInTrajectories = sum(ByTrack.HasSpiralIn);
E.NSpiralOutTrajectories = sum(ByTrack.HasSpiralOut);
E.NOscillatingTrajectories = sum(ByTrack.HasOscillation);
E.MeanAbsoluteAngleDeg = meanIgnoringNaN( ...
    abs(Angles.SignedAngleDeg(Angles.AngleValid)));
E.MeanRadius = meanIgnoringNaN(Angles.Radius(Angles.AngleValid));
E.NEligibleTrajectories = sum(ByTrack.TurningBehaviorEligible);
E.NClassifiedTrajectories = sum(ByTrack.BehaviorClassified);
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
else
    E.EligibleFraction = ...
        E.NEligibleTrajectories / E.NTrajectories;
end

end

% =====================================================================
function y = meanIgnoringNaN(x)

x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = mean(x);
end

end

% =====================================================================
function y = stdIgnoringNaN(x)

x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = std(x, 1);
end

end
% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end
