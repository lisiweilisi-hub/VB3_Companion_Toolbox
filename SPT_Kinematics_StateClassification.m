function Project = SPT_Kinematics_StateClassification(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_StateClassification
%
% Initialize state-classification analysis from frozen kinematics outputs.
%
% Input
%   Project.Analysis.Kinematics frozen analysis outputs
%
% Output
%   Project.Analysis.Kinematics.StateClassification
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_StateClassification:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for future classification configuration.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Analysis') || ...
        ~isstruct(Project.Analysis) || ~isscalar(Project.Analysis) || ...
        ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics)
    error('SPT_Kinematics_StateClassification:MissingKinematics', ...
        'Project.Analysis.Kinematics not found.');
end

Kinematics = Project.Analysis.Kinematics;
requiredModules = {'Trajectory','Confinement','TurningAngle', ...
    'MSD','Diffusion','TurningBehavior'};
for i = 1:numel(requiredModules)
    name = requiredModules{i};
    if ~isfield(Kinematics, name) || ...
            ~isstruct(Kinematics.(name)) || ...
            ~isscalar(Kinematics.(name))
        error('SPT_Kinematics_StateClassification:MissingInput', ...
            'Project.Analysis.Kinematics.%s not found.', name);
    end
end

Trajectory = Kinematics.Trajectory;
Confinement = Kinematics.Confinement;
TurningAngle = Kinematics.TurningAngle;
MSD = Kinematics.MSD;
Diffusion = Kinematics.Diffusion;
TurningBehavior = Kinematics.TurningBehavior;
validateByTrackContainer(Trajectory, 'Trajectory');
validateByTrackContainer(Confinement, 'Confinement');
validateByTrackContainer(TurningAngle, 'TurningAngle');
validateByTrackContainer(MSD, 'MSD');
validateByTrackContainer(Diffusion, 'Diffusion');
validateByTrackContainer(TurningBehavior, 'TurningBehavior');

trajectoryNumeric = {'DatasetIndex','RawIndex','Tid', ...
    'NSteps','NFiniteSteps'};
evidenceNumeric = {'DatasetIndex','RawIndex','Tid'};
validateNumericColumns(Trajectory.ByTrack, trajectoryNumeric, ...
    'Trajectory');
validateNumericColumns(Confinement.ByTrack, evidenceNumeric, ...
    'Confinement');
validateNumericColumns(TurningAngle.ByTrack, evidenceNumeric, ...
    'TurningAngle');
validateNumericColumns(MSD.ByTrack, evidenceNumeric, 'MSD');
validateNumericColumns(Diffusion.ByTrack, ...
    [evidenceNumeric {'DiffusionCoefficient','FitRSquared'}], ...
    'Diffusion');
validateNumericColumns(TurningBehavior.ByTrack, ...
    [evidenceNumeric {'BehaviorScore'}], 'TurningBehavior');
validateLogicalColumn(Confinement.ByTrack, ...
    'ConfinementEligible', 'Confinement');
validateLogicalColumn(TurningAngle.ByTrack, ...
    'TurningAngleEligible', 'TurningAngle');
validateLogicalColumn(MSD.ByTrack, 'MSDComputed', 'MSD');
validateLogicalColumn(Diffusion.ByTrack, ...
    'FitSuccessful', 'Diffusion');
validateLogicalColumn(TurningBehavior.ByTrack, ...
    'TurningBehaviorAvailable', 'TurningBehavior');
validateLogicalColumn(TurningBehavior.ByTrack, ...
    'TurningBehaviorEligible', 'TurningBehavior');
validateLogicalColumn(TurningBehavior.ByTrack, ...
    'BehaviorClassified', 'TurningBehavior');
validateCellStringColumn(TurningBehavior.ByTrack, ...
    'TurningBehaviorClass', 'TurningBehavior');
validateCellStringColumn(TurningBehavior.ByTrack, ...
    'BehaviorLabel', 'TurningBehavior');

[TrajectoryByTrack, trajectorySorted] = normalizeByTrack( ...
    Trajectory.ByTrack(:, trajectoryNumeric));
