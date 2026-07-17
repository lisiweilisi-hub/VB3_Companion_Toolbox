function tests = test_Kinematics_Diffusion
% Focused tests for SPT_Kinematics_Diffusion (MATLAB R2016b compatible).

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

Project = SPT_Kinematics_Diffusion(makeProject(makeMSD()));
D = Project.Analysis.Kinematics.Diffusion;

verifyEqual(testCase, fieldnames(D), ...
    {'ByTrack';'Ensemble';'Summary';'Validation'});
verifyTrue(testCase, istable(D.ByTrack));
verifyEqual(testCase, D.ByTrack.DatasetIndex, [1; 2]);
verifyEqual(testCase, D.ByTrack.NFiniteMSDPoints, [3; 2]);
verifyEqual(testCase, D.ByTrack.MaxFiniteLag, [3; 2]);
verifyEqual(testCase, D.ByTrack.DiffusionEligible, [true; true]);
verifyEqual(testCase, D.ByTrack.DiffusionCoefficient, [1; 2], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.ByTrack.FitSlope, [4; 8], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.ByTrack.FitIntercept, [0; 0], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.ByTrack.FitRSquared, [1; 1], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.ByTrack.NFitPoints, [3; 2]);
verifyEqual(testCase, D.ByTrack.FitSuccessful, [true; true]);

verifyEqual(testCase, D.Ensemble.NFitSuccessful, 2);
verifyEqual(testCase, D.Ensemble.FitSuccessfulFraction, 1, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.MeanDiffusionCoefficient, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.MedianDiffusionCoefficient, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.PooledDiffusionCoefficient, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.PooledFitSlope, 6, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.PooledFitIntercept, 0, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.PooledFitRSquared, 1, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.PooledNFitPoints, 3);
verifyTrue(testCase, D.Ensemble.PooledFitSuccessful);

verifyEqual(testCase, D.Summary.nFitSuccessful, 2);
verifyEqual(testCase, D.Summary.MeanDiffusionCoefficient, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Summary.PooledDiffusionCoefficient, 1.5, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Summary.Dimension, 2);
verifyEqual(testCase, D.Summary.FitPointLimit, 10);
verifyEqual(testCase, D.Summary.Status, 'Core');
verifyTrue(testCase, D.Validation.OK);
verifyEqual(testCase, D.Validation.Source, ...
    'Project.Analysis.Kinematics.MSD');
verifyTrue(testCase, D.Validation.Upstream.OK);

end

% =====================================================================
function testUsesOnlyInitialTenMSDPoints(testCase)

