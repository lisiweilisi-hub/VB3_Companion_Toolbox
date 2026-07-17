function tests = test_Kinematics_MSD
% Focused tests for SPT_Kinematics_MSD (MATLAB R2016b compatible).

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

Project = SPT_Kinematics_MSD(makeProject(makeTrajectorySamples()));
M = Project.Analysis.Kinematics.MSD;

verifyEqual(testCase, fieldnames(M), ...
    {'ByTrack';'Ensemble';'Summary';'Validation'});
verifyTrue(testCase, istable(M.ByTrack));
verifyEqual(testCase, M.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, M.ByTrack.Lag{1}, [1; 2]);
verifyEqual(testCase, M.ByTrack.LagTime{1}, [0.5; 1], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.ByTrack.MSD{1}, [25; 100], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.ByTrack.MSDX{1}, [9; 36], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.ByTrack.MSDY{1}, [16; 64], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.ByTrack.MSDPairCount{1}, [2; 1]);
verifyEqual(testCase, M.ByTrack.MSD{2}, 4, 'AbsTol', 1e-12);
verifyEqual(testCase, M.ByTrack.NComputedLags, [2; 1]);
verifyEqual(testCase, M.ByTrack.NMSDPairs, [3; 1]);
verifyEqual(testCase, M.ByTrack.MSDComputed, [true; true]);

verifyEqual(testCase, M.Ensemble.Lag, [1; 2]);
verifyEqual(testCase, M.Ensemble.LagTime, [0.5; 1], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.PooledMSD, [18; 100], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.PooledMSDX, [22 / 3; 36], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.PooledMSDY, [32 / 3; 64], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.PairsByLag, [3; 1]);
verifyEqual(testCase, M.Ensemble.TrajectoryMeanMSD, [14.5; 100], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.TrajectorySEMMSD, [10.5; 0], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.NTrajectoriesByLag, [2; 1]);
verifyEqual(testCase, M.Ensemble.NComputedTrajectories, 2);

verifyEqual(testCase, M.Summary.nComputedTrajectories, 2);
verifyEqual(testCase, M.Summary.nComputedLags, 2);
verifyEqual(testCase, M.Summary.nMSDPairs, 4);
verifyEqual(testCase, M.Summary.Status, 'Core');
verifyTrue(testCase, M.Validation.OK);
verifyEqual(testCase, M.Validation.Source, ...
    'Project.Analysis.Kinematics.TrajectorySamples');
verifyTrue(testCase, M.Validation.Upstream.OK);

end

% =====================================================================
function testConsumesOnlyTrajectorySamples(testCase)

TrajectorySamples = makeTrajectorySamples();
ProjectA = makeProject(TrajectorySamples);
ProjectB = makeProject(TrajectorySamples);
ProjectB.Dataset = struct('Trajectory', 'must not be read');
ProjectB.Tables = struct('Localization', 'must not be read');
ProjectB.Geometry = struct('Position', 999);
ProjectB.HMM = struct('State', 999);
ProjectB.Analysis.Kinematics.Step = struct('Poison', 1);
ProjectB.Analysis.Kinematics.Trajectory = struct('Poison', 2);
ProjectB.Analysis.Kinematics.Confinement = struct('Poison', 3);
ProjectB.Analysis.Kinematics.TurningAngle = struct('Poison', 4);

ProjectA = SPT_Kinematics_MSD(ProjectA);
ProjectB = SPT_Kinematics_MSD(ProjectB);

verifyTrue(testCase, isequaln(ProjectA.Analysis.Kinematics.MSD, ...
    ProjectB.Analysis.Kinematics.MSD));
verifyEqual(testCase, ProjectB.Analysis.Kinematics.MSD.Validation.Source, ...
    'Project.Analysis.Kinematics.TrajectorySamples');

end

% =====================================================================
function testFrozenInputsAndModulesArePreserved(testCase)

Project = makeProject(makeTrajectorySamples());
Project.Analysis.Kinematics.Step = struct('FrozenValue', 1);
Project.Analysis.Kinematics.Trajectory = struct('FrozenValue', 2);
Project.Analysis.Kinematics.Confinement = struct('FrozenValue', 3);
Project.Analysis.Kinematics.TurningAngle = struct('FrozenValue', 4);
Frozen = Project.Analysis.Kinematics;

Project = SPT_Kinematics_MSD(Project);

verifyTrue(testCase, isequaln( ...
    Project.Analysis.Kinematics.TrajectorySamples, ...
    Frozen.TrajectorySamples));
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
function testUnsortedInputIsNormalized(testCase)

TrajectorySamples = makeTrajectorySamples();
TrajectorySamples.Samples = ...
    TrajectorySamples.Samples([5 3 1 4 2], :);
