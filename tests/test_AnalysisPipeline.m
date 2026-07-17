function tests = test_AnalysisPipeline
% End-to-end frozen Analysis pipeline test (MATLAB R2016b compatible).

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
function testCompleteFrozenAnalysisPipeline(testCase)

stages = pipelineStages();
sourceFiles = frozenSourceFiles();
sourceBefore = readSources(testCase.TestData.ProjectDir, sourceFiles);
Project = makeProject();
completed = cell(size(stages, 1), 1);

for i = 1:size(stages, 1)
    name = stages{i, 1};
    runner = stages{i, 2};
    expectedAPI = stages{i, 3};
    Project = runner(Project);
    Module = stageOutput(Project, name);
    verifyTrue(testCase, isstruct(Module) && isscalar(Module));
    verifyEqual(testCase, fieldnames(Module), expectedAPI);
    completed{i} = name;
end

verifyEqual(testCase, completed, stages(:, 1));
verifyValidationChain(testCase, Project);
verifyCanonicalJoinKey(testCase, Project);

sourceAfter = readSources(testCase.TestData.ProjectDir, sourceFiles);
verifyEqual(testCase, sourceAfter, sourceBefore);

end


% =====================================================================
function testUpstreamValidationFailurePropagatesAndSuppressesOutputs(testCase)

stages = pipelineStages();
Project = makeProject();

% Run through the last valid sample-producing stage, then inject one
% upstream validation failure before executing its downstream consumers.
for i = 1:6
    Project = stages{i, 2}(Project);
end
Project.Analysis.Kinematics.TrajectorySamples.Validation.OK = false;
Project.Analysis.Kinematics.TrajectorySamples.Validation. ...
    Issues{end + 1, 1} = 'Injected integration failure.';
for i = 7:size(stages, 1)
    Project = stages{i, 2}(Project);
end

Kinematics = Project.Analysis.Kinematics;
downstream = {'MSD','Diffusion','StateClassification'};
for i = 1:numel(downstream)
    Validation = Kinematics.(downstream{i}).Validation;
    verifyTrue(testCase, Validation.LocalOK);
    verifyFalse(testCase, Validation.Upstream.OK);
    verifyFalse(testCase, Validation.OK);
    verifyNotEmpty(testCase, Validation.Issues);
    verifyEqual(testCase, ...
        Kinematics.(downstream{i}).ByTrack.DatasetIndex, [1; 2]);
end

verifyEqual(testCase, Kinematics.MSD.ByTrack.MSDComputed, [false; false]);
verifyEqual(testCase, Kinematics.MSD.ByTrack.NComputedLags, [0; 0]);
verifyTrue(testCase, all(cellfun(@isempty, Kinematics.MSD.ByTrack.MSD)));

verifyEqual(testCase, ...
    Kinematics.Diffusion.ByTrack.DiffusionEligible, [false; false]);
verifyEqual(testCase, ...
    Kinematics.Diffusion.ByTrack.FitSuccessful, [false; false]);
verifyTrue(testCase, all(isnan( ...
    Kinematics.Diffusion.ByTrack.DiffusionCoefficient)));
verifyEqual(testCase, Kinematics.Diffusion.ByTrack.NFitPoints, [0; 0]);

verifyEqual(testCase, ...
    Kinematics.StateClassification.ByTrack.ClassificationEligible, ...
    [false; false]);
verifyEqual(testCase, ...
    Kinematics.StateClassification.ByTrack.ClassificationSuccessful, ...
    [false; false]);
verifyEqual(testCase, ...
    Kinematics.StateClassification.ByTrack.ClassificationCode, [0; 0]);
verifyTrue(testCase, all(isnan(Kinematics.StateClassification. ...
    ByTrack.ClassificationConfidence)));

end


% =====================================================================
function testLargerSyntheticDatasetPerformanceSmoke(testCase)

nTracks = 24;
nPoints = 32;
Project = makeSyntheticProject(nTracks, nPoints);
stages = pipelineStages();

lastwarn('');
for i = 1:size(stages, 1)
    Project = stages{i, 2}(Project);
    Module = stageOutput(Project, stages{i, 1});
    verifyTrue(testCase, isstruct(Module) && isscalar(Module));
    verifyEqual(testCase, fieldnames(Module), stages{i, 3});