[ConfinementByTrack, confinementSorted] = normalizeByTrack( ...
    Confinement.ByTrack(:, ...
    [evidenceNumeric {'ConfinementEligible'}]));
[TurningAngleByTrack, turningAngleSorted] = normalizeByTrack( ...
    TurningAngle.ByTrack(:, ...
    [evidenceNumeric {'TurningAngleEligible'}]));
[MSDByTrack, msdSorted] = normalizeByTrack( ...
    MSD.ByTrack(:, [evidenceNumeric {'MSDComputed'}]));
[DiffusionByTrack, diffusionSorted] = normalizeByTrack( ...
    Diffusion.ByTrack(:, ...
    [evidenceNumeric ...
    {'DiffusionCoefficient','FitRSquared','FitSuccessful'}]));
turningBehaviorColumns = [evidenceNumeric ...
    {'TurningBehaviorAvailable','TurningBehaviorEligible', ...
    'TurningBehaviorClass','BehaviorLabel','BehaviorScore', ...
    'BehaviorClassified'}];
[TurningBehaviorByTrack, turningBehaviorSorted] = normalizeByTrack( ...
    TurningBehavior.ByTrack(:, turningBehaviorColumns));

sources = { ...
    'Project.Analysis.Kinematics.Trajectory.ByTrack'; ...
    'Project.Analysis.Kinematics.Confinement'; ...
    'Project.Analysis.Kinematics.TurningAngle'; ...
    'Project.Analysis.Kinematics.MSD'; ...
    'Project.Analysis.Kinematics.Diffusion'; ...
    'Project.Analysis.Kinematics.TurningBehavior'};

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.Source = 'Project.Analysis.Kinematics frozen outputs';
Validation.InputSources = sources;
Validation.Upstream = readUpstreamValidation( ...
    Trajectory, Confinement, TurningAngle, MSD, Diffusion, ...
    TurningBehavior);
Validation.RequiredModules = requiredModules;
Validation.NInputTrajectories = height(TrajectoryByTrack);
Validation.SortedInternally = struct( ...
    'Trajectory', trajectorySorted, ...
    'Confinement', confinementSorted, ...
    'TurningAngle', turningAngleSorted, ...
    'MSD', msdSorted, ...
    'Diffusion', diffusionSorted, ...
    'TurningBehavior', turningBehaviorSorted);

if any(~isfinite(TrajectoryByTrack.DatasetIndex)) || ...
        any(TrajectoryByTrack.DatasetIndex ~= ...
        floor(TrajectoryByTrack.DatasetIndex))
    Validation = addIssue(Validation, ...
        'Trajectory DatasetIndex must contain finite integer values.');
end
if numel(unique(TrajectoryByTrack.DatasetIndex)) ~= ...
        height(TrajectoryByTrack)
    Validation = addIssue(Validation, ...
        'Trajectory DatasetIndex must be unique.');
end
if any(~isfinite(TrajectoryByTrack.RawIndex)) || ...
        any(~isfinite(TrajectoryByTrack.Tid))
    Validation = addIssue(Validation, ...
        'Trajectory RawIndex and Tid must contain finite values.');
end
if any(~isfinite(TrajectoryByTrack.NSteps)) || ...
        any(TrajectoryByTrack.NSteps < 0) || ...
        any(TrajectoryByTrack.NSteps ~= floor(TrajectoryByTrack.NSteps)) || ...
        any(~isfinite(TrajectoryByTrack.NFiniteSteps)) || ...
        any(TrajectoryByTrack.NFiniteSteps < 0) || ...
        any(TrajectoryByTrack.NFiniteSteps ~= ...
        floor(TrajectoryByTrack.NFiniteSteps)) || ...
        any(TrajectoryByTrack.NFiniteSteps > TrajectoryByTrack.NSteps)
    Validation = addIssue(Validation, ...
        'Trajectory step counts must contain consistent nonnegative integers.');
end

[confinementRows, confinementComplete] = mapRows( ...
    TrajectoryByTrack.DatasetIndex, ConfinementByTrack.DatasetIndex);
[turningAngleRows, turningAngleComplete] = mapRows( ...
    TrajectoryByTrack.DatasetIndex, TurningAngleByTrack.DatasetIndex);