TrajectorySamples.ByTrack = TrajectorySamples.ByTrack([2 1], :);
Project = SPT_Kinematics_MSD(makeProject(TrajectorySamples));
M = Project.Analysis.Kinematics.MSD;

verifyTrue(testCase, M.Validation.SamplesSortedInternally);
verifyTrue(testCase, M.Validation.TracksSortedInternally);
verifyEqual(testCase, M.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, M.ByTrack.MSD{1}, [25; 100], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, M.Ensemble.PooledMSD, [18; 100], ...
    'AbsTol', 1e-12);
verifyTrue(testCase, M.Validation.OK);

end

% =====================================================================
function testFailedUpstreamValidationIsPropagated(testCase)

TrajectorySamples = makeTrajectorySamples();
TrajectorySamples.Validation.OK = false;
Project = SPT_Kinematics_MSD(makeProject(TrajectorySamples));
M = Project.Analysis.Kinematics.MSD;

verifyTrue(testCase, M.Validation.LocalOK);
verifyFalse(testCase, M.Validation.Upstream.OK);
verifyFalse(testCase, M.Validation.OK);
verifyNotEmpty(testCase, M.Validation.Issues);
verifyEqual(testCase, M.Summary.nComputedTrajectories, 0);
verifyEqual(testCase, M.Summary.nComputedLags, 0);
verifyEqual(testCase, M.ByTrack.MSDComputed, [false; false]);

end

% =====================================================================
function testFractionalFrameFailsNumericalValidation(testCase)

TrajectorySamples = makeTrajectorySamples();
TrajectorySamples.Samples.Frame(2) = 2.5;
Project = SPT_Kinematics_MSD(makeProject(TrajectorySamples));
M = Project.Analysis.Kinematics.MSD;

verifyFalse(testCase, M.Validation.LocalOK);
verifyFalse(testCase, M.Validation.OK);
verifyNotEmpty(testCase, M.Validation.Issues);
verifyEqual(testCase, M.Summary.nComputedTrajectories, 0);
verifyEqual(testCase, M.ByTrack.MSDComputed, [false; false]);

end

% =====================================================================
function testEmptyInputProducesEmptyCoreOutput(testCase)

TrajectorySamples = makeTrajectorySamples();
TrajectorySamples.Samples = TrajectorySamples.Samples([], :);
TrajectorySamples.ByTrack = TrajectorySamples.ByTrack([], :);
Project = SPT_Kinematics_MSD(makeProject(TrajectorySamples));
M = Project.Analysis.Kinematics.MSD;

verifyEqual(testCase, height(M.ByTrack), 0);
verifyEqual(testCase, M.Ensemble.NSamples, 0);
verifyEqual(testCase, M.Ensemble.NTrajectories, 0);
verifyEqual(testCase, M.Ensemble.Lag, zeros(0, 1));
verifyEqual(testCase, M.Ensemble.PooledMSD, zeros(0, 1));
verifyTrue(testCase, isnan(M.Ensemble.EligibleFraction));
verifyEqual(testCase, M.Summary.nComputedTrajectories, 0);
verifyTrue(testCase, M.Validation.OK);

end

% =====================================================================
function testMissingTrajectorySamplesIsRejected(testCase)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();

verifyError(testCase, @() SPT_Kinematics_MSD(Project), ...
    'SPT_Kinematics_MSD:MissingTrajectorySamples');

end

% =====================================================================
function Project = makeProject(TrajectorySamples)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();
Project.Analysis.Kinematics.TrajectorySamples = TrajectorySamples;

end

% =====================================================================
function TrajectorySamples = makeTrajectorySamples()

Samples = table();
Samples.DatasetIndex = [1; 1; 1; 2; 2];
Samples.RawIndex = [11; 11; 11; 22; 22];
Samples.Tid = [101; 101; 101; 202; 202];
Samples.Frame = [1; 2; 3; 1; 2];
Samples.Time = [0; 0.5; 1; 0; 0.5];
Samples.X = [0; 3; 6; 0; 2];
Samples.Y = [0; 4; 8; 0; 0];

ByTrack = table();
ByTrack.DatasetIndex = [1; 2];
ByTrack.RawIndex = [11; 22];
ByTrack.Tid = [101; 202];
ByTrack.NSamples = [3; 2];
ByTrack.NFinitePositions = [3; 2];
ByTrack.NPairs = [2; 1];
ByTrack.NFinitePairs = [2; 1];
ByTrack.MaxLag = [2; 1];
ByTrack.MeanTimeInterval = [0.5; 0.5];
ByTrack.MSDEligible = [true; true];

TrajectorySamples = struct();
TrajectorySamples.Samples = Samples;
TrajectorySamples.ByTrack = ByTrack;
TrajectorySamples.Validation = struct('OK', true);

end
