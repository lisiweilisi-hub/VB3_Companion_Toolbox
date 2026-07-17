function tests = test_Kinematics_StateClassification
% Focused tests for State Classification (MATLAB R2016b compatible).

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
function testPublicOutputStructureAndCoreNumerics(testCase)

Project = SPT_Kinematics_StateClassification(makeProject());
S = Project.Analysis.Kinematics.StateClassification;

verifyEqual(testCase, fieldnames(S), ...
    {'ByTrack';'Ensemble';'Summary';'Validation'});
verifyTrue(testCase, istable(S.ByTrack));
verifyEqual(testCase, S.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, S.ByTrack.HasConfinementEvidence, [true; false]);
verifyEqual(testCase, S.ByTrack.HasTurningAngleEvidence, [true; false]);
verifyEqual(testCase, S.ByTrack.HasMSDEvidence, [true; true]);
verifyEqual(testCase, S.ByTrack.HasDiffusionEvidence, [true; false]);
verifyEqual(testCase, S.ByTrack.TurningBehaviorAvailable, [true; false]);
verifyEqual(testCase, S.ByTrack.TurningBehaviorEligible, [true; false]);
verifyEqual(testCase, S.ByTrack.TurningBehaviorClass, ...
    {'BrownianLike';'Unavailable'});
verifyEqual(testCase, S.ByTrack.BehaviorLabel, ...
    {'BrownianLike';'Unclassified'});
verifyEqual(testCase, S.ByTrack.BehaviorScore, [0.8; 0], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, S.ByTrack.BehaviorClassified, [true; false]);
verifyEqual(testCase, S.ByTrack.NAvailableFeatures, [5; 1]);
verifyEqual(testCase, S.ByTrack.ClassificationEligible, [true; true]);
verifyEqual(testCase, S.ByTrack.ClassificationCode, [1; 0]);
verifyEqual(testCase, S.ByTrack.ClassificationLabel, ...
    {'BrownianCandidate';'Unclassified'});
verifyEqual(testCase, S.ByTrack.ClassificationConfidence(1), 0.9, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, isnan(S.ByTrack.ClassificationConfidence(2)));
verifyEqual(testCase, S.ByTrack.ClassificationSuccessful, [true; false]);
verifyEqual(testCase, S.ByTrack.ClassificationBasis, ...
    {'BaselineBrownianFit';'None'});

verifyEqual(testCase, S.Ensemble.NTrajectories, 2);
verifyEqual(testCase, S.Ensemble.NTrajectoriesWithEvidence, 2);
verifyEqual(testCase, S.Ensemble.NEligibleTrajectories, 2);
verifyEqual(testCase, S.Ensemble.NClassifiedTrajectories, 1);
verifyEqual(testCase, S.Ensemble.NBrownianCandidates, 1);
verifyEqual(testCase, S.Ensemble.NUnclassifiedTrajectories, 1);
verifyEqual(testCase, S.Ensemble.EligibleFraction, 1, 'AbsTol', 1e-12);
verifyEqual(testCase, S.Ensemble.MeanAvailableFeatures, 3, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, S.Ensemble.BrownianCandidateFraction, 0.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, S.Ensemble.MeanClassificationConfidence, 0.9, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, ...
    S.Ensemble.MeanClassifiedDiffusionCoefficient, 2.5, ...
    'AbsTol', 1e-12);

verifyEqual(testCase, S.Summary.Status, 'Core');
verifyEqual(testCase, S.Summary.nClassifiedTrajectories, 1);
verifyEqual(testCase, S.Summary.nBrownianCandidates, 1);
verifyTrue(testCase, S.Validation.OK);
verifyEqual(testCase, S.Validation.Source, ...
    'Project.Analysis.Kinematics frozen outputs');
verifyTrue(testCase, S.Validation.Upstream.OK);
verifyTrue(testCase, isfield(S.Validation, 'Issues'));

end

% =====================================================================
function testConsumesOnlyFrozenAnalysisOutputs(testCase)

ProjectA = makeProject();
ProjectB = makeProject();
ProjectB.Dataset = struct('Poison', 'must not be read');
ProjectB.Tables = struct('Localization', 'must not be read');
ProjectB.Geometry = struct('Poison', 999);
ProjectB.Analysis.Kinematics.Step = struct('Poison', 1);
ProjectB.Analysis.Kinematics.TrajectorySamples = struct('Poison', 2);

ProjectA = SPT_Kinematics_StateClassification(ProjectA);
ProjectB = SPT_Kinematics_StateClassification(ProjectB);

verifyTrue(testCase, isequaln( ...
    ProjectA.Analysis.Kinematics.StateClassification, ...
    ProjectB.Analysis.Kinematics.StateClassification));

end

% =====================================================================
function testFrozenAnalysisInputsArePreserved(testCase)

