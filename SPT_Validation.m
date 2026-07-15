function Project = SPT_Validation(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Validation
%
% VB3 Companion Toolbox v4.1
%
% Validate Project consistency across:
%   Raw
%   Dataset
%   Geometry
%   Tables
%   Analysis
%   Figures
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Validation\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Config
%% --------------------------------------------------------

if nargin < 2 || isempty(Config)
    if isfield(Project, 'Config') && ~isempty(Project.Config)
        Config = Project.Config; %#ok<NASGU>
    else
        Config = struct(); %#ok<NASGU>
    end
end

%% --------------------------------------------------------
%% Ensure Validation struct
%% --------------------------------------------------------

if ~isfield(Project, 'Validation') || ~isstruct(Project.Validation)
    Project.Validation = struct();
end

issues = {};
checkNames = {};
checkValues = false(0,1);

%% --------------------------------------------------------
%% Raw
%% --------------------------------------------------------

[ok, msg] = checkRawLayer(Project);
Project.Validation.RawOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'RawOK', ok, msg);

%% --------------------------------------------------------
%% Dataset
%% --------------------------------------------------------

[ok, msg] = checkDatasetLayer(Project);
Project.Validation.DatasetOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'DatasetOK', ok, msg);

%% --------------------------------------------------------
%% Geometry
%% --------------------------------------------------------

[ok, msg] = checkGeometryLayer(Project);
Project.Validation.GeometryOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'GeometryOK', ok, msg);

%% --------------------------------------------------------
%% Localization table
%% --------------------------------------------------------

[ok, msg] = checkLocalizationLayer(Project);
Project.Validation.LocalizationOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'LocalizationOK', ok, msg);

%% --------------------------------------------------------
%% Segment table
%% --------------------------------------------------------

[ok, msg] = checkSegmentLayer(Project);
Project.Validation.SegmentOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'SegmentOK', ok, msg);

%% --------------------------------------------------------
%% Track table
%% --------------------------------------------------------

[ok, msg] = checkTrackLayer(Project);
Project.Validation.TrackOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'TrackOK', ok, msg);

%% --------------------------------------------------------
%% State table
%% --------------------------------------------------------

[ok, msg] = checkStateLayer(Project);
Project.Validation.StateOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'StateOK', ok, msg);

%% --------------------------------------------------------
%% Transition analysis
%% --------------------------------------------------------

[ok, msg] = checkTransitionLayer(Project);
Project.Validation.TransitionOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'TransitionOK', ok, msg);

%% --------------------------------------------------------
%% MSD
%% --------------------------------------------------------

[ok, msg] = checkMSDLayer(Project);
Project.Validation.MSDOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'MSDOK', ok, msg);

%% --------------------------------------------------------
%% Turning angle
%% --------------------------------------------------------

[ok, msg] = checkTurningAngleLayer(Project);
Project.Validation.TurningAngleOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'TurningAngleOK', ok, msg);

%% --------------------------------------------------------
%% Confinement
%% --------------------------------------------------------

[ok, msg] = checkConfinementLayer(Project);
Project.Validation.ConfinementOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'ConfinementOK', ok, msg);

%% --------------------------------------------------------
%% Figures
%% --------------------------------------------------------

[ok, msg] = checkFiguresLayer(Project);
Project.Validation.FiguresOK = ok;
[issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, 'FiguresOK', ok, msg);

%% --------------------------------------------------------
%% Overall result
%% --------------------------------------------------------

Project.Validation.Issues = issues;
Project.Validation.CheckNames = checkNames;
Project.Validation.CheckValues = checkValues;

Project.Validation.NIssues = numel(issues);
Project.Validation.OK = all(checkValues);

if Project.Validation.OK
    fprintf('Validation status     : OK\n');
else
    fprintf('Validation status     : FAILED (%d issues)\n', Project.Validation.NIssues);
end

fprintf('\n');

if ~isempty(issues)
    fprintf('Validation issues:\n');
    for i = 1:numel(issues)
        fprintf('  - %s\n', issues{i});
    end
    fprintf('\n');
end

fprintf('=====================================================\n');

end

% =====================================================================
function [issues, checkNames, checkValues] = appendCheck(issues, checkNames, checkValues, name, ok, msg)

checkNames{end+1,1} = name;
checkValues(end+1,1) = logical(ok);

if ~ok && ~isempty(msg)
    issues{end+1,1} = msg;
end

end

