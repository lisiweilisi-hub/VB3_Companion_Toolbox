function figures = SPT_FigurePublication(Project, F, pubSummaryDir, pubOverviewDir, stateColors)
% SPT_FigurePublication
% Figure Framework v2
% Frozen version
% MATLAB R2016b compatible

figures = struct([]);

if ~isfield(Project, 'Analysis') || ~isfield(Project.Analysis, 'Confinement') || isempty(Project.Analysis.Confinement)
    fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
    axis off;
    text(0.5, 0.5, 'No confinement analysis available', ...
        'HorizontalAlignment', 'center');
    out = SPT_FigureSavePair(fig, fullfile(pubSummaryDir, 'publication_summary'), F);
    close(fig);

    figures(1).Name = 'publication_summary';
    figures(1).PNGFile = out.PNGFile;
    figures(1).PDFFile = out.PDFFile;
    return;
end

CA = Project.Analysis.Confinement;

% ------------------------------------------------------------
% 1) Summary page
% ------------------------------------------------------------
fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
axis off;
hold on;

txt = buildSummaryText(Project);
text(0.02, 0.98, txt, ...
    'VerticalAlignment', 'top', ...
    'FontName', 'Courier New', ...
    'FontSize', 10, ...
    'Interpreter', 'none');

title('SPT Companion Summary');

out = SPT_FigureSavePair(fig, fullfile(pubSummaryDir, 'publication_summary'), F);
close(fig);

figures(1).Name = 'publication_summary';
figures(1).PNGFile = out.PNGFile;
figures(1).PDFFile = out.PDFFile;

% ------------------------------------------------------------
% 2) State occupancy
% ------------------------------------------------------------
if isfield(Project, 'Tables') && isfield(Project.Tables, 'State') && istable(Project.Tables.State)
    T = Project.Tables.State;
    if ismember('fractionOfPoints', T.Properties.VariableNames) && ismember('State', T.Properties.VariableNames)

        fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
        ax = axes('Parent', fig);
        bar(ax, T.State, T.fractionOfPoints);

        styleAxes(ax, F);
        xlabel(ax, 'State');
        ylabel(ax, 'Fraction of points');
        title(ax, 'State occupancy', ...
            'FontName', F.FontName, ...
            'FontSize', F.TitleFontSize, ...
            'FontWeight', 'bold');

        out = SPT_FigureSavePair(fig, fullfile(pubOverviewDir, 'publication_state_occupancy'), F);
        close(fig);

        figures(end+1).Name = 'publication_state_occupancy'; %#ok<AGROW>
        figures(end).PNGFile = out.PNGFile;
        figures(end).PDFFile = out.PDFFile;
    end
end

% ------------------------------------------------------------
% 3) Confinement overview
% ------------------------------------------------------------
if isfield(CA, 'WindowTable') && istable(CA.WindowTable) && ~isempty(CA.WindowTable)
    out = localConfinementOverview(Project, F, pubOverviewDir, stateColors);
    if ~isempty(out.PNGFile) || ~isempty(out.PDFFile)
        figures(end+1).Name = 'publication_confinement_overview'; %#ok<AGROW>
        figures(end).PNGFile = out.PNGFile;
        figures(end).PDFFile = out.PDFFile;
    end
end

% ------------------------------------------------------------
% 4) Optional summary bars from confinement by state
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
        fullfile(pubOverviewDir, 'publication_state_rg'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nState, packVals, ...
        'State', 'Mean packing coefficient', ...
        'Confinement by state: Packing coefficient', ...
        fullfile(pubOverviewDir, 'publication_state_packing'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nState, ratioVals, ...
        'State', 'Mean confinement ratio', ...
        'Confinement by state: Confinement ratio', ...
        fullfile(pubOverviewDir, 'publication_state_ratio'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nState, indexVals, ...
        'State', 'Mean confinement index', ...
        'Confinement by state: Confinement index', ...
        fullfile(pubOverviewDir, 'publication_state_index'), F)]; %#ok<AGROW>
end

end

% =====================================================================
function out = localConfinementOverview(Project, F, outDir, stateColors)

out = struct('PNGFile', '', 'PDFFile', '');

CA = Project.Analysis.Confinement;
WT = CA.WindowTable;

if ismember('WindowState', WT.Properties.VariableNames)
    stateVar = 'WindowState';
elseif ismember('State', WT.Properties.VariableNames)
    stateVar = 'State';
else
    stateVar = '';
end

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);