Project = makeProject();
Project.Analysis.Kinematics.Step = struct('FrozenValue', 1);
Project.Analysis.Kinematics.TrajectorySamples = struct('FrozenValue', 2);
Project.Dataset = struct('FrozenValue', 3);
Project.Tables = struct('FrozenValue', 4);
FrozenKinematics = Project.Analysis.Kinematics;
FrozenDataset = Project.Dataset;
FrozenTables = Project.Tables;

Project = SPT_Kinematics_StateClassification(Project);

names = fieldnames(FrozenKinematics);
for i = 1:numel(names)
    name = names{i};
    verifyTrue(testCase, isequaln( ...
        Project.Analysis.Kinematics.(name), FrozenKinematics.(name)));
end
verifyTrue(testCase, isequaln(Project.Dataset, FrozenDataset));
verifyTrue(testCase, isequaln(Project.Tables, FrozenTables));

end

% =====================================================================
function testEvidenceIsJoinedByDatasetIndex(testCase)

Project = makeProject();
names = {'Trajectory','Confinement','TurningAngle','MSD','Diffusion', ...
    'TurningBehavior'};
for i = 1:numel(names)
    name = names{i};
    Project.Analysis.Kinematics.(name).ByTrack = ...
        Project.Analysis.Kinematics.(name).ByTrack([2; 1], :);
end

Project = SPT_Kinematics_StateClassification(Project);
S = Project.Analysis.Kinematics.StateClassification;

verifyTrue(testCase, S.Validation.OK);
verifyEqual(testCase, S.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, S.ByTrack.ClassificationCode, [1; 0]);
verifyTrue(testCase, S.Validation.SortedInternally.Trajectory);
verifyTrue(testCase, S.Validation.SortedInternally.Confinement);
verifyTrue(testCase, S.Validation.SortedInternally.TurningAngle);
verifyTrue(testCase, S.Validation.SortedInternally.MSD);
verifyTrue(testCase, S.Validation.SortedInternally.Diffusion);
verifyTrue(testCase, S.Validation.SortedInternally.TurningBehavior);

end

% =====================================================================
function testFailedUpstreamValidationSuppressesClassification(testCase)

Project = makeProject();
Project.Analysis.Kinematics.MSD.Validation.OK = false;
Project = SPT_Kinematics_StateClassification(Project);
S = Project.Analysis.Kinematics.StateClassification;

verifyTrue(testCase, S.Validation.LocalOK);
verifyFalse(testCase, S.Validation.Upstream.OK);
verifyFalse(testCase, S.Validation.OK);
verifyNotEmpty(testCase, S.Validation.Issues);
verifyEqual(testCase, S.ByTrack.ClassificationEligible, [false; false]);
verifyEqual(testCase, S.ByTrack.ClassificationCode, [0; 0]);
verifyEqual(testCase, S.ByTrack.ClassificationSuccessful, [false; false]);
verifyTrue(testCase, all(isnan(S.ByTrack.ClassificationConfidence)));
verifyEqual(testCase, S.Ensemble.NClassifiedTrajectories, 0);
verifyTrue(testCase, isnan(S.Ensemble.MeanClassificationConfidence));

end

% =====================================================================
function testInvalidSuccessfulDiffusionFitsFailValidation(testCase)

badValues = {[-1, 0.9], [Inf, 0.9], [2.5, NaN], [2.5, 1.1]};
for i = 1:numel(badValues)
    Project = makeProject();
    values = badValues{i};
    Project.Analysis.Kinematics.Diffusion.ByTrack. ...
        DiffusionCoefficient(1) = values(1);
    Project.Analysis.Kinematics.Diffusion.ByTrack.FitRSquared(1) = ...
        values(2);
    Project = SPT_Kinematics_StateClassification(Project);
    S = Project.Analysis.Kinematics.StateClassification;

    verifyFalse(testCase, S.Validation.LocalOK);
    verifyFalse(testCase, S.Validation.OK);
    verifyNotEmpty(testCase, S.Validation.Issues);
    verifyEqual(testCase, S.ByTrack.ClassificationCode, [0; 0]);
    verifyEqual(testCase, ...
        S.ByTrack.ClassificationSuccessful, [false; false]);
    verifyTrue(testCase, ...
        all(isnan(S.ByTrack.ClassificationConfidence)));
end

end

% =====================================================================
function testUnavailableDiffusionEvidenceRemainsUnclassified(testCase)

Project = makeProject();
Project.Analysis.Kinematics.Diffusion.ByTrack. ...
    DiffusionCoefficient(1) = NaN;
Project.Analysis.Kinematics.Diffusion.ByTrack.FitRSquared(1) = NaN;
Project.Analysis.Kinematics.Diffusion.ByTrack.FitSuccessful(1) = false;
Project = SPT_Kinematics_StateClassification(Project);
S = Project.Analysis.Kinematics.StateClassification;