% =====================================================================
function [ok, msg] = checkRawLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Raw') || ~isstruct(Project.Raw)
    msg = 'Project.Raw is missing.';
    return;
end

R = Project.Raw;

req = {'finalTraj','memberTid','memberIdx','dt','nTraj'};
for i = 1:numel(req)
    if ~isfield(R, req{i})
        msg = ['Project.Raw.' req{i} ' is missing.'];
        return;
    end
end

if ~iscell(R.finalTraj)
    msg = 'Project.Raw.finalTraj must be a cell array.';
    return;
end

if ~isnumeric(R.memberTid) || ~isvector(R.memberTid)
    msg = 'Project.Raw.memberTid must be a numeric vector.';
    return;
end

if ~isnumeric(R.memberIdx) || ~isvector(R.memberIdx)
    msg = 'Project.Raw.memberIdx must be a numeric vector.';
    return;
end

if ~isnumeric(R.dt) || ~isscalar(R.dt) || ~isfinite(R.dt) || R.dt <= 0
    msg = 'Project.Raw.dt must be a positive scalar.';
    return;
end

if ~isnumeric(R.nTraj) || ~isscalar(R.nTraj) || R.nTraj < 0
    msg = 'Project.Raw.nTraj must be a nonnegative scalar.';
    return;
end

if numel(R.finalTraj) ~= R.nTraj
    msg = 'Project.Raw.nTraj does not match length(Project.Raw.finalTraj).';
    return;
end

if numel(R.memberTid) ~= R.nTraj
    msg = 'Project.Raw.memberTid length does not match Project.Raw.nTraj.';
    return;
end

if numel(R.memberIdx) ~= R.nTraj
    msg = 'Project.Raw.memberIdx length does not match Project.Raw.nTraj.';
    return;
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkDatasetLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Dataset') || ~isstruct(Project.Dataset)
    msg = 'Project.Dataset is missing.';
    return;
end

D = Project.Dataset;

req = {'nTraj','Trajectory','State','Posterior','Tid','RawIndex','Length','dt','Mapping','Metadata','Summary'};
for i = 1:numel(req)
    if ~isfield(D, req{i})
        msg = ['Project.Dataset.' req{i} ' is missing.'];
        return;
    end
end

if ~iscell(D.Trajectory)
    msg = 'Project.Dataset.Trajectory must be a cell array.';
    return;
end

if ~iscell(D.State)
    msg = 'Project.Dataset.State must be a cell array.';
    return;
end

if ~iscell(D.Posterior)
    msg = 'Project.Dataset.Posterior must be a cell array.';
    return;
end

if ~isnumeric(D.Tid) || ~isvector(D.Tid)
    msg = 'Project.Dataset.Tid must be a numeric vector.';
    return;
end

if ~isnumeric(D.RawIndex) || ~isvector(D.RawIndex)
    msg = 'Project.Dataset.RawIndex must be a numeric vector.';
    return;
end

if ~isnumeric(D.Length) || ~isvector(D.Length)
    msg = 'Project.Dataset.Length must be a numeric vector.';
    return;
end

if ~isnumeric(D.dt) || ~isscalar(D.dt) || ~isfinite(D.dt) || D.dt <= 0
    msg = 'Project.Dataset.dt must be a positive scalar.';
    return;
end

if ~isnumeric(D.nTraj) || ~isscalar(D.nTraj) || D.nTraj < 0
    msg = 'Project.Dataset.nTraj must be a nonnegative scalar.';
    return;
end

n = D.nTraj;

if numel(D.Trajectory) ~= n
    msg = 'Project.Dataset.nTraj does not match length(Project.Dataset.Trajectory).';
    return;
end

if numel(D.State) ~= n
    msg = 'Project.Dataset.nTraj does not match length(Project.Dataset.State).';
    return;
end

if numel(D.Posterior) ~= n
    msg = 'Project.Dataset.nTraj does not match length(Project.Dataset.Posterior).';
    return;
end

if numel(D.Tid) ~= n
    msg = 'Project.Dataset.Tid length does not match Project.Dataset.nTraj.';
    return;
end

if numel(D.RawIndex) ~= n
    msg = 'Project.Dataset.RawIndex length does not match Project.Dataset.nTraj.';
    return;
end

if numel(D.Length) ~= n
    msg = 'Project.Dataset.Length length does not match Project.Dataset.nTraj.';
    return;
end

if ~istable(D.Mapping)
    msg = 'Project.Dataset.Mapping must be a table.';
    return;
end

