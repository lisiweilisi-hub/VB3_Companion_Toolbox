function Project = SPT_Kinematics_Confinement(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_Confinement
%
% Initialize confinement analysis from trajectory-resolved kinematics.
%
% Input
%   Project.Analysis.Kinematics.Trajectory.ByTrack
%
% Output
%   Project.Analysis.Kinematics.Confinement
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_Confinement:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for future confinement configuration.
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
    error('SPT_Kinematics_Confinement:MissingTrajectory', ...
        'Project.Analysis.Kinematics.Trajectory.ByTrack not found.');
end

TrajectoryByTrack = Project.Analysis.Kinematics.Trajectory.ByTrack;
if ~istable(TrajectoryByTrack)
    error('SPT_Kinematics_Confinement:InvalidByTrack', ...
        'Trajectory.ByTrack must be a table.');
end

required = {'DatasetIndex','RawIndex','Tid','NSteps','NFiniteSteps', ...
    'TotalDistance','Duration','PathMeanSpeed'};
validateByTrack(TrajectoryByTrack, required);

[ByTrack, sortedInternally] = normalizeByTrack(TrajectoryByTrack);
[ByTrack, ratesConsistent] = addCoreCalculations(ByTrack);
Ensemble = summarizeEnsemble(ByTrack);

Summary = struct();
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nTrajectoriesWithSteps = Ensemble.NTrajectoriesWithSteps;
Summary.nSteps = Ensemble.NSteps;
Summary.nFiniteSteps = Ensemble.NFiniteSteps;
Summary.TotalDistance = Ensemble.TotalDistance;
Summary.TotalDuration = Ensemble.TotalDuration;
Summary.MeanPathSpeed = Ensemble.MeanPathSpeed;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.MeanFiniteStepFraction = Ensemble.MeanFiniteStepFraction;
Summary.MeanStepDuration = Ensemble.MeanStepDuration;
Summary.MeanDistanceRate = Ensemble.MeanDistanceRate;

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
if any(~isfinite(ByTrack.TotalDistance) | ByTrack.TotalDistance < 0)
    Validation = addIssue(Validation, ...
        'TotalDistance must contain finite nonnegative values.');
end
hasSteps = ByTrack.NSteps > 0;
if any(hasSteps & (~isfinite(ByTrack.Duration) | ByTrack.Duration <= 0))
    Validation = addIssue(Validation, ...
        'Duration must be positive and finite when steps are present.');
end
if any(hasSteps & ...
        (~isfinite(ByTrack.PathMeanSpeed) | ByTrack.PathMeanSpeed < 0))
    Validation = addIssue(Validation, ...
        'PathMeanSpeed must be finite and nonnegative when steps are present.');
end

if ~ratesConsistent
    Validation = addIssue(Validation, ...
        'PathMeanSpeed must agree with TotalDistance divided by Duration.');
end

Confinement = struct();
Confinement.ByTrack = ByTrack;
Confinement.Ensemble = Ensemble;
Confinement.Summary = Summary;
Confinement.Validation = Validation;

Project.Analysis.Kinematics.Confinement = Confinement;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Confinement\n');
fprintf('=====================================================\n');
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateByTrack(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_Confinement:MissingColumn', ...
            'Trajectory.ByTrack missing column: %s', name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_Confinement:InvalidColumn', ...
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
function [T, ratesConsistent] = addCoreCalculations(T)

n = height(T);
T.FiniteStepFraction = nan(n, 1);
T.MeanStepDuration = nan(n, 1);
T.DistanceRate = nan(n, 1);
T.ConfinementEligible = false(n, 1);

hasSteps = T.NSteps > 0;
validDuration = hasSteps & isfinite(T.Duration) & T.Duration > 0;
T.FiniteStepFraction(hasSteps) = ...
    T.NFiniteSteps(hasSteps) ./ T.NSteps(hasSteps);
T.MeanStepDuration(validDuration) = ...
    T.Duration(validDuration) ./ T.NSteps(validDuration);
T.DistanceRate(validDuration) = ...
    T.TotalDistance(validDuration) ./ T.Duration(validDuration);

validRate = validDuration & isfinite(T.TotalDistance) & ...
    isfinite(T.PathMeanSpeed);
rateConsistent = false(n, 1);
if any(validRate)
    difference = abs(T.DistanceRate(validRate) - T.PathMeanSpeed(validRate));
    scale = max(1, abs(T.PathMeanSpeed(validRate)));
    rateConsistent(validRate) = difference <= 1e-12 .* scale;
end

ratesConsistent = all(rateConsistent(hasSteps));

validCounts = isfinite(T.NSteps) & T.NSteps >= 0 & ...
    T.NSteps == floor(T.NSteps) & isfinite(T.NFiniteSteps) & ...
    T.NFiniteSteps >= 0 & T.NFiniteSteps == floor(T.NFiniteSteps) & ...
    T.NFiniteSteps <= T.NSteps;

T.ConfinementEligible = validCounts & T.NSteps >= 2 & ...
    T.NFiniteSteps == T.NSteps & validDuration & ...
    isfinite(T.TotalDistance) & T.TotalDistance > 0 & ...
    isfinite(T.PathMeanSpeed) & T.PathMeanSpeed >= 0 & rateConsistent;

end
% =====================================================================

function E = summarizeEnsemble(T)

E = struct();
E.NTrajectories = height(T);
E.NTrajectoriesWithSteps = sum(T.NSteps > 0);
E.NSteps = sum(T.NSteps);
E.NFiniteSteps = sum(T.NFiniteSteps);
E.TotalDistance = sum(T.TotalDistance);
E.TotalDuration = sum(T.Duration(T.NSteps > 0));
E.MeanPathSpeed = meanIgnoringNaN(T.PathMeanSpeed(T.NSteps > 0));
E.NEligibleTrajectories = sum(T.ConfinementEligible);
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
else
    E.EligibleFraction = E.NEligibleTrajectories / E.NTrajectories;
end
E.MeanFiniteStepFraction = meanIgnoringNaN(T.FiniteStepFraction);
E.MeanStepDuration = meanIgnoringNaN(T.MeanStepDuration);
E.MeanDistanceRate = meanIgnoringNaN(T.DistanceRate);

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

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