% ------------------------------------------------------------
% Panel 1: R_g histogram
% ------------------------------------------------------------
subplot(2, 2, 1);
if ismember('RadiusOfGyration', WT.Properties.VariableNames)
    x = WT.RadiusOfGyration;
    x = x(:);
    x = x(isfinite(x));
    if ~isempty(x)
        hist(x, F.ConfBins);
    end
end
styleAxes(gca, F);
xlabel('Window R_g');
ylabel('Count');
title('Window R_g');

% ------------------------------------------------------------
% Panel 2: Packing coefficient histogram
% ------------------------------------------------------------
subplot(2, 2, 2);
if ismember('PackingCoefficient', WT.Properties.VariableNames)
    x = WT.PackingCoefficient;
    x = x(:);
    x = x(isfinite(x));
    if ~isempty(x)
        hist(x, F.ConfBins);
    end
end
styleAxes(gca, F);
xlabel('Packing coefficient');
ylabel('Count');
title('Window packing coefficient');

% ------------------------------------------------------------
% Panel 3: state-resolved confinement ratio density
% ------------------------------------------------------------
subplot(2, 2, 3);
hold on;

if ~isempty(stateVar) && ismember('ConfinementRatio', WT.Properties.VariableNames)
    x = WT.ConfinementRatio(:);
    st = WT.(stateVar)(:);

    valid = isfinite(x) & isfinite(st);
    x = x(valid);
    st = st(valid);

    if ~isempty(x)
        stateIDs = unique(st);
        stateIDs = stateIDs(isfinite(stateIDs));
        stateIDs = sort(stateIDs(:));

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

        for s = 1:numel(stateIDs)
            idx = (st == stateIDs(s));
            xs = x(idx);
            if isempty(xs)
                continue;
            end

            c = SPT_FigureHistcountsCompat(xs, edges);
            total = sum(c);

            if total > 0 && isfinite(binWidth) && binWidth > 0
                d = c(:) ./ (total * binWidth);
            else
                d = zeros(nbins, 1);
            end

            ccol = SPT_FigureStateColor(stateIDs(s), stateColors);
            bar(centers, d, 1.0, ...
                'FaceColor', ccol, ...
                'EdgeColor', 'none', ...
                'FaceAlpha', 0.65);
        end

        legendCells = cell(1, numel(stateIDs));
        for s = 1:numel(stateIDs)
            legendCells{s} = ['State ' num2str(stateIDs(s))];
        end
        legend(legendCells, 'Location', 'best');
    end
end

styleAxes(gca, F);
xlabel('Confinement ratio');
ylabel('Density');
title('State-resolved confinement ratio');

% ------------------------------------------------------------
% Panel 4: state means
% ------------------------------------------------------------
subplot(2, 2, 4);
hold on;

if isfield(CA, 'ByState') && ~isempty(CA.ByState)
    nState = numel(CA.ByState);
    rgVals = nan(nState, 1);
    packVals = nan(nState, 1);

    for k = 1:nState
        if isfield(CA.ByState(k), 'MeanRadiusOfGyration')
            rgVals(k) = CA.ByState(k).MeanRadiusOfGyration;
        end
        if isfield(CA.ByState(k), 'MeanPackingCoefficient')
            packVals(k) = CA.ByState(k).MeanPackingCoefficient;
        end
    end

    bar(1:nState, rgVals, 0.55);
    bar(1:nState, packVals, 0.35);
