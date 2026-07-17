function tests = test_Kinematics_TurningBehavior
% Focused TurningBehavior tests (MATLAB R2016b compatible).

tests = functiontests(localfunctions);

end

% =====================================================================
function setupOnce(testCase)

testsDir = fileparts(mfilename('fullpath'));
projectDir = fileparts(testsDir);
addpath(projectDir);
testCase.TestData.ProjectDir = projectDir;

end

% =====================================================================
function teardownOnce(testCase)

rmpath(testCase.TestData.ProjectDir);

end


% =====================================================================
function testPublicOutputStructure(testCase)

Project = SPT_Kinematics_TurningBehavior(makeProject());
TurningBehavior = Project.Analysis.Kinematics.TurningBehavior;

verifyEqual(testCase, fieldnames(TurningBehavior), ...
    {'AngleTable';'SegmentTable';'ByTrack';'Ensemble'; ...
    'Summary';'Validation'});
verifyTrue(testCase, istable(TurningBehavior.AngleTable));
verifyTrue(testCase, istable(TurningBehavior.SegmentTable));
verifyTrue(testCase, istable(TurningBehavior.ByTrack));
verifyTrue(testCase, isstruct(TurningBehavior.Ensemble));
verifyTrue(testCase, isstruct(TurningBehavior.Summary));
verifyTrue(testCase, isstruct(TurningBehavior.Validation));
verifyEqual(testCase, TurningBehavior.Summary.Status, 'Core');
verifyTrue(testCase, TurningBehavior.Validation.OK);
verifyEqual(testCase, TurningBehavior.Validation.Source, ...
    ['Project.Analysis.Kinematics.TrajectorySamples ' ...
    'and Trajectory']);

end

% =====================================================================
function testConsumesOnlyFrozenKinematicsOutputs(testCase)

Project = makeProject();
verifyFalse(testCase, isfield(Project, 'Dataset'));
verifyFalse(testCase, isfield(Project, 'Tables'));

FrozenSamples = Project.Analysis.Kinematics.TrajectorySamples;
FrozenTrajectory = Project.Analysis.Kinematics.Trajectory;
Project = SPT_Kinematics_TurningBehavior(Project);

verifyTrue(testCase, isequaln( ...
    Project.Analysis.Kinematics.TrajectorySamples, FrozenSamples));
verifyTrue(testCase, isequaln( ...
    Project.Analysis.Kinematics.Trajectory, FrozenTrajectory));

end

% =====================================================================
function testSignedAngleNumericsAndMetadata(testCase)

Project = SPT_Kinematics_TurningBehavior(makeProject());
A = Project.Analysis.Kinematics.TurningBehavior.AngleTable;

verifyEqual(testCase, height(A), 6);
verifyEqual(testCase, A.DatasetIndex, [1; 1; 1; 2; 2; 2]);
verifyEqual(testCase, A.AngleIndex, [1; 2; 3; 1; 2; 3]);
verifyEqual(testCase, A.SignedAngleDeg, ...
    [90; 90; 90; -90; 90; 90], 'AbsTol', 1e-12);
verifyEqual(testCase, A.SignedAngleRad, ...
    [pi/2; pi/2; pi/2; -pi/2; pi/2; pi/2], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, A.DirectionCode, [1; 1; 1; -1; 1; 1]);
verifyEqual(testCase, A.Direction, ...
    {'Counterclockwise';'Counterclockwise';'Counterclockwise'; ...
    'Clockwise';'Counterclockwise';'Counterclockwise'});
verifyEqual(testCase, A.Radius, repmat(sqrt(0.5), 6, 1), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, A.AngularDeltaTime, ones(6, 1), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, A.AngularVelocityDegPerTime, ...
    [90; 90; 90; -90; 90; 90], 'AbsTol', 1e-12);
verifyEqual(testCase, A.CenterFrame, [2; 3; 4; 2; 3; 4]);
verifyTrue(testCase, all(A.AngleValid));

end

% =====================================================================
function testContiguousTurningSegmentSummaries(testCase)

Project = SPT_Kinematics_TurningBehavior(makeProject());
S = Project.Analysis.Kinematics.TurningBehavior.SegmentTable;

verifyEqual(testCase, height(S), 3);
verifyEqual(testCase, S.DatasetIndex, [1; 2; 2]);
verifyEqual(testCase, S.SegmentIndex, [1; 1; 2]);
verifyEqual(testCase, S.DirectionCode, [1; -1; 1]);
verifyEqual(testCase, S.Direction, ...
    {'Counterclockwise';'Clockwise';'Counterclockwise'});
verifyEqual(testCase, S.StartAngleIndex, [1; 1; 2]);
verifyEqual(testCase, S.EndAngleIndex, [3; 1; 3]);
verifyEqual(testCase, S.NAngles, [3; 1; 2]);
verifyEqual(testCase, S.StartFrame, [1; 1; 2]);
verifyEqual(testCase, S.EndFrame, [5; 3; 5]);
verifyEqual(testCase, S.Duration, [4; 2; 3], 'AbsTol', 1e-12);
verifyEqual(testCase, S.CumulativeAbsoluteAngleDeg, ...
    [270; 90; 180], 'AbsTol', 1e-12);
verifyEqual(testCase, S.MeanSignedAngleDeg, ...
    [90; -90; 90], 'AbsTol', 1e-12);
verifyEqual(testCase, S.MeanRadius, repmat(sqrt(0.5), 3, 1), ...
    'AbsTol', 1e-12);
verifyEqual(testCase, S.RadiusTrend, ...
    {'Stable';'Undefined';'Stable'});
verifyEqual(testCase, S.InPlaceTurning, [true; false; false]);

end

