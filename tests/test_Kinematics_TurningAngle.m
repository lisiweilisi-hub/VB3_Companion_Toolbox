function tests = test_Kinematics_TurningAngle
% Focused tests for SPT_Kinematics_TurningAngle (MATLAB R2016b compatible).

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
Project = SPT_Kinematics_TurningAngle(makeProject(Input));
A = Project.Analysis.Kinematics.TurningAngle;

verifyEqual(testCase, fieldnames(A), ...
    {'ByTrack';'Ensemble';'Summary';'Validation'});
verifyTrue(testCase, isequaln( ...
    A.ByTrack(:, Input.Properties.VariableNames), Input));
verifyEqual(testCase, A.ByTrack.NPotentialAngles, [2; 1; 0]);
verifyEqual(testCase, A.ByTrack.NPotentialFiniteAngles, [2; 0; 0]);
verifyEqual(testCase, ...
    A.ByTrack.FiniteAngleFractionUpperBound(1:2), [1; 0], ...
    'AbsTol', 1e-12);
verifyTrue(testCase, ...
    isnan(A.ByTrack.FiniteAngleFractionUpperBound(3)));
verifyEqual(testCase, ...
    A.ByTrack.TurningAngleEligible, [true; false; false]);

verifyEqual(testCase, A.Ensemble.NTrajectories, 3);
verifyEqual(testCase, A.Ensemble.NPotentialAngles, 3);
verifyEqual(testCase, A.Ensemble.NPotentialFiniteAngles, 2);
verifyEqual(testCase, A.Ensemble.NEligibleTrajectories, 1);
verifyEqual(testCase, A.Ensemble.EligibleFraction, 1 / 3, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, ...
    A.Ensemble.MeanFiniteAngleFractionUpperBound, 0.5, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, A.Validation.OK);

end

% =====================================================================
function testUsesOnlyTrajectoryByTrackAsDataSource(testCase)

Input = makeByTrack();
ProjectA = makeProject(Input);
ProjectB = makeProject(Input);
ProjectB.Dataset = struct('TurningAngle', 'must not be read');
ProjectB.Tables = struct('Localization', 'must not be read');
ProjectB.Analysis.Kinematics.Step = struct('Poison', 1);
ProjectB.Analysis.Kinematics.Trajectory.Other = 'must not be read';

ProjectA = SPT_Kinematics_TurningAngle(ProjectA);
ProjectB = SPT_Kinematics_TurningAngle(ProjectB);

verifyTrue(testCase, isequaln( ...
    ProjectA.Analysis.Kinematics.TurningAngle, ...
    ProjectB.Analysis.Kinematics.TurningAngle));
verifyEqual(testCase, ...
    ProjectB.Analysis.Kinematics.TurningAngle.Validation.Source, ...
    'Project.Analysis.Kinematics.Trajectory.ByTrack');

end

% =====================================================================
function testTrajectoryInputIsPreserved(testCase)

Project = makeProject(makeByTrack());
Trajectory = Project.Analysis.Kinematics.Trajectory;
Project = SPT_Kinematics_TurningAngle(Project);

verifyTrue(testCase, isequaln( ...
    Project.Analysis.Kinematics.Trajectory, Trajectory));

end

% =====================================================================
function testUnsortedInputIsNormalized(testCase)

Input = makeByTrack();
Input = Input([3 1 2], :);
Project = SPT_Kinematics_TurningAngle(makeProject(Input));
A = Project.Analysis.Kinematics.TurningAngle;

verifyTrue(testCase, A.Validation.SortedInternally);
verifyEqual(testCase, A.ByTrack.DatasetIndex, [1; 2; 3]);
verifyEqual(testCase, A.ByTrack.NPotentialAngles, [2; 1; 0]);

end

% =====================================================================
function testFiniteAngleUpperBoundUsesFiniteStepCount(testCase)

Input = makeByTrack();
Input.NFiniteSteps(1) = 2;
Project = SPT_Kinematics_TurningAngle(makeProject(Input));
A = Project.Analysis.Kinematics.TurningAngle;

verifyEqual(testCase, A.ByTrack.NPotentialAngles(1), 2);
verifyEqual(testCase, A.ByTrack.NPotentialFiniteAngles(1), 1);
verifyEqual(testCase, ...
    A.ByTrack.FiniteAngleFractionUpperBound(1), 0.5, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, A.ByTrack.TurningAngleEligible(1));
verifyTrue(testCase, A.Validation.OK);

end

% =====================================================================
function testInvalidStepCountsFailValidation(testCase)

Input = makeByTrack();
Input.NFiniteSteps(2) = 3;
Project = SPT_Kinematics_TurningAngle(makeProject(Input));
A = Project.Analysis.Kinematics.TurningAngle;

verifyFalse(testCase, A.Validation.OK);
verifyNotEmpty(testCase, A.Validation.Issues);
verifyFalse(testCase, A.ByTrack.TurningAngleEligible(2));

end

% =====================================================================
function testDuplicateDatasetIndexFailsValidation(testCase)

Input = makeByTrack();
Input.DatasetIndex(2) = Input.DatasetIndex(1);
Project = SPT_Kinematics_TurningAngle(makeProject(Input));
V = Project.Analysis.Kinematics.TurningAngle.Validation;

verifyFalse(testCase, V.OK);
verifyNotEmpty(testCase, V.Issues);

end

% =====================================================================
function testEmptyTrajectoryProducesEmptyTurningAngle(testCase)

Input = makeByTrack();
Input = Input([], :);
Project = SPT_Kinematics_TurningAngle(makeProject(Input));
A = Project.Analysis.Kinematics.TurningAngle;

verifyEqual(testCase, height(A.ByTrack), 0);
verifyEqual(testCase, A.Ensemble.NTrajectories, 0);
verifyEqual(testCase, A.Ensemble.NPotentialAngles, 0);
verifyEqual(testCase, A.Ensemble.NEligibleTrajectories, 0);
verifyTrue(testCase, isnan(A.Ensemble.EligibleFraction));
verifyTrue(testCase, A.Validation.OK);

end

% =====================================================================
function testMissingColumnIsRejected(testCase)

Input = makeByTrack();
Input.NFiniteSteps = [];
Project = makeProject(Input);

verifyError(testCase, @() SPT_Kinematics_TurningAngle(Project), ...
    'SPT_Kinematics_TurningAngle:MissingColumn');

end

% =====================================================================
function testMissingTrajectoryIsRejected(testCase)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();

verifyError(testCase, @() SPT_Kinematics_TurningAngle(Project), ...
    'SPT_Kinematics_TurningAngle:MissingTrajectory');

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
T.DatasetIndex = [1; 2; 3];
T.RawIndex = [11; 22; 33];
T.Tid = [101; 202; 303];
T.NSteps = [3; 2; 1];
T.NFiniteSteps = [3; 1; 1];
T.ExistingMetric = [7; 8; 9];

end
