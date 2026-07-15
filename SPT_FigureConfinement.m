function figures = SPT_FigureConfinement(Project, F, confOverallDir, confGroupedDir, confStateDir, confProfileDir, stateColors)
% SPT_FigureConfinement
% Figure Framework v2
% Frozen version
% MATLAB R2016b compatible

figures = struct([]);

if ~isfield(Project, 'Analysis') || ~isfield(Project.Analysis, 'Confinement') || isempty(Project.Analysis.Confinement)
    return;
end

CA = Project.Analysis.Confinement;

if ~isfield(CA, 'Table') || ~istable(CA.Table) || isempty(CA.Table)
    return;
end

T = CA.Table;

WT = table();
if isfield(CA, 'WindowTable') && istable(CA.WindowTable) && ~isempty(CA.WindowTable)
    WT = CA.WindowTable;
end

if ~isempty(WT)
    if ismember('WindowState', WT.Properties.VariableNames)
        stateVar = 'WindowState';
    elseif ismember('State', WT.Properties.VariableNames)
        stateVar = 'State';
    else
        stateVar = '';
    end
else
    stateVar = '';
end

% ------------------------------------------------------------
% 1) Overall histograms from trajectory-level confinement table
% ------------------------------------------------------------
metrics = { ...
    'RadiusOfGyration',   'Radius of gyration (window)',  'confinement_window_rg_hist'; ...
    'ConvexHullArea',     'Convex hull area (window)',    'confinement_window_hull_area_hist'; ...
    'PackingCoefficient', 'Packing coefficient (window)', 'confinement_window_packing_hist'; ...
    'ConfinementRatio',   'Confinement ratio (window)',   'confinement_window_ratio_hist'; ...
    'ConfinementIndex',   'Confinement index (window)',   'confinement_window_index_hist'};

for m = 1:size(metrics, 1)
    colName = metrics{m, 1};
    xLabelText = metrics{m, 2};
    baseName = metrics{m, 3};

    if ~ismember(colName, T.Properties.VariableNames)
        continue;
    end

    x = T.(colName);
    x = x(:);
    x = x(isfinite(x));

    if isempty(x)
        continue;
    end

    figures = [figures, localHistogramFigure(x, xLabelText, baseName, confOverallDir, F)]; %#ok<AGROW>
end

% ------------------------------------------------------------
% 2) State-resolved grouped density from window table
% ------------------------------------------------------------
if ~isempty(WT) && ~isempty(stateVar)
    metrics2 = { ...
        'RadiusOfGyration',   'Radius of gyration (window)',  'confinement_window_rg_grouped'; ...
        'ConvexHullArea',     'Convex hull area (window)',    'confinement_window_hull_area_grouped'; ...
        'PackingCoefficient', 'Packing coefficient (window)', 'confinement_window_packing_grouped'; ...
        'ConfinementRatio',   'Confinement ratio (window)',   'confinement_window_ratio_grouped'; ...
        'ConfinementIndex',   'Confinement index (window)',   'confinement_window_index_grouped'};

    for m = 1:size(metrics2, 1)
        colName = metrics2{m, 1};
        xLabelText = metrics2{m, 2};
        baseName = metrics2{m, 3};

        if ~ismember(colName, WT.Properties.VariableNames)
            continue;
        end

        x = WT.(colName);
        st = WT.(stateVar);

        x = x(:);
        st = st(:);

        valid = isfinite(x) & isfinite(st);
        x = x(valid);
        st = st(valid);

        if isempty(x)
            continue;
        end

        figures = [figures, localGroupedDensityFigure(x, st, xLabelText, baseName, confGroupedDir, F, stateColors)]; %#ok<AGROW>
    end
end