if height(D.Mapping) ~= n
    msg = 'Project.Dataset.Mapping height does not match Project.Dataset.nTraj.';
    return;
end

for i = 1:n
    trj = D.Trajectory{i};
    st = D.State{i};

    if isempty(trj) || isempty(st)
        continue;
    end

    if ~isnumeric(trj) || ~ismatrix(trj)
        msg = ['Project.Dataset.Trajectory{' num2str(i) '} must be a numeric matrix.'];
        return;
    end

    if ~isnumeric(st) || ~isvector(st)
        msg = ['Project.Dataset.State{' num2str(i) '} must be a numeric vector.'];
        return;
    end

    if size(trj,2) < 2
        msg = ['Project.Dataset.Trajectory{' num2str(i) '} must have at least 2 columns.'];
        return;
    end
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkGeometryLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Geometry') || ~isstruct(Project.Geometry)
    msg = 'Project.Geometry is missing.';
    return;
end

G = Project.Geometry;

req = {'X','Y','DX','DY','StepLength','Direction','Velocity','Acceleration','Time','CentroidX','CentroidY','NetDisplacement','CumulativeDistance','TrackLength','NSteps','Summary'};
for i = 1:numel(req)
    if ~isfield(G, req{i})
        msg = ['Project.Geometry.' req{i} ' is missing.'];
        return;
    end
end

if ~isfield(Project, 'Dataset') || ~isfield(Project.Dataset, 'nTraj')
    msg = 'Cannot validate Geometry without Project.Dataset.nTraj.';
    return;
end

n = Project.Dataset.nTraj;

cellFields = {'X','Y','DX','DY','StepLength','Direction','Velocity','Acceleration','Time'};
for i = 1:numel(cellFields)
    f = cellFields{i};
    if ~iscell(G.(f)) || numel(G.(f)) ~= n
        msg = ['Project.Geometry.' f ' must be a cell array of length nTraj.'];
        return;
    end
end

vecFields = {'CentroidX','CentroidY','NetDisplacement','CumulativeDistance','TrackLength','NSteps'};
for i = 1:numel(vecFields)
    f = vecFields{i};
    if ~isnumeric(G.(f)) || numel(G.(f)) ~= n
        msg = ['Project.Geometry.' f ' must be a numeric vector of length nTraj.'];
        return;
    end
end

for i = 1:n
    x = G.X{i};
    y = G.Y{i};
    dx = G.DX{i};
    dy = G.DY{i};
    step = G.StepLength{i};
    dirDeg = G.Direction{i};
    vel = G.Velocity{i};
    acc = G.Acceleration{i};
    t = G.Time{i};

    if isempty(x) || isempty(y)
        continue;
    end

    if numel(x) ~= numel(y)
        msg = ['Project.Geometry.X and Y lengths do not match for trajectory ' num2str(i) '.'];
        return;
    end

    if numel(x) < 2
        if ~isempty(dx) || ~isempty(dy) || ~isempty(step) || ~isempty(dirDeg) || ~isempty(vel) || ~isempty(acc)
            msg = ['Project.Geometry fields should be empty for short trajectory ' num2str(i) '.'];
            return;
        end
        continue;
    end

    if numel(dx) ~= numel(x)-1 || numel(dy) ~= numel(x)-1
        msg = ['Project.Geometry.DX/DY size mismatch for trajectory ' num2str(i) '.'];
        return;
    end

    if numel(step) ~= numel(x)-1 || numel(dirDeg) ~= numel(x)-1 || numel(vel) ~= numel(x)-1
        msg = ['Project.Geometry step/direction/velocity size mismatch for trajectory ' num2str(i) '.'];
        return;
    end

    if ~isempty(acc) && numel(acc) ~= max(numel(x)-2, 0)
        msg = ['Project.Geometry.Acceleration size mismatch for trajectory ' num2str(i) '.'];
        return;
    end

    if numel(t) ~= numel(x)
        msg = ['Project.Geometry.Time size mismatch for trajectory ' num2str(i) '.'];
        return;
    end
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkLocalizationLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables) || ~isfield(Project.Tables, 'Localization')
    msg = 'Project.Tables.Localization is missing.';
    return;
end

L = Project.Tables.Localization;

if ~istable(L)
    msg = 'Project.Tables.Localization must be a table.';
    return;
end

req = {'DatasetIndex','RawIndex','Tid','Frame','Time','X','Y','State'};
for i = 1:numel(req)
    if ~ismember(req{i}, L.Properties.VariableNames)
        msg = ['Localization table missing column: ' req{i}];
        return;
    end