[msdRows, msdComplete] = mapRows( ...
    TrajectoryByTrack.DatasetIndex, MSDByTrack.DatasetIndex);
[diffusionRows, diffusionComplete] = mapRows( ...
    TrajectoryByTrack.DatasetIndex, DiffusionByTrack.DatasetIndex);
[turningBehaviorRows, turningBehaviorComplete] = mapRows( ...
    TrajectoryByTrack.DatasetIndex, TurningBehaviorByTrack.DatasetIndex);

if ~validEvidenceIdentifiers(ConfinementByTrack) || ...
        ~validEvidenceIdentifiers(TurningAngleByTrack) || ...
        ~validEvidenceIdentifiers(MSDByTrack) || ...
        ~validEvidenceIdentifiers(DiffusionByTrack) || ...
        ~validEvidenceIdentifiers(TurningBehaviorByTrack)
    Validation = addIssue(Validation, ...
        'Evidence DatasetIndex values must be finite, integer, and unique.');
end
if ~(confinementComplete && turningAngleComplete && ...
        msdComplete && diffusionComplete && turningBehaviorComplete)
    Validation = addIssue(Validation, ...
        'Every trajectory must be represented in each evidence module.');
end
if ~identifiersMatch(TrajectoryByTrack, ConfinementByTrack, ...
        confinementRows) || ...
        ~identifiersMatch(TrajectoryByTrack, TurningAngleByTrack, ...
        turningAngleRows) || ...
        ~identifiersMatch(TrajectoryByTrack, MSDByTrack, msdRows) || ...
        ~identifiersMatch(TrajectoryByTrack, DiffusionByTrack, diffusionRows) || ...
        ~identifiersMatch(TrajectoryByTrack, TurningBehaviorByTrack, ...
        turningBehaviorRows)
    Validation = addIssue(Validation, ...
        'RawIndex and Tid must agree across frozen analysis outputs.');
end

ByTrack = TrajectoryByTrack;
n = height(ByTrack);
ByTrack.HasConfinementEvidence = false(n, 1);
ByTrack.ConfinementEligible = false(n, 1);
ByTrack.HasTurningAngleEvidence = false(n, 1);
ByTrack.HasMSDEvidence = false(n, 1);
ByTrack.HasDiffusionEvidence = false(n, 1);
ByTrack.DiffusionCoefficient = nan(n, 1);
ByTrack.DiffusionFitRSquared = nan(n, 1);
ByTrack.TurningBehaviorAvailable = false(n, 1);
ByTrack.TurningBehaviorEligible = false(n, 1);
ByTrack.TurningBehaviorClass = repmat({'Unavailable'}, n, 1);
ByTrack.BehaviorLabel = repmat({'Unclassified'}, n, 1);
ByTrack.BehaviorScore = zeros(n, 1);
ByTrack.BehaviorClassified = false(n, 1);

valid = confinementRows > 0;
ByTrack.HasConfinementEvidence(valid) = logical( ...
    ConfinementByTrack.ConfinementEligible(confinementRows(valid)));
ByTrack.ConfinementEligible = ByTrack.HasConfinementEvidence;
valid = turningAngleRows > 0;
ByTrack.HasTurningAngleEvidence(valid) = logical( ...
    TurningAngleByTrack.TurningAngleEligible(turningAngleRows(valid)));
valid = msdRows > 0;
ByTrack.HasMSDEvidence(valid) = logical( ...
    MSDByTrack.MSDComputed(msdRows(valid)));
valid = diffusionRows > 0;
fitSuccessful = false(n, 1);
fitSuccessful(valid) = logical( ...
    DiffusionByTrack.FitSuccessful(diffusionRows(valid)));
coefficient = nan(n, 1);
coefficient(valid) = ...
    DiffusionByTrack.DiffusionCoefficient(diffusionRows(valid));
rSquared = nan(n, 1);
rSquared(valid) = ...
    DiffusionByTrack.FitRSquared(diffusionRows(valid));
validDiffusion = fitSuccessful & isfinite(coefficient) & ...
    coefficient >= 0 & isfinite(rSquared) & ...
    rSquared >= 0 & rSquared <= 1;
