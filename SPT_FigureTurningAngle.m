function figures = SPT_FigureTurningAngle(Project, F, angleOverallDir, angleStateDir, stateColors)
% SPT_FigureTurningAngle
% Figure Framework v2
% Frozen version
% MATLAB R2016b compatible

figures = struct([]);

if ~isfield(Project, 'Analysis') || ~isfield(Project.Analysis, 'TurningAngle') || isempty(Project.Analysis.TurningAngle)
    return;
end

TA = Project.Analysis.TurningAngle;
if ~isfield(TA, 'Ensemble') || isempty(TA.Ensemble)
    return;
end

angles = localExtractAngleAll(TA);
angles = angles(isfinite(angles));
if isempty(angles)
    return;
end

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = localInferNStates(Project, TA);
end

% ------------------------------------------------------------
% Overall histogram
% ------------------------------------------------------------
out = localAngleHistogram(angles, ...
    sprintf('Turning angle histogram | n = %d', numel(angles)), ...
    'turning_angle_histogram', angleOverallDir, F, false);

figures(end+1).Name = 'turning_angle_histogram'; %#ok<AGROW>
figures(end).PNGFile = out.PNGFile;
figures(end).PDFFile = out.PDFFile;

% ------------------------------------------------------------
% Summary panel
% ------------------------------------------------------------
meanAngle = SPT_FigureCircularMeanDeg(angles);
meanAbsAngle = mean(abs(angles));
resultant = SPT_FigureCircularResultant(angles);

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);
axis(ax, 'off');

text(ax, 0.02, 0.96, sprintf([ ...
    'nAngles = %d\n' ...
    'Mean angle = %.2f deg\n' ...
    'Mean |angle| = %.2f deg\n' ...
    'Resultant length = %.3f\n' ...
    'Circular variance = %.3f'], ...
    numel(angles), meanAngle, meanAbsAngle, resultant, 1 - resultant), ...
    'Units', 'normalized', ...
    'VerticalAlignment', 'top', ...
    'FontName', F.FontName, ...
    'FontSize', F.FontSize, ...
    'Interpreter', 'none');

