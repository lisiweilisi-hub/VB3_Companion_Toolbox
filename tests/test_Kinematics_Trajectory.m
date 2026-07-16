function tests = test_Kinematics_Trajectory
% Focused tests for SPT_Kinematics_Trajectory (MATLAB R2016b compatible).

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

Project = SPT_Kinematics_Trajectory(makeProject(makeStep()));
T = Project.Analysis.Kinematics.Trajectory;

verifyEqual(testCase, fieldnames(T), ...
    {'ByTrack';'Ensemble';'Summary';'Validation'});
verifyEqual(testCase, T.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, T.ByTrack.StartFrame, [1; 1]);
verifyEqual(testCase, T.ByTrack.EndFrame, [3; 2]);
verifyEqual(testCase, T.ByTrack.StartTime, [0; 0]);
verifyEqual(testCase, T.ByTrack.EndTime, [1; 0.5]);
verifyEqual(testCase, T.ByTrack.Duration, [1; 0.5], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.ByTrack.PathMeanSpeed, [10; 4], ...
    'AbsTol', 1e-12);

verifyEqual(testCase, T.Ensemble.NTrajectories, 2);
verifyEqual(testCase, T.Ensemble.NSteps, 3);
verifyEqual(testCase, T.Ensemble.TotalDistance, 12, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.Ensemble.TotalDuration, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.Ensemble.MeanPathSpeed, 7, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.Summary.MeanTrajectoryDuration, 0.75, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, T.Validation.OK);

end

% =====================================================================
function testPublicTableFieldIsByTrack(testCase)

Project = SPT_Kinematics_Trajectory(makeProject(makeStep()));
T = Project.Analysis.Kinematics.Trajectory;

verifyTrue(testCase, isfield(T, 'ByTrack'));
verifyFalse(testCase, isfield(T, 'Table'));
verifyTrue(testCase, istable(T.ByTrack));

end

% =====================================================================
function testUsesOnlyStepAsDataSource(testCase)

Step = makeStep();
ProjectA = makeProject(Step);
ProjectB = makeProject(Step);
ProjectB.Dataset = struct('Trajectory', 'must not be read');
ProjectB.Tables = struct('Localization', 'must not be read');

ProjectA = SPT_Kinematics_Trajectory(ProjectA);
ProjectB = SPT_Kinematics_Trajectory(ProjectB);

verifyTrue(testCase, isequaln( ...
    ProjectA.Analysis.Kinematics.Trajectory, ...
    ProjectB.Analysis.Kinematics.Trajectory));
verifyEqual(testCase, ...
    ProjectB.Analysis.Kinematics.Trajectory.Validation.Source, ...
    'Project.Analysis.Kinematics.Step');

end

% =====================================================================
function testStepInputIsPreserved(testCase)

Step = makeStep();
Project = SPT_Kinematics_Trajectory(makeProject(Step));

verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Step, Step));

end

% =====================================================================
function testUnsortedInputIsNormalized(testCase)

Step = makeStep();
Step.ByTrack = Step.ByTrack([2 1], :);
Step.Table = Step.Table([3 2 1], :);
Project = SPT_Kinematics_Trajectory(makeProject(Step));
T = Project.Analysis.Kinematics.Trajectory;

verifyTrue(testCase, T.Validation.SortedInternally);
verifyEqual(testCase, T.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, T.ByTrack.StartFrame, [1; 1]);
verifyEqual(testCase, T.ByTrack.EndFrame, [3; 2]);
verifyEqual(testCase, T.ByTrack.Duration, [1; 0.5], ...
    'AbsTol', 1e-12);

end

% =====================================================================
function testInvalidStepTimeFailsValidation(testCase)

Step = makeStep();
Step.Table.DeltaTime(1) = 0;
Project = SPT_Kinematics_Trajectory(makeProject(Step));
V = Project.Analysis.Kinematics.Trajectory.Validation;

verifyFalse(testCase, V.OK);
verifyNotEmpty(testCase, V.Issues);

end

% =====================================================================
function testMismatchedStepCountFailsValidation(testCase)

Step = makeStep();
Step.ByTrack.NSteps(1) = 3;
Project = SPT_Kinematics_Trajectory(makeProject(Step));
V = Project.Analysis.Kinematics.Trajectory.Validation;

verifyFalse(testCase, V.OK);
verifyNotEmpty(testCase, V.Issues);

end

% =====================================================================
function testEmptyStepProducesEmptyTrajectory(testCase)

Step = makeStep();
Step.Table = Step.Table([], :);
Step.ByTrack = Step.ByTrack([], :);
Project = SPT_Kinematics_Trajectory(makeProject(Step));
T = Project.Analysis.Kinematics.Trajectory;

verifyEqual(testCase, height(T.ByTrack), 0);
verifyEqual(testCase, T.Ensemble.NTrajectories, 0);
verifyEqual(testCase, T.Ensemble.NSteps, 0);
verifyEqual(testCase, T.Ensemble.TotalDistance, 0);
verifyEqual(testCase, T.Ensemble.TotalDuration, 0);
verifyTrue(testCase, T.Validation.OK);

end

% =====================================================================
function testMissingStepIsRejected(testCase)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();

verifyError(testCase, @() SPT_Kinematics_Trajectory(Project), ...
    'SPT_Kinematics_Trajectory:MissingStep');

end

% =====================================================================
function Project = makeProject(Step)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();
Project.Analysis.Kinematics.Step = Step;
Project.Analysis.ExistingResult = 42;

end

% =====================================================================
function Step = makeStep()

Step = struct();

Step.Table = table();
Step.Table.DatasetIndex = [1; 1; 2];
Step.Table.RawIndex = [11; 11; 22];
Step.Table.Tid = [101; 101; 202];
Step.Table.StartFrame = [1; 2; 1];
Step.Table.EndFrame = [2; 3; 2];
Step.Table.StartTime = [0; 0.5; 0];
Step.Table.EndTime = [0.5; 1; 0.5];
Step.Table.DeltaTime = [0.5; 0.5; 0.5];
Step.Table.State = [1; 2; 1];
Step.Table.StepLength = [5; 5; 2];
Step.Table.Speed = [10; 10; 4];
Step.Table.Acceleration = [0; NaN; NaN];

Step.ByTrack = table();
Step.ByTrack.DatasetIndex = [1; 2];
Step.ByTrack.RawIndex = [11; 22];
Step.ByTrack.Tid = [101; 202];
Step.ByTrack.NSteps = [2; 1];
Step.ByTrack.NFiniteSteps = [2; 1];
Step.ByTrack.TotalDistance = [10; 2];
Step.ByTrack.MeanStepLength = [5; 2];
Step.ByTrack.MedianStepLength = [5; 2];
Step.ByTrack.MeanSpeed = [10; 4];
Step.ByTrack.MedianSpeed = [10; 4];
Step.ByTrack.MeanAcceleration = [0; NaN];

end