% ------------------------------------------------------------
% 3) State summary bars
% ------------------------------------------------------------
if isfield(CA, 'ByState') && ~isempty(CA.ByState)
    nState = numel(CA.ByState);

    rgVals = nan(nState, 1);
    packVals = nan(nState, 1);
    ratioVals = nan(nState, 1);
    indexVals = nan(nState, 1);

    for k = 1:nState
        if isfield(CA.ByState(k), 'MeanRadiusOfGyration')
            rgVals(k) = CA.ByState(k).MeanRadiusOfGyration;
        end
        if isfield(CA.ByState(k), 'MeanPackingCoefficient')
            packVals(k) = CA.ByState(k).MeanPackingCoefficient;
        end
        if isfield(CA.ByState(k), 'MeanConfinementRatio')
            ratioVals(k) = CA.ByState(k).MeanConfinementRatio;
        end
        if isfield(CA.ByState(k), 'MeanConfinementIndex')
            indexVals(k) = CA.ByState(k).MeanConfinementIndex;
        end
    end

    figures = [figures, localBarFigure(1:nState, rgVals, ...
        'State', 'Mean R_g', ...
        'Confinement by state: Radius of gyration', ...
        fullfile(confStateDir, 'confinement_state_rg'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nState, packVals, ...
        'State', 'Mean packing coefficient', ...
        'Confinement by state: Packing coefficient', ...
        fullfile(confStateDir, 'confinement_state_packing'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nState, ratioVals, ...
        'State', 'Mean confinement ratio', ...
        'Confinement by state: Confinement ratio', ...
        fullfile(confStateDir, 'confinement_state_ratio'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nState, indexVals, ...
        'State', 'Mean confinement index', ...
        'Confinement by state: Confinement index', ...
        fullfile(confStateDir, 'confinement_state_index'), F)]; %#ok<AGROW>
end

% ------------------------------------------------------------
% 4) Per-trajectory confinement profiles
% ------------------------------------------------------------
if isfield(CA, 'PerTrajectory') && ~isempty(CA.PerTrajectory)
    nPreview = min(F.ConfProfilePreview, numel(CA.PerTrajectory));
    for i = 1:nPreview
        PT = CA.PerTrajectory{i};
        if isempty(PT) || ~isstruct(PT) || ~isfield(PT, 'WindowCenterTime_s') || isempty(PT.WindowCenterTime_s)
            continue;
        end
        figures = [figures, localProfileFigure(PT, i, confProfileDir, F, stateColors)]; %#ok<AGROW>
    end
end

end

% =====================================================================
function figs = localHistogramFigure(x, xLabelText, baseName, outDir, F)
figs = struct('Name', '', 'PNGFile', '', 'PDFFile', '');

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);

nbins = F.ConfBins;
xmin = min(x);
xmax = max(x);
if xmin == xmax
    xmin = xmin - 0.5;
    xmax = xmax + 0.5;
end

edges = linspace(xmin, xmax, nbins + 1);
counts = SPT_FigureHistcountsCompat(x, edges);
centers = (edges(1:end-1) + edges(2:end)) / 2;

bar(ax, centers, counts, 1.0, ...
    'FaceColor', [0.20 0.45 0.85], ...
    'EdgeColor', 'none');

SPT_FigureStyleAxes(ax, F);
xlabel(ax, xLabelText);
ylabel(ax, 'Count');
title(ax, xLabelText, ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');

SPT_FigureEnsureDir(outDir);
out = SPT_FigureSavePair(fig, fullfile(outDir, baseName), F);
close(fig);

figs(1).Name = baseName;
figs(1).PNGFile = out.PNGFile;
figs(1).PDFFile = out.PDFFile;
end

% =====================================================================
function figs = localGroupedDensityFigure(x, st, xLabelText, baseName, outDir, F, stateColors)
figs = struct('Name', '', 'PNGFile', '', 'PDFFile', '');

stateIDs = unique(st);
stateIDs = stateIDs(isfinite(stateIDs));
stateIDs = sort(stateIDs(:));

if isempty(stateIDs)
    figs = [];
    return;
end

nbins = F.ConfBins;
xmin = min(x);
xmax = max(x);
if xmin == xmax
    xmin = xmin - 0.5;
    xmax = xmax + 0.5;
end

edges = linspace(xmin, xmax, nbins + 1);
centers = (edges(1:end-1) + edges(2:end)) / 2;
binWidth = edges(2) - edges(1);

D = zeros(nbins, numel(stateIDs));

for s = 1:numel(stateIDs)
    idx = (st == stateIDs(s));
    xs = x(idx);
    if isempty(xs)
        continue;
    end

    c = SPT_FigureHistcountsCompat(xs, edges);
    total = sum(c);
    if total > 0 && isfinite(binWidth) && binWidth > 0
        D(:, s) = c(:) ./ (total * binWidth);
    end
end

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);
hold(ax, 'on');

for s = 1:numel(stateIDs)
    c = SPT_FigureStateColor(stateIDs(s), stateColors);
    bar(ax, centers, D(:, s), 1.0, ...
        'FaceColor', c, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.65);
end

SPT_FigureStyleAxes(ax, F);
xlabel(ax, xLabelText);
ylabel(ax, 'Density');
title(ax, [xLabelText ' | state-resolved normalized density'], ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');
xlim(ax, [xmin xmax]);

legendCells = cell(1, numel(stateIDs));
for s = 1:numel(stateIDs)
    legendCells{s} = ['State ' num2str(stateIDs(s))];
end
legend(ax, legendCells, 'Location', 'best');

SPT_FigureEnsureDir(outDir);
out = SPT_FigureSavePair(fig, fullfile(outDir, baseName), F);
close(fig);

figs(1).Name = baseName;
figs(1).PNGFile = out.PNGFile;
figs(1).PDFFile = out.PDFFile;
end

% =====================================================================
function figs = localBarFigure(x, y, xlab, ylab, ttl, basePath, F)
figs = struct('Name', '', 'PNGFile', '', 'PDFFile', '');

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);
bar(ax, x, y, 0.75);

SPT_FigureStyleAxes(ax, F);
xlabel(ax, xlab);
ylabel(ax, ylab);
title(ax, ttl, ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');

out = SPT_FigureSavePair(fig, basePath, F);
close(fig);

figs(1).Name = localBaseName(basePath);
figs(1).PNGFile = out.PNGFile;
figs(1).PDFFile = out.PDFFile;
end

% =====================================================================
function figs = localProfileFigure(PT, idx, outDir, F, stateColors)
figs = struct('Name', '', 'PNGFile', '', 'PDFFile', '');

t = PT.WindowCenterTime_s(:);

haveRg = isfield(PT, 'WindowRg') && ~isempty(PT.WindowRg);
havePack = isfield(PT, 'WindowPackingCoefficient') && ~isempty(PT.WindowPackingCoefficient);
haveRatio = isfield(PT, 'WindowConfinementRatio') && ~isempty(PT.WindowConfinementRatio);
haveIndex = isfield(PT, 'WindowConfinementIndex') && ~isempty(PT.WindowConfinementIndex);
haveState = isfield(PT, 'WindowState') && ~isempty(PT.WindowState);

if ~haveRg && ~havePack && ~haveRatio && ~haveIndex
    figs = [];
    return;
end

nSub = 0;
if haveRg, nSub = nSub + 1; end
if havePack, nSub = nSub + 1; end
if haveRatio, nSub = nSub + 1; end
if haveIndex, nSub = nSub + 1; end

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
plotIdx = 0;

if haveRg
    plotIdx = plotIdx + 1;
    subplot(nSub, 1, plotIdx);
    localPlotWindowSeries(t, PT.WindowRg(:), haveState, PT, stateColors, F);
    ylabel('R_g');
    title(sprintf('Trajectory %d | confinement profile', idx), ...
        'FontName', F.FontName, ...
        'FontSize', F.TitleFontSize, ...
        'FontWeight', 'bold');
end

if havePack
    plotIdx = plotIdx + 1;
    subplot(nSub, 1, plotIdx);
    localPlotWindowSeries(t, PT.WindowPackingCoefficient(:), haveState, PT, stateColors, F);
    ylabel('Packing');
end

if haveRatio
    plotIdx = plotIdx + 1;
    subplot(nSub, 1, plotIdx);
    localPlotWindowSeries(t, PT.WindowConfinementRatio(:), haveState, PT, stateColors, F);
    ylabel('Ratio');
end

if haveIndex
    plotIdx = plotIdx + 1;
    subplot(nSub, 1, plotIdx);
    localPlotWindowSeries(t, PT.WindowConfinementIndex(:), haveState, PT, stateColors, F);
    ylabel('Index');
end

xlabel('Time (s)');
baseName = sprintf('confinement_profile_tid_%d', localGetValue(PT, {'Tid', 'tid'}, idx));
out = SPT_FigureSavePair(fig, fullfile(outDir, baseName), F);
close(fig);

figs(1).Name = baseName;
figs(1).PNGFile = out.PNGFile;
figs(1).PDFFile = out.PDFFile;
end

% =====================================================================
function localPlotWindowSeries(t, y, haveState, PT, stateColors, F)
hold on;

if haveState && isfield(PT, 'WindowState') && numel(PT.WindowState) == numel(y)
    st = PT.WindowState(:);
    for k = 1:numel(y)
        c = SPT_FigureStateColor(st(k), stateColors);
        plot(t(k), y(k), '.', ...
            'Color', c, ...
            'MarkerSize', 10);
    end
    plot(t, y, '-', ...
        'Color', [0.2 0.2 0.2], ...
        'LineWidth', 1.0);
else
    plot(t, y, '-', ...
        'Color', [0.2 0.2 0.2], ...
        'LineWidth', 1.2);
end

SPT_FigureStyleAxes(gca, F);
box on;
end

% =====================================================================
function val = localGetValue(S, names, defaultVal)
val = defaultVal;
for i = 1:numel(names)
    if isfield(S, names{i})
        v = S.(names{i});
        if isnumeric(v) && numel(v) >= 1
            val = v(1);
            return;
        end
    end
end
end

% =====================================================================
function base = localBaseName(basePath)
[~, base, ~] = fileparts(basePath);
end

% =====================================================================
function styleAxes(ax, F)
set(ax, ...
    'FontName', F.FontName, ...
    'FontSize', F.FontSize, ...
    'LineWidth', F.AxisLineWidth, ...
    'TickDir', 'out', ...
    'Color', F.BackgroundColor);
box(ax, 'on');
end