ByTrack.HasDiffusionEvidence = validDiffusion;
ByTrack.DiffusionCoefficient(validDiffusion) = ...
    coefficient(validDiffusion);
ByTrack.DiffusionFitRSquared(validDiffusion) = ...
    rSquared(validDiffusion);
valid = turningBehaviorRows > 0;
ByTrack.TurningBehaviorAvailable(valid) = logical( ...
    TurningBehaviorByTrack.TurningBehaviorAvailable( ...
    turningBehaviorRows(valid)));
ByTrack.TurningBehaviorEligible(valid) = logical( ...
    TurningBehaviorByTrack.TurningBehaviorEligible( ...
    turningBehaviorRows(valid)));
ByTrack.TurningBehaviorClass(valid) = ...
    TurningBehaviorByTrack.TurningBehaviorClass(turningBehaviorRows(valid));
ByTrack.BehaviorLabel(valid) = ...
    TurningBehaviorByTrack.BehaviorLabel(turningBehaviorRows(valid));
ByTrack.BehaviorScore(valid) = ...
    TurningBehaviorByTrack.BehaviorScore(turningBehaviorRows(valid));
ByTrack.BehaviorClassified(valid) = logical( ...
    TurningBehaviorByTrack.BehaviorClassified(turningBehaviorRows(valid)));
ByTrack.NAvailableFeatures = ...
    double(ByTrack.HasConfinementEvidence) + ...
    double(ByTrack.HasTurningAngleEvidence) + ...
    double(ByTrack.HasMSDEvidence) + ...
    double(ByTrack.HasDiffusionEvidence) + ...
    double(ByTrack.TurningBehaviorAvailable);

if any(~isfinite(TurningBehaviorByTrack.BehaviorScore)) || ...
        any(TurningBehaviorByTrack.BehaviorScore < 0) || ...
        any(TurningBehaviorByTrack.BehaviorScore > 1)
    Validation = addIssue(Validation, ...
        'TurningBehavior BehaviorScore values must be finite from zero to one.');
end
if any(TurningBehaviorByTrack.BehaviorClassified & ...
        ~(TurningBehaviorByTrack.TurningBehaviorAvailable & ...
        TurningBehaviorByTrack.TurningBehaviorEligible))
    Validation = addIssue(Validation, ...
        ['Classified TurningBehavior rows must be available ' ...
        'and eligible.']);
end
if any(TurningBehaviorByTrack.BehaviorClassified & ...
        strcmp(TurningBehaviorByTrack.BehaviorLabel, 'Unclassified')) || ...
        any(~TurningBehaviorByTrack.BehaviorClassified & ...
        ~strcmp(TurningBehaviorByTrack.BehaviorLabel, 'Unclassified'))
    Validation = addIssue(Validation, ...
        ['TurningBehavior BehaviorLabel and BehaviorClassified ' ...
        'must be consistent.']);
end
if any(fitSuccessful & ~validDiffusion)
    Validation = addIssue(Validation, ...
        ['Successful diffusion fits must have finite nonnegative ' ...
        'coefficients and finite R-squared values from zero to one.']);
end
if any(~fitSuccessful & ...
        (~isnan(coefficient) | ~isnan(rSquared)))
    Validation = addIssue(Validation, ...
        ['Unsuccessful diffusion fits must suppress diffusion ' ...
        'coefficients and R-squared values as NaN.']);
end

Validation.LocalOK = Validation.OK;
if ~Validation.Upstream.OK
    Validation = addIssue(Validation, ...
        'One or more frozen upstream validations are missing or failed.');
end
Validation.OK = Validation.LocalOK && Validation.Upstream.OK;

ByTrack.ClassificationEligible = ByTrack.NAvailableFeatures > 0 & ...
    logical(Validation.OK);
ByTrack = classifyCore(ByTrack, Validation.OK);
Ensemble = summarizeEnsemble(ByTrack);

Summary = struct();
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nTrajectoriesWithEvidence = ...
    Ensemble.NTrajectoriesWithEvidence;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.MeanAvailableFeatures = Ensemble.MeanAvailableFeatures;
