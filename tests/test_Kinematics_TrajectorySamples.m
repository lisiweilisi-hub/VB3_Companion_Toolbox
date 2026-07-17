function tests = test_Kinematics_TrajectorySamples
% Focused tests for SPT_Kinematics_TrajectorySamples (MATLAB R2016b compatible).

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
function testPublicOutputStructureAndNumerics(testCase)

Localization = makeLocalization();
Project = SPT_Kinematics_TrajectorySamples(makeProject(Localization));
T = Project.Analysis.Kinematics.TrajectorySamples;

verifyEqual(testCase, fieldnames(T), ...
    {'Samples';'ByTrack';'Ensemble';'Summary';'Validation'});
verifyTrue(testCase, istable(T.Samples));
verifyEqual(testCase, T.Samples.Properties.VariableNames, ...
    {'DatasetIndex','RawIndex','Tid','Frame','Time','X','Y'});
verifyEqual(testCase, T.Samples.DatasetIndex, [1; 1; 1; 2; 2]);
verifyEqual(testCase, T.Samples.Frame, [1; 2; 3; 1; 2]);
verifyEqual(testCase, T.Samples.X, [0; 3; 6; 0; 2], 'AbsTol', 1e-12);
verifyEqual(testCase, T.Samples.Y, [0; 4; 8; 0; 0], 'AbsTol', 1e-12);

verifyTrue(testCase, istable(T.ByTrack));
verifyEqual(testCase, T.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, T.ByTrack.NSamples, [3; 2]);
verifyEqual(testCase, T.ByTrack.NFinitePositions, [3; 2]);
verifyEqual(testCase, T.ByTrack.Duration, [1; 0.5], 'AbsTol', 1e-12);
verifyEqual(testCase, T.ByTrack.NPairs, [2; 1]);
verifyEqual(testCase, T.ByTrack.NFinitePairs, [2; 1]);
verifyEqual(testCase, T.ByTrack.MaxLag, [2; 1]);
verifyEqual(testCase, T.ByTrack.MeanFrameInterval, [1; 1], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.ByTrack.MeanTimeInterval, [0.5; 0.5], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.ByTrack.UniformFrameInterval, [true; true]);
verifyEqual(testCase, T.ByTrack.UniformTimeInterval, [true; true]);
verifyEqual(testCase, T.ByTrack.MSDEligible, [true; true]);

verifyEqual(testCase, T.Ensemble.NSamples, 5);
verifyEqual(testCase, T.Ensemble.NTrajectories, 2);
verifyEqual(testCase, T.Ensemble.NFinitePositions, 5);
verifyEqual(testCase, T.Ensemble.NPairs, 3);
verifyEqual(testCase, T.Ensemble.NFinitePairs, 3);
verifyEqual(testCase, T.Ensemble.NEligibleTrajectories, 2);
verifyEqual(testCase, T.Ensemble.EligibleFraction, 1, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.Ensemble.MeanTimeInterval, 0.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.Ensemble.TotalDuration, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.Summary.nSamples, 5);
verifyEqual(testCase, T.Summary.nTrajectories, 2);
verifyEqual(testCase, T.Summary.JoinKey, 'DatasetIndex');
verifyTrue(testCase, T.Validation.OK);
verifyEqual(testCase, T.Validation.Source, ...
    'Project.Tables.Localization');
verifyEqual(testCase, T.Validation.JoinKey, 'DatasetIndex');
verifyEqual(testCase, T.Validation.SampleKey, ...
    {'DatasetIndex','Frame'});

end

% =====================================================================
function testConsumesOnlyLocalizationAsDataSource(testCase)

Localization = makeLocalization();
ProjectA = makeProject(Localization);
ProjectB = makeProject(Localization);
ProjectB.Dataset = struct('Trajectory', 'must not be read');
ProjectB.Geometry = struct('Position', 999);
ProjectB.HMM = struct('State', 999);
ProjectB.Analysis = struct();
ProjectB.Analysis.Unrelated = struct('Value', -1);
ProjectB.Analysis.Kinematics = struct();
ProjectB.Analysis.Kinematics.Step = struct('Poison', 1);
ProjectB.Analysis.Kinematics.Trajectory = struct('Poison', 2);
ProjectB.Analysis.Kinematics.Confinement = struct('Poison', 3);
ProjectB.Analysis.Kinematics.TurningAngle = struct('Poison', 4);

ProjectA = SPT_Kinematics_TrajectorySamples(ProjectA);
ProjectB = SPT_Kinematics_TrajectorySamples(ProjectB);

verifyTrue(testCase, isequaln( ...
    ProjectA.Analysis.Kinematics.TrajectorySamples, ...
    ProjectB.Analysis.Kinematics.TrajectorySamples));
verifyEqual(testCase, ...
    ProjectB.Analysis.Kinematics.TrajectorySamples.Validation.Source, ...
    'Project.Tables.Localization');

end

