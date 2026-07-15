function Project = SPT_Confinement(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Confinement
%
% VB3 Companion Toolbox v4.1 / v4.1.1
%
% Time-resolved local confinement analysis.
%
% Input
%   Project.Dataset
%   Project.Geometry (optional)
%
% Output
%   Project.Analysis.Confinement
%
% Main outputs
%   - PerTrajectory: per-trajectory local confinement profiles
%   - Table        : per-trajectory summary table (backward-compatible)
%   - WindowTable   : per-window table (time-resolved)
%   - Ensemble     : global window-level summary
%   - ByState      : state-resolved summary
%
% MATLAB R2016b compatible
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Confinement v2\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

if nargin < 2 || isempty(Config)
    if isfield(Project, 'Config') && ~isempty(Project.Config)
        Config = Project.Config;
    else
        Config = struct();
    end
end

if ~isfield(Project, 'Flags') || ~isfield(Project.Flags, 'Dataset') || ~Project.Flags.Dataset
    error('Dataset has not been created.');
end

if ~isfield(Project, 'Validation') || ...
        ~isfield(Project.Validation, 'DatasetOK') || ...
        ~Project.Validation.DatasetOK
    error('Dataset validation failed.');
end

if ~isfield(Project, 'Dataset') || isempty(Project.Dataset.Trajectory)
    error('Project.Dataset is empty.');
end

if ~isfield(Project.Dataset, 'State') || isempty(Project.Dataset.State)
    error('Project.Dataset.State not found.');
end

%% --------------------------------------------------------
%% Configuration
%% --------------------------------------------------------

if ~isfield(Config, 'Confinement') || ~isstruct(Config.Confinement)
    Config.Confinement = struct();
end

if ~isfield(Config.Confinement, 'Window') || isempty(Config.Confinement.Window)
    Config.Confinement.Window = 20;
end

if ~isfield(Config.Confinement, 'MinPoints') || isempty(Config.Confinement.MinPoints)
    Config.Confinement.MinPoints = 10;
end

if ~isfield(Config.Confinement, 'Stride') || isempty(Config.Confinement.Stride)
    Config.Confinement.Stride = 1;
end

if ~isfield(Config.Confinement, 'UseDominantState') || isempty(Config.Confinement.UseDominantState)
    Config.Confinement.UseDominantState = true;
end

if ~isfield(Config.Confinement, 'ComputeWindowTable') || isempty(Config.Confinement.ComputeWindowTable)
    Config.Confinement.ComputeWindowTable = true;
end

if ~isfield(Config.Confinement, 'ComputePerTrajectoryProfiles') || isempty(Config.Confinement.ComputePerTrajectoryProfiles)
    Config.Confinement.ComputePerTrajectoryProfiles = true;
end

winSize = Config.Confinement.Window;
minPoints = Config.Confinement.MinPoints;
stride = Config.Confinement.Stride;

if ~isnumeric(winSize) || ~isscalar(winSize) || winSize < 2
    error('Config.Confinement.Window must be a scalar >= 2.');
end

if ~isnumeric(minPoints) || ~isscalar(minPoints) || minPoints < 2
    error('Config.Confinement.MinPoints must be a scalar >= 2.');
end

if ~isnumeric(stride) || ~isscalar(stride) || stride < 1
    error('Config.Confinement.Stride must be a scalar >= 1.');
end

winSize = round(winSize);
minPoints = round(minPoints);
stride = round(stride);

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;
dt = Dataset.dt;

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = inferNStatesFromStateCell(Dataset.State);
end

%% --------------------------------------------------------
%% Initialize
%% --------------------------------------------------------

CA = struct();
CA.Config = Config.Confinement;
CA.PerTrajectory = cell(nTraj, 1);
CA.Table = table();         % backward-compatible trajectory summary table
CA.WindowTable = table();    % time-resolved sliding-window table
CA.Ensemble = struct();
CA.ByState = struct();
CA.Summary = struct();

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Window size            : %d points\n', winSize);
fprintf('Min points             : %d points\n', minPoints);
fprintf('Stride                 : %d points\n', stride);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building confinement analysis ...\n');

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

trajRows = cell(nTraj, 1);
windowRows = {};

for i = 1:nTraj

    trj = Dataset.Trajectory{i};
    state = Dataset.State{i};
    tid = Dataset.Tid(i);
    rawIndex = Dataset.RawIndex(i);

    if isempty(trj) || isempty(state)
        CA.PerTrajectory{i} = struct();
        continue
    end

    [x, y] = localExtractXY(trj);

    x = x(:);
    y = y(:);
    state = state(:);

    nPoint = numel(x);
    nState = numel(state);
    n = min(nPoint, nState);

    if n < minPoints
        CA.PerTrajectory{i} = struct();
        continue
    end

    x = x(1:n);
    y = y(1:n);
    state = state(1:n);

    % ----------------------------------------------------
    % Global trajectory metrics
    % ----------------------------------------------------

    [rgGlobal, hullAreaGlobal, hullPerimGlobal] = localGeometryMetrics(x, y);
    stepGlobal = localStepLengthFromTrajectory(x, y);
    totalDistanceGlobal = sum(stepGlobal);
    netDisplacementGlobal = sqrt((x(end) - x(1))^2 + (y(end) - y(1))^2);

    if totalDistanceGlobal > 0
        confinementRatioGlobal = netDisplacementGlobal / totalDistanceGlobal;
        confinementIndexGlobal = 1 - confinementRatioGlobal;
    else
        confinementRatioGlobal = NaN;
        confinementIndexGlobal = NaN;
    end

    packingGlobal = NaN;
    if isfinite(hullAreaGlobal) && hullAreaGlobal > 0 && ~isempty(stepGlobal)
        packingGlobal = sum(stepGlobal.^2) / hullAreaGlobal;
    end

    centerX = mean(x);
    centerY = mean(y);

    % ----------------------------------------------------
    % Sliding-window local profiles
    % ----------------------------------------------------

    nWin = 0;
    wStart = [];
    wEnd = [];
    wCenter = [];
    wCenterTime = [];
    wRg = [];
    wHullArea = [];
    wHullPerim = [];
    wPacking = [];
    wRatio = [];
    wIndex = [];
    wState = [];
    wCenterState = [];
    wNet = [];
    wTotal = [];
    wMeanX = [];
    wMeanY = [];

    if n >= winSize

        starts = 1:stride:(n - winSize + 1);
        nWin = numel(starts);

        wStart = nan(nWin, 1);
        wEnd = nan(nWin, 1);
        wCenter = nan(nWin, 1);
        wCenterTime = nan(nWin, 1);
        wRg = nan(nWin, 1);
        wHullArea = nan(nWin, 1);
        wHullPerim = nan(nWin, 1);
        wPacking = nan(nWin, 1);
        wRatio = nan(nWin, 1);
        wIndex = nan(nWin, 1);
        wState = nan(nWin, 1);
        wCenterState = nan(nWin, 1);
        wNet = nan(nWin, 1);
        wTotal = nan(nWin, 1);
        wMeanX = nan(nWin, 1);
        wMeanY = nan(nWin, 1);

        for k = 1:nWin

            s0 = starts(k);
            s1 = s0 + winSize - 1;
            idx = s0:s1;

            xw = x(idx);
            yw = y(idx);

            [rgW, hullAreaW, hullPerimW] = localGeometryMetrics(xw, yw);
            stepW = localStepLengthFromTrajectory(xw, yw);
            totalDistanceW = sum(stepW);
            netDisplacementW = sqrt((xw(end) - xw(1))^2 + (yw(end) - yw(1))^2);

            if totalDistanceW > 0
                confinementRatioW = netDisplacementW / totalDistanceW;
                confinementIndexW = 1 - confinementRatioW;
            else
                confinementRatioW = NaN;
                confinementIndexW = NaN;
            end

            packingW = NaN;
            if isfinite(hullAreaW) && hullAreaW > 0 && ~isempty(stepW)
                packingW = sum(stepW.^2) / hullAreaW;
            end

            centerFrame = s0 + floor((winSize - 1) / 2);
            centerFrame = min(max(centerFrame, 1), n);
            centerTime_s = (centerFrame - 1) * dt;

            % Dominant state inside the window
            stateW = state(idx);
            stateW = stateW(~isnan(stateW));
            if isempty(stateW)
                domState = NaN;
            else
                domState = localModeInteger(stateW);
            end

            centerState = state(centerFrame);

            wStart(k) = s0;
            wEnd(k) = s1;
            wCenter(k) = centerFrame;
            wCenterTime(k) = centerTime_s;
            wRg(k) = rgW;
            wHullArea(k) = hullAreaW;
            wHullPerim(k) = hullPerimW;
            wPacking(k) = packingW;
            wRatio(k) = confinementRatioW;
            wIndex(k) = confinementIndexW;
            wState(k) = domState;
            wCenterState(k) = centerState;
            wNet(k) = netDisplacementW;
            wTotal(k) = totalDistanceW;
            wMeanX(k) = mean(xw);
            wMeanY(k) = mean(yw);

        end
    end

    % ----------------------------------------------------
    % Per-trajectory summary
    % ----------------------------------------------------

    trajState = state(~isnan(state));
    if isempty(trajState)
        dominantState = NaN;
    else
        dominantState = localModeInteger(trajState);
    end

    stateFrac = zeros(1, nStates);
    for k = 1:nStates
        stateFrac(k) = sum(state == k) / n;
    end

    meanWindowRg = localMeanIgnoreNaN(wRg);
    medianWindowRg = localMedianIgnoreNaN(wRg);
    meanWindowHullArea = localMeanIgnoreNaN(wHullArea);
    meanWindowPacking = localMeanIgnoreNaN(wPacking);
    meanWindowRatio = localMeanIgnoreNaN(wRatio);
    meanWindowIndex = localMeanIgnoreNaN(wIndex);

    T = struct();
    T.DatasetIndex = i;
    T.RawIndex = rawIndex;
    T.Tid = tid;
    T.NPoints = n;
    T.TimeStep_s = dt;

    T.CentroidX = centerX;
    T.CentroidY = centerY;

    T.RadiusOfGyration = rgGlobal;
    T.ConvexHullArea = hullAreaGlobal;
    T.ConvexHullPerimeter = hullPerimGlobal;
    T.TotalDistance = totalDistanceGlobal;
    T.NetDisplacement = netDisplacementGlobal;
    T.ConfinementRatio = confinementRatioGlobal;
    T.ConfinementIndex = confinementIndexGlobal;
    T.PackingCoefficient = packingGlobal;

    T.WindowSize = winSize;
    T.Stride = stride;
    T.WindowCount = nWin;

    T.MeanWindowRadiusOfGyration = meanWindowRg;
    T.MedianWindowRadiusOfGyration = medianWindowRg;
    T.MeanWindowHullArea = meanWindowHullArea;
    T.MeanWindowPackingCoefficient = meanWindowPacking;
    T.MeanWindowConfinementRatio = meanWindowRatio;
    T.MeanWindowConfinementIndex = meanWindowIndex;

    T.DominantState = dominantState;
    T.NStates = numel(unique(trajState));
    T.StateFractions = stateFrac;

    for k = 1:nStates
        T.(['state' num2str(k) '_fraction']) = stateFrac(k);
    end

    T.WindowCenterFrame = wCenter;
    T.WindowCenterTime_s = wCenterTime;
    T.WindowRg = wRg;
    T.WindowHullArea = wHullArea;
    T.WindowHullPerimeter = wHullPerim;
    T.WindowPackingCoefficient = wPacking;
    T.WindowConfinementRatio = wRatio;
    T.WindowConfinementIndex = wIndex;
    T.WindowState = wState;
    T.WindowCenterState = wCenterState;
    T.WindowNetDisplacement = wNet;
    T.WindowTotalDistance = wTotal;
    T.WindowMeanX = wMeanX;
    T.WindowMeanY = wMeanY;

    CA.PerTrajectory{i} = T;

    trajRows{i} = makeTrajectorySummaryRow(T, nStates); %#ok<AGROW>

    % ----------------------------------------------------
    % Append window rows
    % ----------------------------------------------------

    if Config.Confinement.ComputeWindowTable && nWin > 0
        for k = 1:nWin
            windowRows{end+1, 1} = makeWindowRow(T, k, nStates); %#ok<AGROW>
        end
    end

end

%% --------------------------------------------------------
%% Combine tables
%% --------------------------------------------------------

if ~isempty(trajRows)
    valid = trajRows(~cellfun(@isempty, trajRows));
    if ~isempty(valid)
        CA.Table = vertcat(valid{:});
        if ismember('DatasetIndex', CA.Table.Properties.VariableNames)
            CA.Table = sortrows(CA.Table, 'DatasetIndex');
        end
    end
end

if ~isempty(windowRows)
    validW = windowRows(~cellfun(@isempty, windowRows));
    if ~isempty(validW)
        CA.WindowTable = vertcat(validW{:});
        if ismember('DatasetIndex', CA.WindowTable.Properties.VariableNames) && ...
                ismember('WindowID', CA.WindowTable.Properties.VariableNames)
            CA.WindowTable = sortrows(CA.WindowTable, {'DatasetIndex', 'WindowID'});
        end
    end
end

%% --------------------------------------------------------
%% Ensemble summary
%% --------------------------------------------------------

Ensemble = struct();
Ensemble.nTraj = nTraj;
Ensemble.nStates = nStates;
Ensemble.WindowSize = winSize;
Ensemble.Stride = stride;
Ensemble.MinPoints = minPoints;

if ~isempty(CA.WindowTable)
    Ensemble.nWindows = height(CA.WindowTable);
else
    Ensemble.nWindows = 0;
end

Ensemble.MeanRadiusOfGyration = localMeanIgnoreNaN(getTableColumn(CA.WindowTable, 'RadiusOfGyration'));
Ensemble.MedianRadiusOfGyration = localMedianIgnoreNaN(getTableColumn(CA.WindowTable, 'RadiusOfGyration'));

Ensemble.MeanConvexHullArea = localMeanIgnoreNaN(getTableColumn(CA.WindowTable, 'ConvexHullArea'));
Ensemble.MedianConvexHullArea = localMedianIgnoreNaN(getTableColumn(CA.WindowTable, 'ConvexHullArea'));

Ensemble.MeanPackingCoefficient = localMeanIgnoreNaN(getTableColumn(CA.WindowTable, 'PackingCoefficient'));
Ensemble.MedianPackingCoefficient = localMedianIgnoreNaN(getTableColumn(CA.WindowTable, 'PackingCoefficient'));

Ensemble.MeanConfinementRatio = localMeanIgnoreNaN(getTableColumn(CA.WindowTable, 'ConfinementRatio'));
Ensemble.MedianConfinementRatio = localMedianIgnoreNaN(getTableColumn(CA.WindowTable, 'ConfinementRatio'));

Ensemble.MeanConfinementIndex = localMeanIgnoreNaN(getTableColumn(CA.WindowTable, 'ConfinementIndex'));
Ensemble.MedianConfinementIndex = localMedianIgnoreNaN(getTableColumn(CA.WindowTable, 'ConfinementIndex'));

Ensemble.HistogramBins = 40;
[Ensemble.RgHistogramCounts, Ensemble.RgHistogramEdges] = localHistCounts(getTableColumn(CA.WindowTable, 'RadiusOfGyration'), Ensemble.HistogramBins);
[Ensemble.PackingHistogramCounts, Ensemble.PackingHistogramEdges] = localHistCounts(getTableColumn(CA.WindowTable, 'PackingCoefficient'), Ensemble.HistogramBins);
[Ensemble.RatioHistogramCounts, Ensemble.RatioHistogramEdges] = localHistCounts(getTableColumn(CA.WindowTable, 'ConfinementRatio'), Ensemble.HistogramBins);
[Ensemble.IndexHistogramCounts, Ensemble.IndexHistogramEdges] = localHistCounts(getTableColumn(CA.WindowTable, 'ConfinementIndex'), Ensemble.HistogramBins);

CA.Ensemble = Ensemble;

%% --------------------------------------------------------
%% State-specific summary
%% --------------------------------------------------------

ByState = repmat(struct( ...
    'State', [], ...
    'nWindows', [], ...
    'nTraj', [], ...
    'MeanRadiusOfGyration', [], ...
    'MedianRadiusOfGyration', [], ...
    'MeanConvexHullArea', [], ...
    'MeanPackingCoefficient', [], ...
    'MeanConfinementRatio', [], ...
    'MeanConfinementIndex', []), nStates, 1);

for k = 1:nStates

    if ~isempty(CA.WindowTable) && ismember('WindowState', CA.WindowTable.Properties.VariableNames)
        idx = (CA.WindowTable.WindowState == k);
    else
        idx = false(0, 1);
    end

    ByState(k).State = k;
    ByState(k).nWindows = sum(idx);

    if any(idx)
        ByState(k).nTraj = numel(unique(CA.WindowTable.DatasetIndex(idx)));
        ByState(k).MeanRadiusOfGyration = localMeanIgnoreNaN(CA.WindowTable.RadiusOfGyration(idx));
        ByState(k).MedianRadiusOfGyration = localMedianIgnoreNaN(CA.WindowTable.RadiusOfGyration(idx));
        ByState(k).MeanConvexHullArea = localMeanIgnoreNaN(CA.WindowTable.ConvexHullArea(idx));
        ByState(k).MeanPackingCoefficient = localMeanIgnoreNaN(CA.WindowTable.PackingCoefficient(idx));
        ByState(k).MeanConfinementRatio = localMeanIgnoreNaN(CA.WindowTable.ConfinementRatio(idx));
        ByState(k).MeanConfinementIndex = localMeanIgnoreNaN(CA.WindowTable.ConfinementIndex(idx));
    else
        ByState(k).nTraj = 0;
        ByState(k).MeanRadiusOfGyration = NaN;
        ByState(k).MedianRadiusOfGyration = NaN;
        ByState(k).MeanConvexHullArea = NaN;
        ByState(k).MeanPackingCoefficient = NaN;
        ByState(k).MeanConfinementRatio = NaN;
        ByState(k).MeanConfinementIndex = NaN;
    end
end

CA.ByState = ByState;

%% --------------------------------------------------------
%% Summary
%% --------------------------------------------------------

Summary = struct();
Summary.nTraj = nTraj;
Summary.nStates = nStates;
Summary.WindowSize = winSize;
Summary.Stride = stride;
Summary.MinPoints = minPoints;
Summary.nTrajectoryRows = height(CA.Table);
Summary.nWindowRows = height(CA.WindowTable);

Summary.MeanRadiusOfGyration = Ensemble.MeanRadiusOfGyration;
Summary.MeanConvexHullArea = Ensemble.MeanConvexHullArea;
Summary.MeanPackingCoefficient = Ensemble.MeanPackingCoefficient;
Summary.MeanConfinementRatio = Ensemble.MeanConfinementRatio;
Summary.MeanConfinementIndex = Ensemble.MeanConfinementIndex;

CA.Summary = Summary;

%% --------------------------------------------------------
%% Save
%% --------------------------------------------------------

Project.Analysis.Confinement = CA;

if ~isfield(Project.Validation, 'ConfinementOK')
    Project.Validation.ConfinementOK = false;
end
Project.Validation.ConfinementOK = true;

if ~isfield(Project.Validation, 'AnalysisOK')
    Project.Validation.AnalysisOK = false;
end
Project.Validation.AnalysisOK = true;

Project.Flags.Analysis = true;

%% --------------------------------------------------------
%% Display
%% --------------------------------------------------------

fprintf('Trajectory rows       : %d\n', height(CA.Table));
fprintf('Window rows           : %d\n', height(CA.WindowTable));
fprintf('Mean Rg (window)      : %.6g\n', Ensemble.MeanRadiusOfGyration);
fprintf('Mean hull area        : %.6g\n', Ensemble.MeanConvexHullArea);
fprintf('Mean packing coeff    : %.6g\n', Ensemble.MeanPackingCoefficient);
fprintf('Mean confinement ratio: %.6g\n', Ensemble.MeanConfinementRatio);
fprintf('Mean confinement index: %.6g\n', Ensemble.MeanConfinementIndex);

fprintf('\n');
fprintf('Confinement v2 created successfully.');
fprintf('\n');
fprintf('=====================================================\n');

end

% =====================================================================
function row = makeTrajectorySummaryRow(T, nStates)

row = table();

vars = {'DatasetIndex','RawIndex','Tid','NPoints','TimeStep_s', ...
        'CentroidX','CentroidY','RadiusOfGyration','ConvexHullArea', ...
        'ConvexHullPerimeter','TotalDistance','NetDisplacement', ...
        'ConfinementRatio','ConfinementIndex','PackingCoefficient', ...
        'WindowSize','Stride','WindowCount','MeanWindowRadiusOfGyration', ...
        'MedianWindowRadiusOfGyration','MeanWindowHullArea', ...
        'MeanWindowPackingCoefficient','MeanWindowConfinementRatio', ...
        'MeanWindowConfinementIndex','DominantState','NStates'};

vals = cell(1, numel(vars));
for i = 1:numel(vars)
    if isfield(T, vars{i})
        vals{i} = T.(vars{i});
    else
        vals{i} = NaN;
    end
end

row = table(vals{:}, 'VariableNames', vars);

for k = 1:nStates
    fname = ['state' num2str(k) '_fraction'];
    if isfield(T, fname)
        row.(fname) = T.(fname);
    else
        row.(fname) = NaN;
    end
end

end

% =====================================================================
function row = makeWindowRow(T, k, nStates)

row = table();

row.DatasetIndex = T.DatasetIndex;
row.RawIndex = T.RawIndex;
row.Tid = T.Tid;
row.WindowID = k;

row.StartFrame = T.WindowCenterFrame(k) - floor((T.WindowSize - 1) / 2);
row.EndFrame = row.StartFrame + T.WindowSize - 1;
row.CenterFrame = T.WindowCenterFrame(k);
row.CenterTime_s = T.WindowCenterTime_s(k);

row.WindowSize = T.WindowSize;
row.Stride = T.Stride;

row.RadiusOfGyration = T.WindowRg(k);
row.ConvexHullArea = T.WindowHullArea(k);
row.ConvexHullPerimeter = T.WindowHullPerimeter(k);
row.PackingCoefficient = T.WindowPackingCoefficient(k);
row.ConfinementRatio = T.WindowConfinementRatio(k);
row.ConfinementIndex = T.WindowConfinementIndex(k);
row.NetDisplacement = T.WindowNetDisplacement(k);
row.TotalDistance = T.WindowTotalDistance(k);
row.MeanX = T.WindowMeanX(k);
row.MeanY = T.WindowMeanY(k);

row.WindowState = T.WindowState(k);
row.WindowCenterState = T.WindowCenterState(k);

for j = 1:nStates
    row.(['state' num2str(j) '_fraction']) = NaN;
end

end

% =====================================================================
function [x, y] = localExtractXY(trj)

if isempty(trj) || ~isnumeric(trj) || ~ismatrix(trj)
    x = [];
    y = [];
    return;
end

[r, c] = size(trj);

if c >= 2 && r >= c
    x = trj(:, 1);
    y = trj(:, 2);
elseif r >= 2
    x = trj(1, :)';
    y = trj(2, :)';
else
    x = [];
    y = [];
end

x = x(:);
y = y(:);

end

% =====================================================================
function [rg, hullArea, hullPerim] = localGeometryMetrics(x, y)

rg = NaN;
hullArea = NaN;
hullPerim = NaN;

if isempty(x) || isempty(y)
    return;
end

cx = mean(x);
cy = mean(y);
rg = sqrt(mean((x - cx).^2 + (y - cy).^2));

pts = unique([x(:), y(:)], 'rows');

if size(pts, 1) < 3
    hullArea = 0;
    hullPerim = 0;
    return;
end

try
    k = convhull(pts(:,1), pts(:,2));
    hx = pts(k, 1);
    hy = pts(k, 2);

    hullArea = polyarea(hx, hy);

    dx = diff(hx);
    dy = diff(hy);
    hullPerim = sum(sqrt(dx.^2 + dy.^2));
catch
    hullArea = NaN;
    hullPerim = NaN;
end

end

% =====================================================================
function step = localStepLengthFromTrajectory(x, y)

if numel(x) < 2
    step = [];
    return;
end

dx = diff(x);
dy = diff(y);
step = sqrt(dx.^2 + dy.^2);

end

% =====================================================================
function m = localModeInteger(x)

x = x(:);
x = x(isfinite(x));

if isempty(x)
    m = NaN;
    return;
end

try
    m = mode(x);
catch
    ux = unique(x);
    counts = zeros(numel(ux), 1);
    for i = 1:numel(ux)
        counts(i) = sum(x == ux(i));
    end
    [~, idx] = max(counts);
    m = ux(idx);
end

end

% =====================================================================
function y = localMeanIgnoreNaN(x)

if isempty(x)
    y = NaN;
    return;
end

x = x(:);
x = x(isfinite(x));

if isempty(x)
    y = NaN;
else
    y = mean(x);
end

end

% =====================================================================
function y = localMedianIgnoreNaN(x)

if isempty(x)
    y = NaN;
    return;
end

x = x(:);
x = x(isfinite(x));

if isempty(x)
    y = NaN;
else
    y = median(x);
end

end

% =====================================================================
function [counts, edges] = localHistCounts(x, nbins)

x = x(:);
x = x(isfinite(x));

if isempty(x)
    counts = zeros(nbins, 1);
    edges = linspace(0, 1, nbins + 1);
    return;
end

xmin = min(x);
xmax = max(x);

if xmin == xmax
    xmin = xmin - 0.5;
    xmax = xmax + 0.5;
end

edges = linspace(xmin, xmax, nbins + 1);

if exist('histcounts', 'file') == 2
    counts = histcounts(x, edges);
else
    counts = histc(x, edges);
    counts(end-1) = counts(end-1) + counts(end);
    counts = counts(1:end-1);
end

counts = counts(:);

end

% =====================================================================
function x = getTableColumn(T, name)

if isempty(T) || ~istable(T) || ~ismember(name, T.Properties.VariableNames)
    x = [];
    return;
end

x = T.(name);

end

% =====================================================================
function nStates = inferNStatesFromStateCell(stateCell)

allStates = [];
for i = 1:numel(stateCell)
    if isempty(stateCell{i})
        continue
    end
    allStates = [allStates; stateCell{i}(:)]; %#ok<AGROW>
end

if isempty(allStates)
    nStates = 1;
else
    nStates = max(allStates);
end

end