end

styleAxes(gca, F);
xlabel('State');
ylabel('Value');
title('State mean R_g / packing');
legend({'R_g', 'Packing'}, 'Location', 'best');

out = SPT_FigureSavePair(fig, fullfile(outDir, 'publication_confinement_overview'), F);
close(fig);

end

% =====================================================================
function figs = localBarFigure(x, y, xlab, ylab, ttl, basePath, F)

figs = struct('Name', '', 'PNGFile', '', 'PDFFile', '');

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);
bar(ax, x, y, 0.75);

styleAxes(ax, F);
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
function txt = buildSummaryText(Project)

lines = {};

if isfield(Project, 'Info') && isfield(Project.Info, 'ProjectName')
    lines{end+1} = ['Project : ' Project.Info.ProjectName];
end

if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'Summary')
    S = Project.Dataset.Summary;
    if isfield(S, 'nTraj')
        lines{end+1} = ['nTraj   : ' num2str(S.nTraj)];
    end
    if isfield(S, 'TotalLocalizations')
        lines{end+1} = ['Points  : ' num2str(S.TotalLocalizations)];
    end
    if isfield(S, 'MeanLength')
        lines{end+1} = ['Mean L  : ' num2str(S.MeanLength)];
    end
    if isfield(S, 'dt')
        lines{end+1} = ['dt (s)  : ' num2str(S.dt)];
    end
end

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates')
    lines{end+1} = ['States  : ' num2str(Project.HMM.nStates)];
end

if isfield(Project, 'Analysis')
    if isfield(Project.Analysis, 'MSD') && ~isempty(Project.Analysis.MSD)
        MSD = Project.Analysis.MSD;
        if isfield(MSD, 'Fit') && isfield(MSD.Fit, 'Linear')
            if isfield(MSD.Fit.Linear, 'D') && ~isempty(MSD.Fit.Linear.D)
                lines{end+1} = ['D       : ' num2str(MSD.Fit.Linear.D)];
            end
            if isfield(MSD.Fit.Linear, 'R2') && ~isempty(MSD.Fit.Linear.R2)
                lines{end+1} = ['R^2     : ' num2str(MSD.Fit.Linear.R2)];
            end
        end
        if isfield(MSD, 'Fit') && isfield(MSD.Fit, 'PowerLaw') && ...
                isfield(MSD.Fit.PowerLaw, 'Alpha') && ~isempty(MSD.Fit.PowerLaw.Alpha)
            lines{end+1} = ['alpha   : ' num2str(MSD.Fit.PowerLaw.Alpha)];
        end
    end

    if isfield(Project.Analysis, 'TurningAngle') && ~isempty(Project.Analysis.TurningAngle)
        TA = Project.Analysis.TurningAngle;
        if isfield(TA, 'Ensemble') && isfield(TA.Ensemble, 'MeanAbsAngle_deg')
            lines{end+1} = ['|angle| : ' num2str(TA.Ensemble.MeanAbsAngle_deg)];
        end
    end

    if isfield(Project.Analysis, 'Confinement') && ~isempty(Project.Analysis.Confinement)
        CA = Project.Analysis.Confinement;
        if isfield(CA, 'Ensemble')
            if isfield(CA.Ensemble, 'MeanRadiusOfGyration')
                lines{end+1} = ['Rg      : ' num2str(CA.Ensemble.MeanRadiusOfGyration)];
            end
            if isfield(CA.Ensemble, 'MeanPackingCoefficient')
                lines{end+1} = ['Pack    : ' num2str(CA.Ensemble.MeanPackingCoefficient)];
            end
        end
    end
end

if isempty(lines)
    lines = {'No summary data available.'};
end

txt = strjoin(lines, sprintf('\n'));

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

% =====================================================================
function base = localBaseName(basePath)
[~, base, ~] = fileparts(basePath);
end