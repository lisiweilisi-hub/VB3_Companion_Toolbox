function Project = SPT_Kinematics_Trajectory(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_Trajectory
%
% Build trajectory-resolved kinematics from the Step analysis.
%
% Input
%   Project.Analysis.Kinematics.Step
%
% Output
%   Project.Analysis.Kinematics.Trajectory
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_Trajectory:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for interface consistency with the other SPT analysis modules.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Analysis') || ...
        ~isstruct(Project.Analysis) || ~isscalar(Project.Analysis) || ...
        ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics) || ...
        ~isfield(Project.Analysis.Kinematics, 'Step')
    error('SPT_Kinematics_Trajectory:MissingStep', ...
        'Project.Analysis.Kinematics.Step not found.');
end

Step = Project.Analysis.Kinematics.Step;
if ~isstruct(Step) || ~isscalar(Step) || ...
        ~isfield(Step, 'ByTrack') || ~isfield(Step, 'Table')
    error('SPT_Kinematics_Trajectory:InvalidStep', ...
        'Step must be a scalar structure containing Table and ByTrack.');
end

StepByTrack = Step.ByTrack;
if ~istable(StepByTrack)
    error('SPT_Kinematics_Trajectory:InvalidByTrack', ...
        'Step.ByTrack must be a table.');
end

StepTable = Step.Table;
if ~istable(StepTable)
    error('SPT_Kinematics_Trajectory:InvalidStepTable', ...
        'Step.Table must be a table.');
end

required = {'DatasetIndex','RawIndex','Tid','NSteps','NFiniteSteps', ...
    'TotalDistance','MeanStepLength','MedianStepLength','MeanSpeed', ...
    'MedianSpeed','MeanAcceleration'};
validateByTrack(StepByTrack, required);

requiredStepColumns = {'DatasetIndex','StartFrame','EndFrame', ...
    'StartTime','EndTime','DeltaTime','StepLength'};
validateStepTable(StepTable, requiredStepColumns);

[ByTrack, sortedInternally] = normalizeByTrack(StepByTrack);
[ByTrack, stepCountsMatch] = addCoreCalculations(ByTrack, StepTable);
Ensemble = summarizeEnsemble(ByTrack);

Summary = struct();
Summary.nTrajectories = height(ByTrack);
Summary.nTrajectoriesWithSteps = Ensemble.NTrajectoriesWithSteps;
Summary.nSteps = Ensemble.NSteps;
Summary.nFiniteSteps = Ensemble.NFiniteSteps;
Summary.TotalDistance = Ensemble.TotalDistance;
Summary.MeanTrajectoryDistance = Ensemble.MeanTrajectoryDistance;
Summary.TotalDuration = Ensemble.TotalDuration;
Summary.MeanTrajectoryDuration = Ensemble.MeanTrajectoryDuration;
Summary.MeanPathSpeed = Ensemble.MeanPathSpeed;
Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.RequiredColumns = required;
Validation.Source = 'Project.Analysis.Kinematics.Step';
Validation.RequiredStepColumns = requiredStepColumns;
Validation.TrajectorySource = 'Step.ByTrack and Step.Table';
Validation.NInputRows = height(StepByTrack);
Validation.NTrajectoryRows = height(ByTrack);
Validation.SortedInternally = sortedInternally;
Validation.NStepRows = height(StepTable);
if sourceValidationFailed(Step)
    Validation = addIssue(Validation, ...
        'Source Step validation failed.');
end

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

if ~stepCountsMatch
    Validation = addIssue(Validation, ...
        'Step.Table row counts must match Step.ByTrack.NSteps.');
end
if any(~isfinite(StepTable.DeltaTime) | StepTable.DeltaTime <= 0)
    Validation = addIssue(Validation, ...
        'Every source step must have a positive finite time interval.');
end

if any(ByTrack.NSteps > 0 & ...
        (~isfinite(ByTrack.Duration) | ByTrack.Duration <= 0))
    Validation = addIssue(Validation, ...
        'Trajectory duration must be positive and finite when steps are present.');
end

