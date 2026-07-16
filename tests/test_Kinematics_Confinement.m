function tests = test_Kinematics_Confinement
% Focused tests for SPT_Kinematics_Confinement (MATLAB R2016b compatible).

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
function testRequiredOutputAndNumerics(testCase)

Input = makeByTrack();
Project = SPT_Kinematics_Confinement(makeProject(Input));
C = Project.Analysis.Kinematics.Confinement;

verifyEqual(testCase, fieldnames(C), ...
    {'ByTrack';'Ensemble';'Summary';'Validation'});
verifyTrue(testCase, isequaln( ...
    C.ByTrack(:, Input.Properties.VariableNames), Input));
verifyEqual(testCase, C.ByTrack.FiniteStepFraction, [1; 1], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, C.ByTrack.MeanStepDuration, [0.5; 0.5], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, C.ByTrack.DistanceRate, [10; 4], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, C.ByTrack.ConfinementEligible, [true; false]);

verifyEqual(testCase, C.Ensemble.NTrajectories, 2);
verifyEqual(testCase, C.Ensemble.NEligibleTrajectories, 1);
verifyEqual(testCase, C.Ensemble.EligibleFraction, 0.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, C.Ensemble.MeanDistanceRate, 7, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, C.Summary.MeanStepDuration, 0.5, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, C.Validation.OK);

end

% =====================================================================
function testUsesOnlyTrajectoryByTrackAsDataSource(testCase)

Input = makeByTrack();
ProjectA = makeProject(Input);
ProjectB = makeProject(Input);
ProjectB.Dataset = struct('Confinement', 'must not be read');
ProjectB.Tables = struct('Localization', 'must not be read');
ProjectB.Analysis.Kinematics.Step = struct('Poison', 1);
ProjectB.Analysis.Kinematics.Trajectory.Other = 'must not be read';

ProjectA = SPT_Kinematics_Confinement(ProjectA);
ProjectB = SPT_Kinematics_Confinement(ProjectB);

verifyTrue(testCase, isequaln( ...
    ProjectA.Analysis.Kinematics.Confinement, ...
    ProjectB.Analysis.Kinematics.Confinement));
verifyEqual(testCase, ...
    ProjectB.Analysis.Kinematics.Confinement.Validation.Source, ...
    'Project.Analysis.Kinematics.Trajectory.ByTrack');

end

% =====================================================================
function testTrajectoryInputIsPreserved(testCase)

Project = makeProject(makeByTrack());
Trajectory = Project.Analysis.Kinematics.Trajectory;
Project = SPT_Kinematics_Confinement(Project);

verifyTrue(testCase, isequaln( ...
    Project.Analysis.Kinematics.Trajectory, Trajectory));

end

% =====================================================================
function testUnsortedInputIsNormalized(testCase)

Input = makeByTrack();
Input = Input([2 1], :);
Project = SPT_Kinematics_Confinement(makeProject(Input));
C = Project.Analysis.Kinematics.Confinement;

verifyTrue(testCase, C.Validation.SortedInternally);
verifyEqual(testCase, C.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, C.ByTrack.DistanceRate, [10; 4], ...
    'AbsTol', 1e-12);

end

% =====================================================================
function testIncompleteStepsAreNotEligible(testCase)

Input = makeByTrack();
Input.NFiniteSteps(1) = 1;
Project = SPT_Kinematics_Confinement(makeProject(Input));
C = Project.Analysis.Kinematics.Confinement;

verifyEqual(testCase, C.ByTrack.FiniteStepFraction, [0.5; 1], ...
    'AbsTol', 1e-12);
verifyFalse(testCase, C.ByTrack.ConfinementEligible(1));
verifyTrue(testCase, C.Validation.OK);

end

% =====================================================================
function testInconsistentRateFailsValidation(testCase)

Input = makeByTrack();
Input.PathMeanSpeed(2) = 5;
Project = SPT_Kinematics_Confinement(makeProject(Input));
V = Project.Analysis.Kinematics.Confinement.Validation;

verifyFalse(testCase, V.OK);
verifyNotEmpty(testCase, V.Issues);

end

% =====================================================================
function testInvalidDurationFailsValidation(testCase)

Input = makeByTrack();
Input.Duration(1) = 0;
Project = SPT_Kinematics_Confinement(makeProject(Input));
V = Project.Analysis.Kinematics.Confinement.Validation;

verifyFalse(testCase, V.OK);
verifyNotEmpty(testCase, V.Issues);

end

% =====================================================================
function testEmptyTrajectoryProducesEmptyConfinement(testCase)

Input = makeByTrack();
Input = Input([], :);
Project = SPT_Kinematics_Confinement(makeProject(Input));
C = Project.Analysis.Kinematics.Confinement;

verifyEqual(testCase, height(C.ByTrack), 0);
verifyEqual(testCase, C.Ensemble.NTrajectories, 0);
verifyEqual(testCase, C.Ensemble.NEligibleTrajectories, 0);
verifyTrue(testCase, isnan(C.Ensemble.EligibleFraction));
verifyTrue(testCase, C.Validation.OK);

end

% =====================================================================
function testMissingColumnIsRejected(testCase)

Input = makeByTrack();
Input.Duration = [];
Project = makeProject(Input);

verifyError(testCase, @() SPT_Kinematics_Confinement(Project), ...
    'SPT_Kinematics_Confinement:MissingColumn');

end

% =====================================================================
function testMissingTrajectoryIsRejected(testCase)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();

verifyError(testCase, @() SPT_Kinematics_Confinement(Project), ...
    'SPT_Kinematics_Confinement:MissingTrajectory');

end

% =====================================================================
function Project = makeProject(ByTrack)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();
Project.Analysis.Kinematics.Trajectory = struct('ByTrack', ByTrack);
Project.Analysis.ExistingResult = 42;

end

% =====================================================================
function T = makeByTrack()

T = table();
T.DatasetIndex = [1; 2];
T.RawIndex = [11; 22];
T.Tid = [101; 202];
T.NSteps = [2; 1];
T.NFiniteSteps = [2; 1];
T.TotalDistance = [10; 2];
T.Duration = [1; 0.5];
T.PathMeanSpeed = [10; 4];
T.ExistingMetric = [7; 8];

end