MSD = makeMSD();
MSD.ByTrack = MSD.ByTrack(1, :);
lag = (1:12)';
msd = [4 * (1:10)'; 1e6; 2e6];
MSD.ByTrack.Lag{1} = lag;
MSD.ByTrack.LagTime{1} = lag;
MSD.ByTrack.MSD{1} = msd;
MSD.ByTrack.MSDX{1} = msd;
MSD.ByTrack.MSDY{1} = zeros(12, 1);
MSD.ByTrack.MSDPairCount{1} = (12:-1:1)';
MSD.ByTrack.NComputedLags(1) = 12;
MSD.ByTrack.NMSDPairs(1) = 78;
MSD.Ensemble.LagTime = lag;
MSD.Ensemble.PooledMSD = msd;
MSD.Ensemble.PairsByLag = (12:-1:1)';

Project = SPT_Kinematics_Diffusion(makeProject(MSD));
D = Project.Analysis.Kinematics.Diffusion;

verifyEqual(testCase, D.ByTrack.NFitPoints, 10);
verifyEqual(testCase, D.ByTrack.FitSlope, 4, 'AbsTol', 1e-12);
verifyEqual(testCase, D.ByTrack.FitIntercept, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, D.ByTrack.DiffusionCoefficient, 1, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, D.Ensemble.PooledNFitPoints, 10);
verifyEqual(testCase, D.Ensemble.PooledDiffusionCoefficient, 1, ...
    'AbsTol', 1e-12);

end

% =====================================================================
function testConsumesOnlyMSD(testCase)

MSD = makeMSD();
ProjectA = makeProject(MSD);
ProjectB = makeProject(MSD);
ProjectB.Dataset = struct('Trajectory', 'must not be read');
ProjectB.Tables = struct('Localization', 'must not be read');
ProjectB.Geometry = struct('Position', 999);
ProjectB.Analysis.Kinematics.Step = struct('Poison', 1);
ProjectB.Analysis.Kinematics.Trajectory = struct('Poison', 2);
ProjectB.Analysis.Kinematics.Confinement = struct('Poison', 3);
ProjectB.Analysis.Kinematics.TurningAngle = struct('Poison', 4);
ProjectB.Analysis.Kinematics.TrajectorySamples = struct('Poison', 5);

ProjectA = SPT_Kinematics_Diffusion(ProjectA);
ProjectB = SPT_Kinematics_Diffusion(ProjectB);

verifyTrue(testCase, isequaln( ...
    ProjectA.Analysis.Kinematics.Diffusion, ...
    ProjectB.Analysis.Kinematics.Diffusion));
verifyEqual(testCase, ...
    ProjectB.Analysis.Kinematics.Diffusion.Validation.Source, ...
    'Project.Analysis.Kinematics.MSD');

end

% =====================================================================
function testFrozenInputAndModulesArePreserved(testCase)

Project = makeProject(makeMSD());
Project.Analysis.Kinematics.Step = struct('FrozenValue', 1);
Project.Analysis.Kinematics.Trajectory = struct('FrozenValue', 2);
Project.Analysis.Kinematics.Confinement = struct('FrozenValue', 3);
Project.Analysis.Kinematics.TurningAngle = struct('FrozenValue', 4);
Project.Analysis.Kinematics.TrajectorySamples = struct('FrozenValue', 5);
Frozen = Project.Analysis.Kinematics;

Project = SPT_Kinematics_Diffusion(Project);

verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.MSD, ...
    Frozen.MSD));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Step, ...
    Frozen.Step));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Trajectory, ...
    Frozen.Trajectory));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.Confinement, ...
    Frozen.Confinement));
verifyTrue(testCase, isequaln(Project.Analysis.Kinematics.TurningAngle, ...
    Frozen.TurningAngle));
verifyTrue(testCase, isequaln( ...
    Project.Analysis.Kinematics.TrajectorySamples, ...
    Frozen.TrajectorySamples));

end

% =====================================================================
function testFailedUpstreamValidationSuppressesFits(testCase)

MSD = makeMSD();
MSD.Validation.OK = false;
Project = SPT_Kinematics_Diffusion(makeProject(MSD));
D = Project.Analysis.Kinematics.Diffusion;

verifyTrue(testCase, D.Validation.LocalOK);
verifyFalse(testCase, D.Validation.Upstream.OK);
verifyFalse(testCase, D.Validation.OK);
verifyNotEmpty(testCase, D.Validation.Issues);
verifyEqual(testCase, D.ByTrack.DiffusionEligible, [false; false]);
verifyEqual(testCase, D.ByTrack.FitSuccessful, [false; false]);
verifyTrue(testCase, all(isnan(D.ByTrack.DiffusionCoefficient)));
verifyEqual(testCase, D.ByTrack.NFitPoints, [0; 0]);
verifyFalse(testCase, D.Ensemble.PooledFitSuccessful);
verifyTrue(testCase, isnan(D.Ensemble.PooledDiffusionCoefficient));

end

% =====================================================================
function testNegativeSlopeFitIsSuppressed(testCase)

MSD = makeMSD();
MSD.ByTrack.MSD{1} = [12; 8; 4];
MSD.ByTrack.MSDX{1} = [9; 6; 3];
MSD.ByTrack.MSDY{1} = [3; 2; 1];
Project = SPT_Kinematics_Diffusion(makeProject(MSD));
D = Project.Analysis.Kinematics.Diffusion;

