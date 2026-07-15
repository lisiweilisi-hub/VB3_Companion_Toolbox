function tests = test_Kinematics_Step
% Focused tests for SPT_Kinematics_Step (MATLAB R2016b compatible).

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

Project = makeProject(makeLocalization());
Project = SPT_Kinematics_Step(Project);
K = Project.Analysis.Kinematics.Step;

verifyEqual(testCase, fieldnames(K), ...
    {'Table';'ByTrack';'ByState';'Ensemble';'Summary';'Validation'});
verifyEqual(testCase, height(K.Table), 3);
verifyEqual(testCase, K.Table.StepLength, [5; 5; 2]);
verifyEqual(testCase, K.Table.Speed, [10; 10; 4], 'AbsTol', 1e-12);
verifyEqual(testCase, K.Table.Acceleration(1), 0, 'AbsTol', 1e-12);
verifyTrue(testCase, all(isnan(K.Table.Acceleration(2:3))));

verifyEqual(testCase, K.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, K.ByTrack.NSteps, [2; 1]);
verifyEqual(testCase, K.ByTrack.TotalDistance, [10; 2]);
verifyEqual(testCase, K.ByState.State, [1; 2]);
verifyEqual(testCase, K.ByState.NSteps, [2; 1]);
verifyEqual(testCase, K.Ensemble.TotalDistance, 12);
verifyTrue(testCase, K.Validation.OK);
verifyEqual(testCase, Project.Analysis.ExistingResult, 42);

end

% =====================================================================
function testUsesOnlyLocalizationAsDataSource(testCase)

L = makeLocalization();
ProjectA = makeProject(L);
ProjectB = makeProject(L);
ProjectB.Dataset = struct('Trajectory', 'must not be read');
ProjectB.Geometry = struct('StepLength', {{999}});
ProjectB.HMM = struct('nStates', 99);

ProjectA = SPT_Kinematics_Step(ProjectA);
ProjectB = SPT_Kinematics_Step(ProjectB);

verifyEqual(testCase, ProjectA.Analysis.Kinematics.Step, ...
    ProjectB.Analysis.Kinematics.Step);

end

% =====================================================================
function testCanonicalStepLengthIsCopied(testCase)

L = makeLocalization();
L.StepLength(1) = 123.5;
Project = SPT_Kinematics_Step(makeProject(L));

verifyEqual(testCase, Project.Analysis.Kinematics.Step.Table.StepLength(1), ...
    123.5);
verifyEqual(testCase, ...
    Project.Analysis.Kinematics.Step.Validation.CanonicalStepLengthSource, ...
    'Localization.StepLength');

end

% =====================================================================
function testUnsortedInputIsNormalized(testCase)

L = makeLocalization();
L = L([4 1 5 3 2], :);
Project = SPT_Kinematics_Step(makeProject(L));
K = Project.Analysis.Kinematics.Step;

verifyTrue(testCase, K.Validation.SortedInternally);
verifyEqual(testCase, K.Table.DatasetIndex, [1; 1; 2]);
verifyEqual(testCase, K.Table.StartFrame, [1; 2; 1]);

end

% =====================================================================
function testFrameGapFailsEmbeddedValidation(testCase)

L = makeLocalization();
L.Frame(2) = 4;
Project = SPT_Kinematics_Step(makeProject(L));
V = Project.Analysis.Kinematics.Step.Validation;

verifyFalse(testCase, V.OK);
verifyNotEmpty(testCase, V.Issues);

end

% =====================================================================
function testSingleLocalizationProducesEmptyStepResult(testCase)

L = makeLocalization();
L = L(1, :);
Project = SPT_Kinematics_Step(makeProject(L));
K = Project.Analysis.Kinematics.Step;

verifyEqual(testCase, height(K.Table), 0);
verifyEqual(testCase, height(K.ByTrack), 0);
verifyEqual(testCase, height(K.ByState), 0);
verifyEqual(testCase, K.Ensemble.NSteps, 0);
verifyEqual(testCase, K.Ensemble.TotalDistance, 0);
verifyTrue(testCase, K.Validation.OK);

end

% =====================================================================
function testMissingColumnIsRejected(testCase)

L = makeLocalization();
L.StepLength = [];
Project = makeProject(L);

verifyError(testCase, @() SPT_Kinematics_Step(Project), ...
    'SPT_Kinematics_Step:MissingColumn');

end

% =====================================================================
function Project = makeProject(L)

Project = struct();
Project.Tables = struct();
Project.Tables.Localization = L;
Project.Analysis = struct();
Project.Analysis.ExistingResult = 42;

end

% =====================================================================
function L = makeLocalization()

L = table();
L.DatasetIndex = [1; 1; 1; 2; 2];
L.RawIndex = [11; 11; 11; 22; 22];
L.Tid = [101; 101; 101; 202; 202];
L.Frame = [1; 2; 3; 1; 2];
L.Time = [0; 0.5; 1.0; 0; 0.5];
L.X = [0; 3; 6; 0; 2];
L.Y = [0; 4; 8; 0; 0];
L.State = [1; 2; 2; 1; 1];
L.StepLength = [5; 5; NaN; 2; NaN];

end
