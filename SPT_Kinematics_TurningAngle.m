function Project = SPT_Kinematics_TurningAngle(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_TurningAngle
%
% Initialize turning-angle analysis from trajectory-resolved kinematics.
%
% Input
%   Project.Analysis.Kinematics.Trajectory.ByTrack
%
% Output
%   Project.Analysis.Kinematics.TurningAngle
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_TurningAngle:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for future turning-angle configuration.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Analysis') || ...
        ~isstruct(Project.Analysis) || ~isscalar(Project.Analysis) || ...
        ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics) || ...
        ~isfield(Project.Analysis.Kinematics, 'Trajectory') || ...
        ~isstruct(Project.Analysis.Kinematics.Trajectory) || ...
        ~isscalar(Project.Analysis.Kinematics.Trajectory) || ...
        ~isfield(Project.Analysis.Kinematics.Trajectory, 'ByTrack')
    error('SPT_Kinematics_TurningAngle:MissingTrajectory', ...
        'Project.Analysis.Kinematics.Trajectory.ByTrack not found.');
end

TrajectoryByTrack = Project.Analysis.Kinematics.Trajectory.ByTrack;
if ~istable(TrajectoryByTrack)
    error('SPT_Kinematics_TurningAngle:InvalidByTrack', ...
        'Trajectory.ByTrack must be a table.');
end

required = {'DatasetIndex','RawIndex','Tid','NSteps','NFiniteSteps'};
validateByTrack(TrajectoryByTrack, required);

[ByTrack, sortedInternally] = normalizeByTrack(TrajectoryByTrack);
[ByTrack, angleCountsConsistent] = addCoreCalculations(ByTrack);
Ensemble = summarizeEnsemble(ByTrack);

Summary = struct();
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nTrajectoriesWithSteps = Ensemble.NTrajectoriesWithSteps;
Summary.nTrajectoriesWithPotentialAngles = ...
    Ensemble.NTrajectoriesWithPotentialAngles;
Summary.nSteps = Ensemble.NSteps;
Summary.nFiniteSteps = Ensemble.NFiniteSteps;
Summary.nPotentialAngles = Ensemble.NPotentialAngles;
Summary.nPotentialFiniteAngles = Ensemble.NPotentialFiniteAngles;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.MeanFiniteAngleFractionUpperBound = ...
    Ensemble.MeanFiniteAngleFractionUpperBound;

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.RequiredColumns = required;
Validation.Source = ...
    'Project.Analysis.Kinematics.Trajectory.ByTrack';
Validation.NInputRows = height(TrajectoryByTrack);
Validation.NTrajectoryRows = height(ByTrack);
Validation.SortedInternally = sortedInternally;

if any(~isfinite(ByTrack.DatasetIndex)) || ...
        any(ByTrack.DatasetIndex ~= floor(ByTrack.DatasetIndex))
    Validation = addIssue(Validation, ...
        'DatasetIndex must contain finite integer values.');
end
if numel(unique(ByTrack.DatasetIndex)) ~= height(ByTrack)
    Validation = addIssue(Validation, ...
        'DatasetIndex must be unique for each trajectory.');
end
if any(~isfinite(ByTrack.NSteps)) || any(ByTrack.NSteps < 0) || ...
        any(ByTrack.NSteps ~= floor(ByTrack.NSteps)) || ...
        any(~isfinite(ByTrack.NFiniteSteps)) || ...
        any(ByTrack.NFiniteSteps < 0) || ...
        any(ByTrack.NFiniteSteps ~= floor(ByTrack.NFiniteSteps)) || ...
        any(ByTrack.NFiniteSteps > ByTrack.NSteps)
    Validation = addIssue(Validation, ...
        'Step counts must be nonnegative integers with finite counts not exceeding total counts.');
end
if ~angleCountsConsistent
    Validation = addIssue(Validation, ...
        'Potential finite angle counts must not exceed potential angle counts.');
end

TurningAngle = struct();
TurningAngle.ByTrack = ByTrack;
TurningAngle.Ensemble = Ensemble;
TurningAngle.Summary = Summary;
TurningAngle.Validation = Validation;

Project.Analysis.Kinematics.TurningAngle = TurningAngle;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Turning Angle\n');
fprintf('=====================================================\n');
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Potential angles  : %d\n', Summary.nPotentialAngles);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateByTrack(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_TurningAngle:MissingColumn', ...
            'Trajectory.ByTrack missing column: %s', name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_TurningAngle:InvalidColumn', ...
            'Trajectory.ByTrack column %s must be a real numeric vector.', ...
            name);
    end
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
% =====================================================================
function [T, countsConsistent] = addCoreCalculations(T)

potentialAngles = T.NSteps - 1;
potentialAngles(potentialAngles < 0) = 0;
potentialFiniteAngles = T.NFiniteSteps - 1;
potentialFiniteAngles(potentialFiniteAngles < 0) = 0;

T.NPotentialAngles = potentialAngles;
T.NPotentialFiniteAngles = potentialFiniteAngles;
T.FiniteAngleFractionUpperBound = nan(height(T), 1);
hasPotentialAngles = potentialAngles > 0;
T.FiniteAngleFractionUpperBound(hasPotentialAngles) = ...
    potentialFiniteAngles(hasPotentialAngles) ./ ...
    potentialAngles(hasPotentialAngles);

validCounts = isfinite(T.NSteps) & T.NSteps >= 0 & ...
    T.NSteps == floor(T.NSteps) & isfinite(T.NFiniteSteps) & ...
    T.NFiniteSteps >= 0 & T.NFiniteSteps == floor(T.NFiniteSteps) & ...
    T.NFiniteSteps <= T.NSteps;
validIdentifier = isfinite(T.DatasetIndex) & ...
    T.DatasetIndex == floor(T.DatasetIndex);
uniqueIdentifier = false(height(T), 1);
for i = 1:height(T)
    if validIdentifier(i)
        uniqueIdentifier(i) = ...
            sum(T.DatasetIndex == T.DatasetIndex(i)) == 1;
    end
end
T.TurningAngleEligible = validIdentifier & uniqueIdentifier & ...
    validCounts & potentialFiniteAngles > 0;

countsConsistent = all(potentialFiniteAngles <= potentialAngles);

end

% =====================================================================
function E = summarizeEnsemble(T)

E = struct();
E.NTrajectories = height(T);
E.NTrajectoriesWithSteps = sum(T.NSteps > 0);
E.NTrajectoriesWithPotentialAngles = sum(T.NPotentialAngles > 0);
E.NSteps = sum(T.NSteps);
E.NFiniteSteps = sum(T.NFiniteSteps);
E.NPotentialAngles = sum(T.NPotentialAngles);
E.NPotentialFiniteAngles = sum(T.NPotentialFiniteAngles);
E.NEligibleTrajectories = sum(T.TurningAngleEligible);
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
else
    E.EligibleFraction = E.NEligibleTrajectories / E.NTrajectories;
end
E.MeanFiniteAngleFractionUpperBound = ...
    meanIgnoringNaN(T.FiniteAngleFractionUpperBound);

end

% =====================================================================
function y = meanIgnoringNaN(x)

x = x(:);
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = mean(x);
end

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end