end
[warningMessage, warningID] = lastwarn;

verifyEmpty(testCase, warningMessage);
verifyEmpty(testCase, warningID);
verifyValidationChain(testCase, Project);
verifyScalableOutputSizes(testCase, Project, nTracks, nPoints);

end

% =====================================================================
function testFrozenPipelineRegressionStability(testCase)

stages = pipelineStages();
sourceFiles = frozenSourceFiles();
sourceBefore = readSources(testCase.TestData.ProjectDir, sourceFiles);
ProjectA = makeProject();
ProjectB = makeProject();

lastwarn('');
for i = 1:size(stages, 1)
    ProjectA = stages{i, 2}(ProjectA);
    ProjectB = stages{i, 2}(ProjectB);
    OutputA = stageOutput(ProjectA, stages{i, 1});
    OutputB = stageOutput(ProjectB, stages{i, 1});
    verifyEqual(testCase, fieldnames(OutputA), stages{i, 3});
    verifyTrue(testCase, isequaln(OutputA, OutputB));
end
[warningMessage, warningID] = lastwarn;

verifyEmpty(testCase, warningMessage);
verifyEmpty(testCase, warningID);
verifyValidationChain(testCase, ProjectA);
verifyCanonicalJoinKey(testCase, ProjectA);
verifyRegressionSignature(testCase, ProjectA);
verifyEqual(testCase, ...
    readSources(testCase.TestData.ProjectDir, sourceFiles), sourceBefore);

end

% =====================================================================
function stages = pipelineStages()

geometryAPI = {'X';'Y';'DX';'DY';'Displacement';'StepLength'; ...
    'Direction';'Velocity';'Acceleration';'Time';'CentroidX'; ...
    'CentroidY';'NetDisplacement';'CumulativeDistance'; ...
    'TrackLength';'NSteps';'Summary'};
standardAPI = {'ByTrack';'Ensemble';'Summary';'Validation'};

stages = { ...
    'Geometry', @SPT_CreateGeometry, geometryAPI; ...
    'Step', @SPT_Kinematics_Step, ...
        {'Table';'ByTrack';'ByState';'Ensemble';'Summary';'Validation'}; ...
    'Trajectory', @SPT_Kinematics_Trajectory, standardAPI; ...
    'Confinement', @SPT_Kinematics_Confinement, standardAPI; ...
    'TurningAngle', @SPT_Kinematics_TurningAngle, standardAPI; ...
    'TrajectorySamples', @SPT_Kinematics_TrajectorySamples, ...
        {'Samples';'ByTrack';'Ensemble';'Summary';'Validation'}; ...
    'MSD', @SPT_Kinematics_MSD, standardAPI; ...
    'Diffusion', @SPT_Kinematics_Diffusion, standardAPI; ...
    'StateClassification', @SPT_Kinematics_StateClassification, ...
        standardAPI};

end


% =====================================================================
function Module = stageOutput(Project, name)

if strcmp(name, 'Geometry')
    Module = Project.Geometry;
else
    Module = Project.Analysis.Kinematics.(name);
end

end


% =====================================================================
function verifyValidationChain(testCase, Project)

verifyTrue(testCase, Project.Flags.Geometry);
verifyTrue(testCase, Project.Validation.GeometryOK);

names = {'Step','Trajectory','Confinement','TurningAngle', ...
    'TrajectorySamples','MSD','Diffusion','StateClassification'};
sources = { ...
    'Project.Tables.Localization'; ...
    'Project.Analysis.Kinematics.Step'; ...
    'Project.Analysis.Kinematics.Trajectory.ByTrack'; ...
    'Project.Analysis.Kinematics.Trajectory.ByTrack'; ...
    'Project.Tables.Localization'; ...
    'Project.Analysis.Kinematics.TrajectorySamples'; ...
    'Project.Analysis.Kinematics.MSD'; ...
    'Project.Analysis.Kinematics frozen outputs'};

for i = 1:numel(names)
    Validation = Project.Analysis.Kinematics.(names{i}).Validation;
    verifyTrue(testCase, Validation.OK);
    verifyEmpty(testCase, Validation.Issues);
    verifyEqual(testCase, Validation.Source, sources{i});
end

propagated = {'TrajectorySamples','MSD','Diffusion', ...
    'StateClassification'};