verifyTrue(testCase, S.Validation.OK);
verifyEqual(testCase, S.ByTrack.HasDiffusionEvidence, [false; false]);
verifyEqual(testCase, S.ByTrack.NAvailableFeatures, [4; 1]);
verifyEqual(testCase, S.ByTrack.ClassificationEligible, [true; true]);
verifyEqual(testCase, S.ByTrack.ClassificationCode, [1; 0]);
verifyEqual(testCase, S.ByTrack.ClassificationLabel, ...
    {'BrownianCandidate';'Unclassified'});
verifyEqual(testCase, S.ByTrack.ClassificationConfidence(1), 0.8, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, S.ByTrack.ClassificationSuccessful, [true; false]);
verifyEqual(testCase, S.Ensemble.NClassifiedTrajectories, 1);
verifyTrue(testCase, isnan(S.Ensemble.MeanClassifiedDiffusionCoefficient));

end

% =====================================================================
function testTurningBehaviorStateFusionLabels(testCase)

turningCases = { ...
    'ClockwiseRotation', 'ClockwiseRotation', 3, 'RotationalCandidate'; ...
    'SpiralIn', 'SpiralIn', 4, 'SpiralCandidate'; ...
    'Oscillation', 'Oscillation', 5, 'OscillatoryCandidate'; ...
    'MixedRotation', 'Mixed', 6, 'MixedCandidate'};
for i = 1:size(turningCases, 1)
    Project = makeProject();
    Project = suppressFirstDiffusion(Project);
    Project.Analysis.Kinematics.Confinement.ByTrack. ...
        ConfinementEligible(1) = false;
    Project = setFirstTurningBehavior(Project, turningCases{i, 1}, ...
        turningCases{i, 2}, 0.8);

    Project = SPT_Kinematics_StateClassification(Project);
    T = Project.Analysis.Kinematics.StateClassification.ByTrack;
    verifyEqual(testCase, T.ClassificationCode(1), turningCases{i, 3});
    verifyEqual(testCase, T.ClassificationLabel{1}, turningCases{i, 4});
    verifyEqual(testCase, T.ClassificationConfidence(1), 0.8, ...
        'AbsTol', 1e-12);
    verifyTrue(testCase, T.ClassificationSuccessful(1));
end

Project = makeProject();
Project = suppressFirstDiffusion(Project);
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    TurningBehaviorAvailable(1) = false;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    TurningBehaviorEligible(1) = false;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    TurningBehaviorClass{1} = 'Unavailable';
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    BehaviorLabel{1} = 'Unclassified';
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    BehaviorScore(1) = 0;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    BehaviorClassified(1) = false;
Project = SPT_Kinematics_StateClassification(Project);
T = Project.Analysis.Kinematics.StateClassification.ByTrack;
verifyEqual(testCase, T.ClassificationCode(1), 2);
verifyEqual(testCase, T.ClassificationLabel{1}, 'ConfinedCandidate');
verifyEqual(testCase, T.ClassificationConfidence(1), 1, ...
    'AbsTol', 1e-12);

Project = makeProject();
Project = setFirstTurningBehavior(Project, ...
    'ClockwiseRotation', 'ClockwiseRotation', 0.8);
Project = SPT_Kinematics_StateClassification(Project);
T = Project.Analysis.Kinematics.StateClassification.ByTrack;
verifyEqual(testCase, T.ClassificationCode(1), 6);
verifyEqual(testCase, T.ClassificationLabel{1}, 'MixedCandidate');
verifyEqual(testCase, T.ClassificationConfidence(1), 0.85, ...
    'AbsTol', 1e-12);

Project = makeProject();
Project = setFirstTurningBehavior(Project, ...
    'ClockwiseRotation', 'ClockwiseRotation', 0.4);
Project = SPT_Kinematics_StateClassification(Project);
T = Project.Analysis.Kinematics.StateClassification.ByTrack;
verifyEqual(testCase, T.ClassificationCode(1), 1);
verifyEqual(testCase, T.ClassificationLabel{1}, 'BrownianCandidate');
verifyEqual(testCase, T.ClassificationConfidence(1), 0.9, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, T.ClassificationLabel{2}, 'Unclassified');

end
% =====================================================================
function testMismatchedFrozenIdentifiersSuppressClassification(testCase)

Project = makeProject();
Project.Analysis.Kinematics.TurningBehavior.ByTrack.RawIndex(1) = 999;
Project = SPT_Kinematics_StateClassification(Project);
S = Project.Analysis.Kinematics.StateClassification;

verifyFalse(testCase, S.Validation.LocalOK);
verifyFalse(testCase, S.Validation.OK);
verifyNotEmpty(testCase, S.Validation.Issues);
verifyEqual(testCase, S.ByTrack.ClassificationEligible, [false; false]);
verifyEqual(testCase, S.ByTrack.ClassificationCode, [0; 0]);
verifyEqual(testCase, S.ByTrack.ClassificationSuccessful, [false; false]);