% =====================================================================
function testFrozenKinematicsModulesArePreserved(testCase)

Project = makeProject(makeLocalization());
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();
Project.Analysis.Kinematics.Step = struct('FrozenValue', 1);
Project.Analysis.Kinematics.Trajectory = struct('FrozenValue', 2);
Project.Analysis.Kinematics.Confinement = struct('FrozenValue', 3);
Project.Analysis.Kinematics.TurningAngle = struct('FrozenValue', 4);
Frozen = Project.Analysis.Kinematics;

Project = SPT_Kinematics_TrajectorySamples(Project);

verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Step, ...
    Frozen.Step));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Trajectory, ...
    Frozen.Trajectory));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Confinement, ...
    Frozen.Confinement));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.TurningAngle, ...
    Frozen.TurningAngle));

end

% =====================================================================
function testUnsortedLocalizationIsNormalized(testCase)

Localization = makeLocalization();
Localization = Localization([5 3 1 4 2], :);
Project = SPT_Kinematics_TrajectorySamples(makeProject(Localization));
T = Project.Analysis.Kinematics.TrajectorySamples;

verifyTrue(testCase, T.Validation.SortedInternally);
verifyEqual(testCase, T.Samples.DatasetIndex, [1; 1; 1; 2; 2]);
verifyEqual(testCase, T.Samples.Frame, [1; 2; 3; 1; 2]);
verifyEqual(testCase, T.ByTrack.Duration, [1; 0.5], 'AbsTol', 1e-12);
verifyTrue(testCase, T.Validation.OK);

end

% =====================================================================
function testInvalidNumericsFailValidation(testCase)

Localization = makeLocalization();
Localization.Time(3) = Localization.Time(2);
Localization.X(4) = NaN;
Project = SPT_Kinematics_TrajectorySamples(makeProject(Localization));
T = Project.Analysis.Kinematics.TrajectorySamples;

verifyFalse(testCase, T.Validation.LocalOK);
verifyFalse(testCase, T.Validation.OK);
verifyNotEmpty(testCase, T.Validation.Issues);
verifyEqual(testCase, T.ByTrack.NFinitePositions, [3; 1]);
verifyEqual(testCase, T.ByTrack.NFinitePairs, [2; 0]);
verifyEqual(testCase, T.ByTrack.MSDEligible, [false; false]);

end

% =====================================================================
function testFailedUpstreamValidationIsPropagated(testCase)

Project = makeProject(makeLocalization());
Project.Validation.LocalizationOK = false;
Project = SPT_Kinematics_TrajectorySamples(Project);
T = Project.Analysis.Kinematics.TrajectorySamples;

verifyTrue(testCase, T.Validation.LocalOK);
verifyFalse(testCase, T.Validation.Upstream.OK);
verifyFalse(testCase, T.Validation.OK);
verifyEqual(testCase, T.ByTrack.MSDEligible, [false; false]);
verifyEqual(testCase, T.Ensemble.NEligibleTrajectories, 0);

end

% =====================================================================
function testEmptyLocalizationProducesEmptyOutput(testCase)

Localization = makeLocalization();
Localization = Localization([], :);
Project = SPT_Kinematics_TrajectorySamples(makeProject(Localization));
T = Project.Analysis.Kinematics.TrajectorySamples;

verifyEqual(testCase, height(T.Samples), 0);
verifyEqual(testCase, height(T.ByTrack), 0);
verifyEqual(testCase, T.Ensemble.NSamples, 0);
verifyEqual(testCase, T.Ensemble.NTrajectories, 0);
verifyEqual(testCase, T.Ensemble.NPairs, 0);
verifyTrue(testCase, isnan(T.Ensemble.EligibleFraction));
verifyTrue(testCase, T.Validation.OK);

end

% =====================================================================
function testMissingLocalizationColumnIsRejected(testCase)

Localization = makeLocalization();
Localization.Y = [];
Project = makeProject(Localization);

verifyError(testCase, @() SPT_Kinematics_TrajectorySamples(Project), ...
    'SPT_Kinematics_TrajectorySamples:MissingColumn');

end

% =====================================================================
function Project = makeProject(Localization)

Project = struct();
Project.Tables = struct();
Project.Tables.Localization = Localization;
Project.Validation = struct();
Project.Validation.LocalizationOK = true;

end

% =====================================================================
function Localization = makeLocalization()

Localization = table();
Localization.DatasetIndex = [1; 1; 1; 2; 2];
Localization.RawIndex = [11; 11; 11; 22; 22];
Localization.Tid = [101; 101; 101; 202; 202];
Localization.Frame = [1; 2; 3; 1; 2];
Localization.Time = [0; 0.5; 1.0; 0; 0.5];
Localization.X = [0; 3; 6; 0; 2];
Localization.Y = [0; 4; 8; 0; 0];
Localization.State = [1; 2; 2; 1; 1];
Localization.StepLength = [5; 5; NaN; 2; NaN];

end