for i = 1:numel(propagated)
    Validation = Project.Analysis.Kinematics.(propagated{i}).Validation;
    verifyTrue(testCase, Validation.LocalOK);
    verifyTrue(testCase, Validation.Upstream.OK);
    verifyTrue(testCase, Validation.OK == ...
        (Validation.LocalOK && Validation.Upstream.OK));
end

end


% =====================================================================
function verifyCanonicalJoinKey(testCase, Project)

Kinematics = Project.Analysis.Kinematics;
canonicalIDs = Kinematics.Trajectory.ByTrack.DatasetIndex;
verifyEqual(testCase, canonicalIDs, [1; 2]);
verifyEqual(testCase, Project.Geometry.Summary.nTraj, ...
    numel(canonicalIDs));

byTrackModules = {'Step','Trajectory','Confinement','TurningAngle', ...
    'TrajectorySamples','MSD','Diffusion','StateClassification'};
for i = 1:numel(byTrackModules)
    ByTrack = Kinematics.(byTrackModules{i}).ByTrack;
    verifyTrue(testCase, ...
        ismember('DatasetIndex', ByTrack.Properties.VariableNames));
    verifyEqual(testCase, ByTrack.DatasetIndex, canonicalIDs);
    verifyEqual(testCase, ByTrack.RawIndex, ...
        Kinematics.Trajectory.ByTrack.RawIndex);
    verifyEqual(testCase, ByTrack.Tid, ...
        Kinematics.Trajectory.ByTrack.Tid);
end

verifyEqual(testCase, Kinematics.Step.Table.DatasetIndex, [1; 1; 2]);
verifyEqual(testCase, ...
    Kinematics.TrajectorySamples.Samples.DatasetIndex, ...
    [1; 1; 1; 2; 2]);

end


% =====================================================================
function files = frozenSourceFiles()

files = { ...
    'SPT_CreateGeometry.m'; ...
    'SPT_Kinematics_Step.m'; ...
    'SPT_Kinematics_Trajectory.m'; ...
    'SPT_Kinematics_Confinement.m'; ...
    'SPT_Kinematics_TurningAngle.m'; ...
    'SPT_Kinematics_TrajectorySamples.m'; ...
    'SPT_Kinematics_MSD.m'; ...
    'SPT_Kinematics_Diffusion.m'; ...
    'SPT_Kinematics_StateClassification.m'};

end


% =====================================================================
function contents = readSources(projectDir, files)

contents = cell(size(files));
for i = 1:numel(files)
    contents{i} = fileread(fullfile(projectDir, files{i}));
end

end


% =====================================================================
function verifyScalableOutputSizes(testCase, Project, nTracks, nPoints)

Kinematics = Project.Analysis.Kinematics;
canonicalIDs = (1:nTracks)';
verifyEqual(testCase, Project.Geometry.Summary.nTraj, nTracks);
verifyEqual(testCase, size(Project.Geometry.X), [nTracks, 1]);
verifyEqual(testCase, size(Project.Geometry.Y), [nTracks, 1]);
verifyEqual(testCase, size(Project.Geometry.StepLength), [nTracks, 1]);
for i = 1:nTracks
    verifyEqual(testCase, numel(Project.Geometry.X{i}), nPoints);
    verifyEqual(testCase, numel(Project.Geometry.Y{i}), nPoints);
    verifyEqual(testCase, ...
        numel(Project.Geometry.StepLength{i}), nPoints - 1);
end

byTrackModules = {'Step','Trajectory','Confinement','TurningAngle', ...
    'TrajectorySamples','MSD','Diffusion','StateClassification'};
for i = 1:numel(byTrackModules)
    ByTrack = Kinematics.(byTrackModules{i}).ByTrack;
    verifyEqual(testCase, height(ByTrack), nTracks);
    verifyEqual(testCase, ByTrack.DatasetIndex, canonicalIDs);
end

verifyEqual(testCase, height(Kinematics.Step.Table), ...
    nTracks * (nPoints - 1));
verifyEqual(testCase, accumarray( ...
    Kinematics.Step.Table.DatasetIndex, 1, [nTracks, 1]), ...
    repmat(nPoints - 1, nTracks, 1));
verifyEqual(testCase, height(Kinematics.TrajectorySamples.Samples), ...
    nTracks * nPoints);