title(ax, sprintf('Turning angle summary | mean = %.2f deg | |mean| = %.2f deg | R = %.3f', ...
    meanAngle, meanAbsAngle, resultant), ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');

out = SPT_FigureSavePair(fig, fullfile(angleOverallDir, 'turning_angle_summary'), F);
close(fig);

figures(end+1).Name = 'turning_angle_summary'; %#ok<AGROW>
figures(end).PNGFile = out.PNGFile;
figures(end).PDFFile = out.PDFFile;

% ------------------------------------------------------------
% State-resolved grouped density
% ------------------------------------------------------------
angleByState = localAnglesByState(TA, nStates);
out = localGroupedDensity(angleByState, nStates, ...
    'Turning angle (deg)', ...
    'turning_angle_grouped_density', angleOverallDir, F, stateColors);

figures(end+1).Name = 'turning_angle_grouped_density'; %#ok<AGROW>
figures(end).PNGFile = out.PNGFile;
figures(end).PDFFile = out.PDFFile;

% ------------------------------------------------------------
% State bar summaries
% ------------------------------------------------------------
if isfield(TA, 'ByState') && ~isempty(TA.ByState)
    nB = numel(TA.ByState);
    meanVals = nan(nB, 1);
    absVals = nan(nB, 1);
    Rvals = nan(nB, 1);

    for k = 1:nB
        if isfield(TA.ByState(k), 'MeanAngle_deg')
            meanVals(k) = TA.ByState(k).MeanAngle_deg;
        end
        if isfield(TA.ByState(k), 'MeanAbsAngle_deg')
            absVals(k) = TA.ByState(k).MeanAbsAngle_deg;
        end
        if isfield(TA.ByState(k), 'ResultantLength')
            Rvals(k) = TA.ByState(k).ResultantLength;
        end
    end

    figures = [figures, localBarFigure(1:nB, meanVals, ...
        'State', 'Mean angle (deg)', ...
        'Mean turning angle by state', ...
        fullfile(angleStateDir, 'turning_angle_state_mean'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nB, absVals, ...
        'State', 'Mean |angle| (deg)', ...
        'Mean absolute turning angle by state', ...
        fullfile(angleStateDir, 'turning_angle_state_mean_abs'), F)]; %#ok<AGROW>

    figures = [figures, localBarFigure(1:nB, Rvals, ...
        'State', 'Resultant length', ...
        'Turning-angle concentration by state', ...
        fullfile(angleStateDir, 'turning_angle_state_resultant'), F)]; %#ok<AGROW>
end

end

% =====================================================================
function out = localAngleHistogram(anglesDeg, titleText, baseName, outDir, F, doSmooth)
anglesDeg = anglesDeg(:);
anglesDeg = anglesDeg(isfinite(anglesDeg));
out = struct('PNGFile', '', 'PDFFile', '');
if isempty(anglesDeg)
    return;
end

nbins = round(F.TurningAngleBins);
if ~isfinite(nbins) || nbins < 12
    nbins = 72;
end

edges = linspace(-180, 180, nbins + 1);
counts = SPT_FigureHistcountsCompat(anglesDeg, edges);
centers = (edges(1:end-1) + edges(2:end)) / 2;

if doSmooth
    counts = SPT_FigureSmoothVector(counts, 1);
end

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);

bar(ax, centers, counts, 1.0, ...
    'FaceColor', [0.20 0.35 0.80], ...
    'EdgeColor', 'none');
hold(ax, 'on');

plot(ax, [0 0], [0 max(counts) * 1.05 + eps], '--', ...
    'Color', [0.85 0.10 0.10], ...
    'LineWidth', 1.2);

SPT_FigureStyleAxes(ax, F);
xlabel(ax, 'Turning angle (deg)');
ylabel(ax, 'Count');
title(ax, titleText, ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');
xlim(ax, [-180 180]);

SPT_FigureEnsureDir(outDir);
out = SPT_FigureSavePair(fig, fullfile(outDir, baseName), F);
close(fig);

end

% =====================================================================
function out = localGroupedDensity(angleByState, nStates, xLabelText, baseName, outDir, F, stateColors)
out = struct('PNGFile', '', 'PDFFile', '');

nbins = round(F.TurningAngleBins);
if ~isfinite(nbins) || nbins < 12
    nbins = 72;
end

edges = linspace(-180, 180, nbins + 1);
centers = (edges(1:end-1) + edges(2:end)) / 2;
binWidth = edges(2) - edges(1);

D = zeros(nbins, nStates);

for k = 1:nStates
    ang = angleByState{k};
    if isempty(ang)
        continue;
    end

    ang = ang(:);
    ang = ang(isfinite(ang));
    if isempty(ang)
        continue;
    end

    c = SPT_FigureHistcountsCompat(ang, edges);
    total = sum(c);
    if total > 0 && isfinite(binWidth) && binWidth > 0
        D(:, k) = c(:) ./ (total * binWidth);
    end
end

fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);
hold(ax, 'on');

for k = 1:nStates
    c = SPT_FigureStateColor(k, stateColors);
    bar(ax, centers, D(:, k), 1.0, ...
        'FaceColor', c, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.65);
end

SPT_FigureStyleAxes(ax, F);
xlabel(ax, xLabelText);
ylabel(ax, 'Density');
title(ax, 'Turning angle | state-resolved normalized density', ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');
xlim(ax, [-180 180]);

legendCells = cell(1, nStates);
for k = 1:nStates
    legendCells{k} = ['State ' num2str(k)];
end
legend(ax, legendCells, 'Location', 'best');

SPT_FigureEnsureDir(outDir);
out = SPT_FigureSavePair(fig, fullfile(outDir, baseName), F);
close(fig);

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
function base = localBaseName(basePath)
[~, base, ~] = fileparts(basePath);
end

% =====================================================================
function angleByState = localAnglesByState(TA, nStates)
angleByState = cell(nStates, 1);

if isfield(TA, 'Table') && istable(TA.Table) && ismember('Angle_deg', TA.Table.Properties.VariableNames)
    if ismember('State', TA.Table.Properties.VariableNames)
        st = TA.Table.State;
    elseif ismember('state', TA.Table.Properties.VariableNames)
        st = TA.Table.state;
    else
        st = [];
    end

    if ~isempty(st)
        for k = 1:nStates
            idx = (st == k);
            angleByState{k} = TA.Table.Angle_deg(idx);
        end
    end
end

end

% =====================================================================
function nStates = localInferNStates(Project, TA)
if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
elseif isfield(TA, 'ByState') && ~isempty(TA.ByState)
    nStates = numel(TA.ByState);
else
    nStates = 1;
end
end

% =====================================================================
function y = localSmoothVector(x, sigma)
x = x(:);

if nargin < 2 || isempty(sigma) || ~isfinite(sigma) || sigma <= 0
    y = x;
    return;
end

halfWidth = max(1, ceil(3 * sigma));
t = -halfWidth:halfWidth;
k = exp(-(t.^2) / (2 * sigma^2));
k = k / sum(k);

y = conv(x, k(:), 'same');
end


% =====================================================================
function angles = localExtractAngleAll(TA)
% Extract all turning angles from TurningAngle analysis.

angles = [];

if isfield(TA, 'Ensemble') && ~isempty(TA.Ensemble)
    E = TA.Ensemble;

    if isfield(E, 'Angles_deg') && ~isempty(E.Angles_deg)
        angles = E.Angles_deg(:);
        return;
    end

    if isfield(E, 'Angle_deg') && ~isempty(E.Angle_deg)
        angles = E.Angle_deg(:);
        return;
    end

    if isfield(E, 'Angle') && ~isempty(E.Angle)
        angles = E.Angle(:);
        return;
    end
end

if isfield(TA, 'Table') && istable(TA.Table)
    T = TA.Table;
    if ismember('Angle_deg', T.Properties.VariableNames)
        angles = T.Angle_deg(:);
    elseif ismember('Angle', T.Properties.VariableNames)
        angles = T.Angle(:);
    elseif ismember('angle_deg', T.Properties.VariableNames)
        angles = T.angle_deg(:);
    elseif ismember('angle', T.Properties.VariableNames)
        angles = T.angle(:);
    end
end

if isempty(angles)
    angles = [];
end

end