end

if ~isfield(Project, 'Dataset') || ~isfield(Project.Dataset, 'nTraj')
    msg = 'Cannot validate Localization without Project.Dataset.nTraj.';
    return;
end

if height(L) < 1
    msg = 'Localization table is empty.';
    return;
end

nStates = inferNStates(Project);
for k = 1:nStates
    v = ['pState' num2str(k)];
    if ~ismember(v, L.Properties.VariableNames)
        msg = ['Localization table missing posterior column: ' v];
        return;
    end
end

if any(L.DatasetIndex < 1) || any(L.DatasetIndex > Project.Dataset.nTraj)
    msg = 'Localization table DatasetIndex contains out-of-range values.';
    return;
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkSegmentLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables) || ~isfield(Project.Tables, 'Segment')
    msg = 'Project.Tables.Segment is missing.';
    return;
end

S = Project.Tables.Segment;

if ~istable(S)
    msg = 'Project.Tables.Segment must be a table.';
    return;
end

req = {'DatasetIndex','RawIndex','Tid','SegmentID','State','StartFrame','EndFrame','NPoints','Duration_s'};
for i = 1:numel(req)
    if ~ismember(req{i}, S.Properties.VariableNames)
        msg = ['Segment table missing column: ' req{i}];
        return;
    end
end

nStates = inferNStates(Project);
for k = 1:nStates
    v = ['meanPState' num2str(k)];
    if ~ismember(v, S.Properties.VariableNames)
        msg = ['Segment table missing posterior-mean column: ' v];
        return;
    end
end

if ~isempty(S)
    if any(S.EndFrame < S.StartFrame)
        msg = 'Segment table has EndFrame < StartFrame in at least one row.';
        return;
    end

    if any(S.NPoints ~= (S.EndFrame - S.StartFrame + 1))
        msg = 'Segment table NPoints is inconsistent with StartFrame/EndFrame.';
        return;
    end
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkTrackLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables) || ~isfield(Project.Tables, 'Track')
    msg = 'Project.Tables.Track is missing.';
    return;
end

T = Project.Tables.Track;

if ~istable(T)
    msg = 'Project.Tables.Track must be a table.';
    return;
end

req = {'DatasetIndex','RawIndex','Tid','NPoints','Length','Duration_s','NStates','DominantState','NSwitches'};
for i = 1:numel(req)
    if ~ismember(req{i}, T.Properties.VariableNames)
        msg = ['Track table missing column: ' req{i}];
        return;
    end
end

nStates = inferNStates(Project);
for k = 1:nStates
    v = ['state' num2str(k) '_fraction'];
    if ~ismember(v, T.Properties.VariableNames)
        msg = ['Track table missing state fraction column: ' v];
        return;
    end
end

if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'nTraj')
    if height(T) ~= Project.Dataset.nTraj
        msg = 'Track table row count does not match dataset trajectory count.';
        return;
    end
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkStateLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables) || ~isfield(Project.Tables, 'State')
    msg = 'Project.Tables.State is missing.';
    return;
end

T = Project.Tables.State;

if ~istable(T)
    msg = 'Project.Tables.State must be a table.';
    return;
end

req = {'State','nPoints','fractionOfPoints','nSegments','fractionOfSegments','nTracks','fractionOfTracks','meanDwell_s','medianDwell_s'};
for i = 1:numel(req)
    if ~ismember(req{i}, T.Properties.VariableNames)
        msg = ['State table missing column: ' req{i}];
        return;
    end
end

nStates = inferNStates(Project);
if height(T) ~= nStates
    msg = 'State table row count does not match number of states.';
    return;
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkTransitionLayer(Project)

ok = false;
msg = '';

if ~isfield(Project, 'Analysis') || ~isstruct(Project.Analysis) || ~isfield(Project.Analysis, 'Transition')
    msg = 'Project.Analysis.Transition is missing.';
    return;
end

TR = Project.Analysis.Transition;

req = {'CountMatrix','ProbMatrix','CountTable','ProbTable','nTotalTransitions','nStates'};
for i = 1:numel(req)
    if ~isfield(TR, req{i})
        msg = ['Transition analysis missing field: ' req{i}];
        return;
    end
end

if ~isnumeric(TR.CountMatrix) || ~isnumeric(TR.ProbMatrix)
    msg = 'Transition matrices must be numeric.';
    return;
end

if size(TR.CountMatrix,1) ~= size(TR.CountMatrix,2)
    msg = 'Transition CountMatrix must be square.';
    return;