verifyTrue(testCase, D.Validation.OK);
verifyEqual(testCase, D.ByTrack.NFitPoints(1), 3);
verifyFalse(testCase, D.ByTrack.FitSuccessful(1));
verifyTrue(testCase, isnan(D.ByTrack.DiffusionCoefficient(1)));
verifyTrue(testCase, isnan(D.ByTrack.FitSlope(1)));
verifyTrue(testCase, D.ByTrack.FitSuccessful(2));

end

% =====================================================================
function testInvalidMSDComponentsFailValidationAndSuppressFits(testCase)

MSD = makeMSD();
MSD.ByTrack.MSDX{1}(1) = MSD.ByTrack.MSDX{1}(1) + 1;
Project = SPT_Kinematics_Diffusion(makeProject(MSD));
D = Project.Analysis.Kinematics.Diffusion;

verifyFalse(testCase, D.Validation.LocalOK);
verifyFalse(testCase, D.Validation.OK);
verifyNotEmpty(testCase, D.Validation.Issues);
verifyEqual(testCase, D.ByTrack.DiffusionEligible, [false; false]);
verifyEqual(testCase, D.ByTrack.FitSuccessful, [false; false]);
verifyTrue(testCase, all(isnan(D.ByTrack.DiffusionCoefficient)));
verifyFalse(testCase, D.Ensemble.PooledFitSuccessful);

end

% =====================================================================
function testEmptyMSDProducesEmptyDiffusion(testCase)

MSD = makeMSD();
MSD.ByTrack = MSD.ByTrack([], :);
MSD.Ensemble.LagTime = zeros(0, 1);
MSD.Ensemble.PooledMSD = zeros(0, 1);
MSD.Ensemble.PairsByLag = zeros(0, 1);
Project = SPT_Kinematics_Diffusion(makeProject(MSD));
D = Project.Analysis.Kinematics.Diffusion;

verifyEqual(testCase, height(D.ByTrack), 0);
verifyEqual(testCase, D.Ensemble.NTrajectories, 0);
verifyEqual(testCase, D.Ensemble.NFitSuccessful, 0);
verifyTrue(testCase, isnan(D.Ensemble.EligibleFraction));
verifyTrue(testCase, isnan(D.Ensemble.MeanDiffusionCoefficient));
verifyFalse(testCase, D.Ensemble.PooledFitSuccessful);
verifyEqual(testCase, D.Summary.nFitSuccessful, 0);
verifyTrue(testCase, D.Validation.OK);

end

% =====================================================================
function testMissingMSDIsRejected(testCase)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();

verifyError(testCase, @() SPT_Kinematics_Diffusion(Project), ...
    'SPT_Kinematics_Diffusion:MissingMSD');

end

% =====================================================================
function Project = makeProject(MSD)

Project = struct();
Project.Analysis = struct();
Project.Analysis.Kinematics = struct();
Project.Analysis.Kinematics.MSD = MSD;

end

% =====================================================================
function MSD = makeMSD()

ByTrack = table();
ByTrack.DatasetIndex = [1; 2];
ByTrack.RawIndex = [11; 22];
ByTrack.Tid = [101; 202];
ByTrack.NComputedLags = [3; 2];
ByTrack.NMSDPairs = [6; 3];
ByTrack.MSDComputed = [true; true];
ByTrack.Lag = {[1; 2; 3]; [1; 2]};
ByTrack.LagTime = {[1; 2; 3]; [1; 2]};
ByTrack.MSD = {[4; 8; 12]; [8; 16]};
ByTrack.MSDX = {[3; 6; 9]; [5; 10]};
ByTrack.MSDY = {[1; 2; 3]; [3; 6]};
ByTrack.MSDPairCount = {[3; 2; 1]; [2; 1]};

Ensemble = struct();
Ensemble.LagTime = [1; 2; 3];
Ensemble.PooledMSD = [6; 12; 18];
Ensemble.PairsByLag = [5; 3; 1];

MSD = struct();
MSD.ByTrack = ByTrack;
MSD.Ensemble = Ensemble;
MSD.Summary = struct('Status', 'Core');
MSD.Validation = struct('OK', true);

end