% =====================================================================
function testTrackAndEnsembleCoreSummariesRemainUnclassified(testCase)

Project = SPT_Kinematics_TurningBehavior(makeProject());
T = Project.Analysis.Kinematics.TurningBehavior;

verifyEqual(testCase, T.ByTrack.NTurningAnglesComputed, [3; 3]);
verifyEqual(testCase, T.ByTrack.NClockwiseAngles, [0; 1]);
verifyEqual(testCase, T.ByTrack.NCounterclockwiseAngles, [3; 2]);
verifyEqual(testCase, T.ByTrack.NTurningSegments, [1; 2]);
verifyEqual(testCase, T.ByTrack.NInPlaceSegments, [1; 0]);
verifyEqual(testCase, T.ByTrack.TurningBehaviorEligible, [true; true]);
verifyEqual(testCase, T.ByTrack.BehaviorCode, [0; 0]);
verifyEqual(testCase, T.ByTrack.BehaviorLabel, ...
    {'Unclassified';'Unclassified'});
verifyEqual(testCase, T.ByTrack.BehaviorClassified, [false; false]);
verifyTrue(testCase, all(isnan(T.ByTrack.BehaviorScore)));

verifyEqual(testCase, T.Ensemble.NTurningAnglesComputed, 6);
verifyEqual(testCase, T.Ensemble.NTurningSegments, 3);
verifyEqual(testCase, T.Ensemble.NClockwiseAngles, 1);
verifyEqual(testCase, T.Ensemble.NCounterclockwiseAngles, 5);
verifyEqual(testCase, T.Ensemble.NInPlaceSegments, 1);
verifyEqual(testCase, T.Summary.nTurningAnglesComputed, 6);
verifyEqual(testCase, T.Summary.nTurningSegments, 3);
verifyEqual(testCase, T.Summary.nClassifiedTrajectories, 0);

end

% =====================================================================
function testUpstreamValidationFailurePropagates(testCase)

Project = makeProject();
Project.Analysis.Kinematics.TrajectorySamples.Validation.OK = false;
Project = SPT_Kinematics_TurningBehavior(Project);
T = Project.Analysis.Kinematics.TurningBehavior;

verifyTrue(testCase, T.Validation.LocalOK);
verifyFalse(testCase, T.Validation.Upstream.OK);
verifyFalse(testCase, T.Validation.OK);
verifyNotEmpty(testCase, T.Validation.Issues);
verifyTrue(testCase, isempty(T.AngleTable));
verifyTrue(testCase, isempty(T.SegmentTable));
verifyEqual(testCase, T.ByTrack.NTurningAnglesComputed, [0; 0]);
verifyEqual(testCase, T.ByTrack.TurningBehaviorEligible, [false; false]);

end

% =====================================================================
function testStraightAndDegenerateAnglesAreRepresented(testCase)

Project = makeProjectFromCoordinates({ ...
    [0, 0; 1, 0; 2, 0; 2, 0; 2, 1]});
Project = SPT_Kinematics_TurningBehavior(Project);
T = Project.Analysis.Kinematics.TurningBehavior;

verifyTrue(testCase, T.Validation.OK);
verifyEqual(testCase, height(T.AngleTable), 3);
verifyEqual(testCase, T.AngleTable.Direction{1}, 'Straight');
verifyEqual(testCase, T.AngleTable.SignedAngleDeg(1), 0, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, isnan(T.AngleTable.Radius(1)));
verifyFalse(testCase, T.AngleTable.AngleValid(2));
verifyFalse(testCase, T.AngleTable.AngleValid(3));
verifyTrue(testCase, isempty(T.SegmentTable));
verifyEqual(testCase, T.ByTrack.NTurningAnglesComputed, 1);

end

% =====================================================================
function Project = makeProject()

coordinates = { ...
    [0, 0; 1, 0; 1, 1; 0, 1; 0, 0]; ...
    [0, 0; 1, 0; 1, -1; 2, -1; 2, 0]};
Project = makeProjectFromCoordinates(coordinates);

end

% =====================================================================
function Project = makeProjectFromCoordinates(coordinates)

nTracks = numel(coordinates);
nRows = 0;
for i = 1:nTracks
    nRows = nRows + size(coordinates{i}, 1);
end

DatasetIndex = zeros(nRows, 1);
RawIndex = zeros(nRows, 1);
Tid = zeros(nRows, 1);
Frame = zeros(nRows, 1);
Time = zeros(nRows, 1);
X = zeros(nRows, 1);
Y = zeros(nRows, 1);
trajectoryIDs = (1:nTracks)';
rawIDs = 10 + trajectoryIDs;
trackIDs = 100 + trajectoryIDs;

offset = 0;
for i = 1:nTracks
    xy = coordinates{i};
    n = size(xy, 1);
    rows = offset + (1:n)';
    DatasetIndex(rows) = trajectoryIDs(i);
    RawIndex(rows) = rawIDs(i);
    Tid(rows) = trackIDs(i);
    Frame(rows) = (1:n)';
    Time(rows) = (0:(n - 1))';
    X(rows) = xy(:, 1);
    Y(rows) = xy(:, 2);
    offset = offset + n;
end

Samples = table(DatasetIndex, RawIndex, Tid, Frame, Time, X, Y);
ByTrack = table(trajectoryIDs, rawIDs, trackIDs, ...
    'VariableNames', {'DatasetIndex','RawIndex','Tid'});

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();
Project.Analysis.Kinematics.TrajectorySamples = struct( ...
    'Samples', Samples, 'Validation', struct('OK', true));
Project.Analysis.Kinematics.Trajectory = struct( ...
    'ByTrack', ByTrack, 'Validation', struct('OK', true));

end