end

if size(TR.ProbMatrix,1) ~= size(TR.ProbMatrix,2)
    msg = 'Transition ProbMatrix must be square.';
    return;
end

if size(TR.CountMatrix,1) ~= TR.nStates || size(TR.ProbMatrix,1) ~= TR.nStates
    msg = 'Transition matrix dimensions do not match nStates.';
    return;
end

ok = true;

end

% =====================================================================
function [ok, msg] = checkMSDLayer(Project)

ok = true;
msg = '';

if ~isfield(Project, 'Analysis') || ~isstruct(Project.Analysis) || ~isfield(Project.Analysis, 'MSD')
    msg = 'Project.Analysis.MSD is missing.';
    ok = false;
    return;
end

MSD = Project.Analysis.MSD;

if ~isstruct(MSD)
    msg = 'Project.Analysis.MSD must be a struct.';
    ok = false;
    return;
end

if isfield(MSD, 'Ensemble')
    E = MSD.Ensemble;
    req = {'Lag','Time_s','PooledMSD'};
    for i = 1:numel(req)
        if ~isfield(E, req{i})
            msg = ['MSD ensemble missing field: ' req{i}];
            ok = false;
            return;
        end
    end
end

end

% =====================================================================
function [ok, msg] = checkTurningAngleLayer(Project)

ok = true;
msg = '';

if ~isfield(Project, 'Analysis') || ~isstruct(Project.Analysis) || ~isfield(Project.Analysis, 'TurningAngle')
    msg = 'Project.Analysis.TurningAngle is missing.';
    ok = false;
    return;
end

TA = Project.Analysis.TurningAngle;

if ~isstruct(TA)
    msg = 'Project.Analysis.TurningAngle must be a struct.';
    ok = false;
    return;
end

if isfield(TA, 'Ensemble')
    E = TA.Ensemble;
    req = {'nAngles','HistogramCounts','HistogramEdges'};
    for i = 1:numel(req)
        if ~isfield(E, req{i})
            msg = ['TurningAngle ensemble missing field: ' req{i}];
            ok = false;
            return;
        end
    end
end

if isfield(TA, 'Table')
    if ~istable(TA.Table)
        msg = 'Project.Analysis.TurningAngle.Table must be a table.';
        ok = false;
        return;
    end
end

end

% =====================================================================
function [ok, msg] = checkConfinementLayer(Project)

ok = true;
msg = '';

if ~isfield(Project, 'Analysis') || ~isstruct(Project.Analysis) || ~isfield(Project.Analysis, 'Confinement')
    msg = 'Project.Analysis.Confinement is missing.';
    ok = false;
    return;
end

CA = Project.Analysis.Confinement;

if ~isstruct(CA)
    msg = 'Project.Analysis.Confinement must be a struct.';
    ok = false;
    return;
end

if isfield(CA, 'Table')
    if ~istable(CA.Table)
        msg = 'Project.Analysis.Confinement.Table must be a table.';
        ok = false;
        return;
    end
end

if isfield(CA, 'Ensemble')
    E = CA.Ensemble;
    req = {'nTraj','nStates','MeanRadiusOfGyration','MeanConvexHullArea','MeanPackingCoefficient','MeanConfinementRatio'};
    for i = 1:numel(req)
        if ~isfield(E, req{i})
            msg = ['Confinement ensemble missing field: ' req{i}];
            ok = false;
            return;
        end
    end
end

end

% =====================================================================
function [ok, msg] = checkFiguresLayer(Project)

ok = true;
msg = '';

if ~isfield(Project, 'Figures') || ~isstruct(Project.Figures)
    msg = 'Project.Figures is missing.';
    ok = false;
    return;
end

end

% =====================================================================
% =====================================================================
function nStates = inferNStates(Project)

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && ...
        isnumeric(Project.HMM.nStates) && isscalar(Project.HMM.nStates) && ...
        isfinite(Project.HMM.nStates) && Project.HMM.nStates >= 1
    nStates = Project.HMM.nStates;
    return;
end

if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'State') && iscell(Project.Dataset.State)
    allStates = [];
    for i = 1:numel(Project.Dataset.State)
        if isempty(Project.Dataset.State{i})
            continue
        end
        allStates = [allStates; Project.Dataset.State{i}(:)]; %#ok<AGROW>
    end
    if isempty(allStates)
        nStates = 1;
    else
        nStates = max(allStates);
    end
else
    nStates = 1;
end

end