Summary.nClassifiedTrajectories = Ensemble.NClassifiedTrajectories;
Summary.nBrownianCandidates = Ensemble.NBrownianCandidates;
Summary.BrownianCandidateFraction = ...
    Ensemble.BrownianCandidateFraction;
Summary.MeanClassificationConfidence = ...
    Ensemble.MeanClassificationConfidence;
Summary.MeanClassifiedDiffusionCoefficient = ...
    Ensemble.MeanClassifiedDiffusionCoefficient;
Summary.Status = 'Core';

StateClassification = struct();
StateClassification.ByTrack = ByTrack;
StateClassification.Ensemble = Ensemble;
StateClassification.Summary = Summary;
StateClassification.Validation = Validation;

Project.Analysis.Kinematics.StateClassification = ...
    StateClassification;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics State Classification\n');
fprintf('=====================================================\n');
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Eligible rows     : %d\n', Summary.nEligibleTrajectories);
fprintf('Status            : %s\n', Summary.Status);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateByTrackContainer(Module, moduleName)

if ~isfield(Module, 'ByTrack') || ~istable(Module.ByTrack)
    error('SPT_Kinematics_StateClassification:InvalidByTrack', ...
        '%s.ByTrack must be a table.', moduleName);
end

end

% =====================================================================
function validateNumericColumns(T, required, moduleName)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_StateClassification:MissingColumn', ...
            '%s.ByTrack missing column: %s', moduleName, name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_StateClassification:InvalidColumn', ...
            ['%s.ByTrack column %s must be a real numeric ' ...
            'vector.'], moduleName, name);
    end
end

end

% =====================================================================
function validateLogicalColumn(T, name, moduleName)

if ~ismember(name, T.Properties.VariableNames)
    error('SPT_Kinematics_StateClassification:MissingColumn', ...
        '%s.ByTrack missing column: %s', moduleName, name);
end
value = T.(name);
validType = islogical(value) || (isnumeric(value) && isreal(value));
if ~validType || ~isvector(value) || numel(value) ~= height(T) || ...
        any(~isfinite(value)) || any(~(value == 0 | value == 1))
    error('SPT_Kinematics_StateClassification:InvalidColumn', ...
        '%s.ByTrack column %s must be a logical vector.', ...
        moduleName, name);
end

end

% =====================================================================
function validateCellStringColumn(T, name, moduleName)

if ~ismember(name, T.Properties.VariableNames)
    error('SPT_Kinematics_StateClassification:MissingColumn', ...
        '%s.ByTrack missing column: %s', moduleName, name);
end
value = T.(name);
if ~iscell(value) || ~isvector(value) || numel(value) ~= height(T) || ...
        any(~cellfun(@ischar, value))
    error('SPT_Kinematics_StateClassification:InvalidColumn', ...
        '%s.ByTrack column %s must be a cell string vector.', ...
        moduleName, name);
end

end
% =====================================================================
function [T, sortedInternally] = normalizeByTrack(T)

sortedInternally = false;
if isempty(T)
    return