Trajectory = struct();
Trajectory.ByTrack = ByTrack;
Trajectory.Ensemble = Ensemble;
Trajectory.Summary = Summary;
Trajectory.Validation = Validation;

Project.Analysis.Kinematics.Trajectory = Trajectory;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Trajectory\n');
fprintf('=====================================================\n');
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Step rows         : %d\n', Summary.nSteps);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function tf = sourceValidationFailed(Step)

tf = false;
if ~isfield(Step, 'Validation')
    return
end

V = Step.Validation;
if ~isstruct(V) || ~isscalar(V) || ~isfield(V, 'OK') || ...
        ~isscalar(V.OK) || ...
        ~(islogical(V.OK) || (isnumeric(V.OK) && isreal(V.OK)))
    tf = true;
    return
end

tf = ~logical(V.OK);

end

% =====================================================================
function validateByTrack(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_Trajectory:MissingColumn', ...
            'Step.ByTrack missing column: %s', name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_Trajectory:InvalidColumn', ...
            'Step.ByTrack column %s must be a real numeric vector.', name);
    end
end

end

% =====================================================================
function validateStepTable(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_Trajectory:MissingStepColumn', ...
            'Step.Table missing column: %s', name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_Trajectory:InvalidStepColumn', ...
            'Step.Table column %s must be a real numeric vector.', name);
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
function [T, countsMatch] = addCoreCalculations(T, S)

n = height(T);
T.StartFrame = nan(n, 1);
T.EndFrame = nan(n, 1);
T.StartTime = nan(n, 1);
T.EndTime = nan(n, 1);
T.Duration = nan(n, 1);
T.PathMeanSpeed = nan(n, 1);
countsMatch = height(S) == sum(T.NSteps);

for i = 1:n
    rows = find(S.DatasetIndex == T.DatasetIndex(i));
    countsMatch = countsMatch && numel(rows) == T.NSteps(i);
    if isempty(rows)
        continue
    end

    [~, order] = sort(S.StartFrame(rows));
    rows = rows(order);
    T.StartFrame(i) = S.StartFrame(rows(1));
    T.EndFrame(i) = S.EndFrame(rows(end));
    T.StartTime(i) = S.StartTime(rows(1));
    T.EndTime(i) = S.EndTime(rows(end));

    deltaTime = S.DeltaTime(rows);
    validTime = isfinite(deltaTime) & deltaTime > 0;
    T.Duration(i) = sum(deltaTime(validTime));
    if T.Duration(i) > 0 && isfinite(T.TotalDistance(i))
        T.PathMeanSpeed(i) = T.TotalDistance(i) / T.Duration(i);
    end
end

end

% =====================================================================
function E = summarizeEnsemble(T)

E = struct();
E.NTrajectories = height(T);
E.NTrajectoriesWithSteps = sum(T.NSteps > 0);
E.NSteps = sum(T.NSteps);
E.NFiniteSteps = sum(T.NFiniteSteps);
E.TotalDistance = sumIgnoringNaN(T.TotalDistance);
E.MeanTrajectoryDistance = meanIgnoringNaN(T.TotalDistance);
E.MedianTrajectoryDistance = medianIgnoringNaN(T.TotalDistance);
E.MeanStepLength = meanIgnoringNaN(T.MeanStepLength);
E.MeanSpeed = meanIgnoringNaN(T.MeanSpeed);
E.MeanAcceleration = meanIgnoringNaN(T.MeanAcceleration);
E.TotalDuration = sumIgnoringNaN(T.Duration);
E.MeanTrajectoryDuration = meanIgnoringNaN(T.Duration);
E.MedianTrajectoryDuration = medianIgnoringNaN(T.Duration);
E.MeanPathSpeed = meanIgnoringNaN(T.PathMeanSpeed);

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end


% =====================================================================
function y = sumIgnoringNaN(x)

x = x(:);
x = x(~isnan(x));
if isempty(x)
    y = 0;
else
    y = sum(x);
end

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
function y = medianIgnoringNaN(x)

x = x(:);
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = median(x);
end

end