end

% =====================================================================
function testSourceDependencyBoundary(testCase)

source = fileread(which('SPT_Kinematics_StateClassification'));
forbidden = {'Project.Dataset', 'Project.Tables.Localization', ...
    'SPT_Kinematics_Step(', 'SPT_Kinematics_Trajectory(', ...
    'SPT_Kinematics_Confinement(', 'SPT_Kinematics_TurningAngle(', ...
    'SPT_Kinematics_TrajectorySamples(', 'SPT_Kinematics_MSD(', ...
    'SPT_Kinematics_Diffusion(', ...
    'SPT_Kinematics_TurningBehavior('};
for i = 1:numel(forbidden)
    verifyEmpty(testCase, strfind(source, forbidden{i})); %#ok<STREMP>
end
required = {'Kinematics.Trajectory', 'Kinematics.Confinement', ...
    'Kinematics.TurningAngle', 'Kinematics.MSD', ...
    'Kinematics.Diffusion', 'Kinematics.TurningBehavior'};
for i = 1:numel(required)
    verifyNotEmpty(testCase, strfind(source, required{i})); %#ok<STREMP>
end

end

% =====================================================================
function Project = suppressFirstDiffusion(Project)

Project.Analysis.Kinematics.Diffusion.ByTrack. ...
    DiffusionCoefficient(1) = NaN;
Project.Analysis.Kinematics.Diffusion.ByTrack.FitRSquared(1) = NaN;
Project.Analysis.Kinematics.Diffusion.ByTrack.FitSuccessful(1) = false;

end

% =====================================================================
function Project = setFirstTurningBehavior(Project, behaviorClass, ...
        behaviorLabel, behaviorScore)

Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    TurningBehaviorAvailable(1) = true;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    TurningBehaviorEligible(1) = true;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    TurningBehaviorClass{1} = behaviorClass;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    BehaviorLabel{1} = behaviorLabel;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    BehaviorScore(1) = behaviorScore;
Project.Analysis.Kinematics.TurningBehavior.ByTrack. ...
    BehaviorClassified(1) = true;

end
% =====================================================================
function Project = makeProject()

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = makeFrozenKinematics();

end

% =====================================================================
function Kinematics = makeFrozenKinematics()

TrajectoryByTrack = table();
TrajectoryByTrack.DatasetIndex = [1; 2];
TrajectoryByTrack.RawIndex = [11; 22];
TrajectoryByTrack.Tid = [101; 202];
TrajectoryByTrack.NSteps = [3; 1];
TrajectoryByTrack.NFiniteSteps = [3; 1];

ConfinementByTrack = identifierTable();
ConfinementByTrack.ConfinementEligible = [true; false];

TurningAngleByTrack = identifierTable();
TurningAngleByTrack.TurningAngleEligible = [true; false];

MSDByTrack = identifierTable();
MSDByTrack.MSDComputed = [true; true];

DiffusionByTrack = identifierTable();
DiffusionByTrack.DiffusionCoefficient = [2.5; NaN];
DiffusionByTrack.FitRSquared = [0.9; NaN];
DiffusionByTrack.FitSuccessful = [true; false];

TurningBehaviorByTrack = identifierTable();
TurningBehaviorByTrack.TurningBehaviorAvailable = [true; false];
TurningBehaviorByTrack.TurningBehaviorEligible = [true; false];
TurningBehaviorByTrack.TurningBehaviorClass = ...
    {'BrownianLike';'Unavailable'};
TurningBehaviorByTrack.BehaviorLabel = ...
    {'BrownianLike';'Unclassified'};
TurningBehaviorByTrack.BehaviorScore = [0.8; 0];
TurningBehaviorByTrack.BehaviorClassified = [true; false];

Kinematics = struct();
Kinematics.Trajectory = frozenModule(TrajectoryByTrack);
Kinematics.Confinement = frozenModule(ConfinementByTrack);
Kinematics.TurningAngle = frozenModule(TurningAngleByTrack);
Kinematics.MSD = frozenModule(MSDByTrack);
Kinematics.Diffusion = frozenModule(DiffusionByTrack);
Kinematics.TurningBehavior = frozenModule(TurningBehaviorByTrack);

end

% =====================================================================
function T = identifierTable()

T = table();
T.DatasetIndex = [1; 2];
T.RawIndex = [11; 22];
T.Tid = [101; 202];

end

% =====================================================================
function Module = frozenModule(ByTrack)

Module = struct();
Module.ByTrack = ByTrack;
Module.Ensemble = struct('Frozen', true);
Module.Summary = struct('Frozen', true);
Module.Validation = struct('OK', true);

end