end
[T, order] = sortrows(T, 'DatasetIndex');
sortedInternally = ~isequal(order(:), (1:height(T))');

end

% =====================================================================
function tf = validEvidenceIdentifiers(T)

tf = all(isfinite(T.DatasetIndex)) && ...
    all(T.DatasetIndex == floor(T.DatasetIndex)) && ...
    numel(unique(T.DatasetIndex)) == height(T) && ...
    all(isfinite(T.RawIndex)) && all(isfinite(T.Tid));

end

% =====================================================================
function [rows, complete] = mapRows(canonicalIDs, evidenceIDs)

rows = zeros(numel(canonicalIDs), 1);
for i = 1:numel(canonicalIDs)
    match = find(evidenceIDs == canonicalIDs(i), 1, 'first');
    if ~isempty(match)
        rows(i) = match;
    end
end
complete = all(rows > 0);

end

% =====================================================================
function tf = identifiersMatch(Canonical, Evidence, rows)

tf = true;
valid = rows > 0;
if any(Canonical.RawIndex(valid) ~= Evidence.RawIndex(rows(valid))) || ...
        any(Canonical.Tid(valid) ~= Evidence.Tid(rows(valid)))
    tf = false;
end

end

% =====================================================================
function Upstream = readUpstreamValidation(Trajectory, Confinement, ...
        TurningAngle, MSD, Diffusion, TurningBehavior)

names = {'Trajectory','Confinement','TurningAngle','MSD','Diffusion', ...
    'TurningBehavior'};
modules = {Trajectory, Confinement, TurningAngle, MSD, Diffusion, ...
    TurningBehavior};
Upstream = struct();
Upstream.Source = cell(numel(names), 1);
Upstream.Available = true;
Upstream.OK = true;
Upstream.Issues = {};

for i = 1:numel(names)
    name = names{i};
    Upstream.Source{i, 1} = ...
        ['Project.Analysis.Kinematics.' name '.Validation'];
    moduleStatus = struct('Available', false, 'OK', false);
    Module = modules{i};
    if isfield(Module, 'Validation') && ...
            isstruct(Module.Validation) && ...
            isscalar(Module.Validation) && ...
            isfield(Module.Validation, 'OK')
        value = Module.Validation.OK;
        if isscalar(value) && ...
                (islogical(value) || ...
                (isnumeric(value) && isreal(value))) && ...
                (~isnumeric(value) || ...
                (isfinite(value) && (value == 0 || value == 1)))
            moduleStatus.Available = true;
            moduleStatus.OK = logical(value);
        end
    end
    Upstream.(name) = moduleStatus;
    Upstream.Available = Upstream.Available && ...
        moduleStatus.Available;
    Upstream.OK = Upstream.OK && moduleStatus.OK;
    if ~moduleStatus.Available
        Upstream.Issues{end + 1, 1} = ...
            [name '.Validation.OK is missing or invalid.'];
    elseif ~moduleStatus.OK
        Upstream.Issues{end + 1, 1} = ...
            [name '.Validation.OK is false.'];
    end
end

end

% =====================================================================
function T = classifyCore(T, validationOK)

n = height(T);
T.ClassificationCode = zeros(n, 1);
T.ClassificationLabel = repmat({'Unclassified'}, n, 1);
T.ClassificationConfidence = nan(n, 1);
T.ClassificationSuccessful = false(n, 1);
T.ClassificationBasis = repmat({'None'}, n, 1);

if ~logical(validationOK)
    return;
end

for i = 1:n
    if ~T.ClassificationEligible(i)
        continue;
    end

    hasBrownian = T.HasDiffusionEvidence(i);
    turningType = getTurningStateType(T, i);
    hasTurning = ~strcmp(turningType, 'None');
    strongTurning = hasTurning && ...
        ~strcmp(turningType, 'BrownianLike') && ...
        T.BehaviorScore(i) >= 0.6;

    if strcmp(turningType, 'Mixed') || (hasBrownian && strongTurning)
        T = setClassification(T, i, 6, 'MixedCandidate', ...
            fusedConfidence(T, i, hasBrownian), ...
            classificationBasis(hasBrownian, true));
    elseif hasBrownian
        T = setClassification(T, i, 1, 'BrownianCandidate', ...
            T.DiffusionFitRSquared(i), 'BaselineBrownianFit');
    elseif strcmp(turningType, 'Rotational')
        T = setClassification(T, i, 3, 'RotationalCandidate', ...
            T.BehaviorScore(i), 'TurningBehavior');
    elseif strcmp(turningType, 'Spiral')
        T = setClassification(T, i, 4, 'SpiralCandidate', ...
            T.BehaviorScore(i), 'TurningBehavior');
    elseif strcmp(turningType, 'Oscillatory')
        T = setClassification(T, i, 5, 'OscillatoryCandidate', ...
            T.BehaviorScore(i), 'TurningBehavior');
    elseif strcmp(turningType, 'BrownianLike')
        T = setClassification(T, i, 1, 'BrownianCandidate', ...
            T.BehaviorScore(i), 'TurningBehaviorBrownianLike');
    elseif T.ConfinementEligible(i)
        T = setClassification(T, i, 2, 'ConfinedCandidate', ...
            1, 'ConfinementEligible');
    end
end

end

% =====================================================================
function turningType = getTurningStateType(T, row)

turningType = 'None';
hasEvidence = T.TurningBehaviorAvailable(row) && ...
    T.TurningBehaviorEligible(row) && T.BehaviorClassified(row);
if ~hasEvidence
    return;
end

label = T.BehaviorLabel{row};
behaviorClass = T.TurningBehaviorClass{row};

if strcmp(label, 'Mixed') || strcmp(behaviorClass, 'MixedRotation') || ...
        strcmp(behaviorClass, 'Mixed')
    turningType = 'Mixed';
elseif strcmp(label, 'SpiralIn') || strcmp(label, 'SpiralOut') || ...
        strcmp(behaviorClass, 'SpiralIn') || ...
        strcmp(behaviorClass, 'SpiralOut')
    turningType = 'Spiral';
elseif strcmp(label, 'Oscillation') || ...
        strcmp(behaviorClass, 'Oscillation') || ...
        strcmp(behaviorClass, 'AlternatingRotation')
    turningType = 'Oscillatory';
elseif strcmp(label, 'ClockwiseRotation') || ...
        strcmp(label, 'CounterclockwiseRotation') || ...
        strcmp(label, 'InPlaceRotation') || ...
        strcmp(behaviorClass, 'ClockwiseRotation') || ...
        strcmp(behaviorClass, 'CounterclockwiseRotation') || ...
        strcmp(behaviorClass, 'InPlaceRotation')
    turningType = 'Rotational';
elseif strcmp(label, 'BrownianLike') || ...
        strcmp(behaviorClass, 'BrownianLike') || ...
        strcmp(behaviorClass, 'Straight')
    turningType = 'BrownianLike';
end

end

% =====================================================================
function T = setClassification(T, row, code, label, confidence, basis)

T.ClassificationCode(row) = code;
T.ClassificationLabel{row} = label;
T.ClassificationConfidence(row) = max(0, min(1, confidence));
T.ClassificationSuccessful(row) = true;
T.ClassificationBasis{row} = basis;

end

% =====================================================================
function confidence = fusedConfidence(T, row, hasBrownian)

if hasBrownian
    confidence = mean([T.DiffusionFitRSquared(row), T.BehaviorScore(row)]);
else
    confidence = T.BehaviorScore(row);
end

end

% =====================================================================
function basis = classificationBasis(hasBrownian, hasTurning)

if hasBrownian && hasTurning
    basis = 'BrownianFit+TurningBehavior';
elseif hasTurning
    basis = 'TurningBehavior';
else
    basis = 'None';
end

end

% =====================================================================
function E = summarizeEnsemble(T)

E = struct();
E.NTrajectories = height(T);
E.NTrajectoriesWithEvidence = sum(T.NAvailableFeatures > 0);
E.NEligibleTrajectories = sum(T.ClassificationEligible);
E.NClassifiedTrajectories = sum(T.ClassificationSuccessful);
E.NBrownianCandidates = sum(T.ClassificationCode == 1 & ...
    T.ClassificationSuccessful);
E.NUnclassifiedTrajectories = ...
    E.NTrajectories - E.NClassifiedTrajectories;
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
    E.MeanAvailableFeatures = NaN;
    E.BrownianCandidateFraction = NaN;
else
    E.EligibleFraction = E.NEligibleTrajectories / E.NTrajectories;
    E.MeanAvailableFeatures = mean(T.NAvailableFeatures);
    E.BrownianCandidateFraction = ...
        E.NBrownianCandidates / E.NTrajectories;
end
classifiedConfidence = ...
    T.ClassificationConfidence(T.ClassificationSuccessful);
classifiedD = T.DiffusionCoefficient(T.ClassificationSuccessful);
if isempty(classifiedConfidence)
    E.MeanClassificationConfidence = NaN;
    E.MeanClassifiedDiffusionCoefficient = NaN;
else
    E.MeanClassificationConfidence = mean(classifiedConfidence);
    E.MeanClassifiedDiffusionCoefficient = mean(classifiedD);
end

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end