verifyEqual(testCase, accumarray( ...
    Kinematics.TrajectorySamples.Samples.DatasetIndex, 1, ...
    [nTracks, 1]), repmat(nPoints, nTracks, 1));

msdCells = {'Lag','LagTime','MSD','MSDX','MSDY','MSDPairCount'};
for i = 1:numel(msdCells)
    verifyEqual(testCase, ...
        size(Kinematics.MSD.ByTrack.(msdCells{i})), [nTracks, 1]);
end
verifyEqual(testCase, ...
    size(Kinematics.Diffusion.ByTrack.DiffusionCoefficient), ...
    [nTracks, 1]);
verifyEqual(testCase, ...
    size(Kinematics.StateClassification.ByTrack.ClassificationCode), ...
    [nTracks, 1]);

end


% =====================================================================
function verifyRegressionSignature(testCase, Project)

Kinematics = Project.Analysis.Kinematics;
verifyEqual(testCase, Project.Geometry.Summary.TotalSteps, 3);
verifyEqual(testCase, Project.Geometry.Summary.TotalDistance, 12, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, Kinematics.Step.Summary.nInputRows, 5);
verifyEqual(testCase, Kinematics.Step.Summary.nSteps, 3);
verifyEqual(testCase, Kinematics.Step.Summary.TotalDistance, 12, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, Kinematics.Trajectory.Summary.nTrajectories, 2);
verifyEqual(testCase, Kinematics.Trajectory.Summary.nSteps, 3);
verifyEqual(testCase, Kinematics.TrajectorySamples.Summary.nSamples, 5);
verifyEqual(testCase, Kinematics.TrajectorySamples.Summary.nPairs, 3);
verifyEqual(testCase, Kinematics.MSD.Summary.nComputedTrajectories, 2);
verifyEqual(testCase, Kinematics.Diffusion.Summary.nFitSuccessful, 1);
verifyEqual(testCase, ...
    Kinematics.StateClassification.Summary.nClassifiedTrajectories, 1);

end

% =====================================================================
function Project = makeSyntheticProject(nTracks, nPoints)

dt = 0.05;
nRows = nTracks * nPoints;
trajectories = cell(nTracks, 1);
DatasetIndex = zeros(nRows, 1);
RawIndex = zeros(nRows, 1);
Tid = zeros(nRows, 1);
Frame = zeros(nRows, 1);
Time = zeros(nRows, 1);
X = zeros(nRows, 1);
Y = zeros(nRows, 1);
State = zeros(nRows, 1);
StepLength = nan(nRows, 1);

for i = 1:nTracks
    localRows = (1:nPoints)';
    rows = (i - 1) * nPoints + localRows;
    frame = localRows;
    time = (frame - 1) * dt;
    x = (frame - 1) * (1 + 0.01 * i);
    y = 0.2 * sin((frame - 1) / 4 + i / 3);
    stepLength = [sqrt(diff(x) .^ 2 + diff(y) .^ 2); NaN];

    trajectories{i} = [x, y];
    DatasetIndex(rows) = i;
    RawIndex(rows) = 1000 + i;
    Tid(rows) = 2000 + i;
    Frame(rows) = frame;
    Time(rows) = time;
    X(rows) = x;
    Y(rows) = y;
    State(rows) = mod(frame - 1, 2) + 1;
    StepLength(rows) = stepLength;
end

Localization = table(DatasetIndex, RawIndex, Tid, Frame, Time, X, Y, ...
    State, StepLength);
Project = struct();
Project.Dataset = struct('Trajectory', {trajectories}, ...
    'nTraj', nTracks, 'dt', dt);
Project.Flags = struct('Dataset', true);
Project.Validation = struct('DatasetOK', true, 'LocalizationOK', true);
Project.Tables = struct('Localization', Localization);

end

% =====================================================================
function Project = makeProject()

Project = struct();
Project.Dataset = struct();
Project.Dataset.Trajectory = { ...
    [0, 0; 3, 4; 6, 8]; ...
    [0, 0; 2, 0]};
Project.Dataset.nTraj = 2;
Project.Dataset.dt = 0.5;

Project.Flags = struct();
Project.Flags.Dataset = true;
Project.Validation = struct();
Project.Validation.DatasetOK = true;
Project.Validation.LocalizationOK = true;

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
Project.Tables = struct();
Project.Tables.Localization = Localization;

end
