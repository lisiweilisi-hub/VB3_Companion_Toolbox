function figures = SPT_FigureHeatmap(Project, F, heatOverallDir, heatStateDir)
% SPT_FigureHeatmap
% Figure Framework v2
% Frozen version
% MATLAB R2016b compatible

figures = struct([]);

if ~isfield(Project, 'Tables') || ~isfield(Project.Tables, 'Localization') || isempty(Project.Tables.Localization)
    return;
end

L = Project.Tables.Localization;
[x, y, s] = SPT_FigureGetLocalizationXYZS(L);

valid = isfinite(x) & isfinite(y) & isfinite(s);
x = x(valid);
y = y(valid);
s = s(valid);

if isempty(x)
    return;
end

nBins = round(F.HeatmapBins);
if ~isfinite(nBins) || nBins < 10
    nBins = 80;
end

[xEdges, yEdges] = SPT_FigureHeatmapEdges(x, y, nBins);

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = max(s);
end

Zall = SPT_FigureHeatmapMatrix( ...
    x, y, xEdges, yEdges, ...
    F.NormalizeHeatmap, ...
    F.UseLogHeatmap, ...
    F.HeatmapSmoothing);

Zstates = cell(nStates, 1);
countsPerState = zeros(nStates, 1);

for k = 1:nStates
    idx = (s == k);
    countsPerState(k) = sum(idx);

    if any(idx)
        Zstates{k} = SPT_FigureHeatmapMatrix( ...
            x(idx), y(idx), xEdges, yEdges, ...
            F.NormalizeHeatmap, ...
            F.UseLogHeatmap, ...
            F.HeatmapSmoothing);
    else
        Zstates{k} = zeros(numel(yEdges) - 1, numel(xEdges) - 1);
    end
end

allVals = Zall(:);
for k = 1:nStates
    allVals = [allVals; Zstates{k}(:)]; %#ok<AGROW>
end
allVals = allVals(isfinite(allVals));

if isempty(allVals)
    cmax = 1;
else
    cmax = max(allVals);
    if ~isfinite(cmax) || cmax <= 0
        cmax = 1;
    end
end

if F.UseLogHeatmap
    cbLabel = 'log_{10}(count + 1)';
elseif F.NormalizeHeatmap
    cbLabel = 'Normalized density';
else
    cbLabel = 'Counts';
end

% ------------------------------------------------------------
% Overall heatmap
% ------------------------------------------------------------
out = localPlotHeatmapFigure( ...
    Zall, xEdges, yEdges, ...
    sprintf('Overall localization heatmap (n = %d)', numel(x)), ...
    'overall_heatmap', heatOverallDir, F, cbLabel, cmax);

figures(end+1).Name = 'overall_heatmap'; %#ok<AGROW>
figures(end).PNGFile = out.PNGFile;
figures(end).PDFFile = out.PDFFile;

% ------------------------------------------------------------
% State-resolved heatmaps
% ------------------------------------------------------------
for k = 1:nStates
    if countsPerState(k) <= 0
        continue;
    end

    out = localPlotHeatmapFigure( ...
        Zstates{k}, xEdges, yEdges, ...
        sprintf('State %d heatmap (n = %d)', k, countsPerState(k)), ...
        ['state_' num2str(k) '_heatmap'], heatStateDir, F, cbLabel, cmax);

    figures(end+1).Name = ['state_' num2str(k) '_heatmap']; %#ok<AGROW>
    figures(end).PNGFile = out.PNGFile;
    figures(end).PDFFile = out.PDFFile;
    figures(end).State = k; %#ok<AGROW>
end

end

% =====================================================================
function out = localPlotHeatmapFigure(Z, xEdges, yEdges, titleText, ...
    baseName, outDir, F, cbLabel, cmax)
% Plot and save one heatmap figure.

out = struct('PNGFile','','PDFFile','');

fig = figure('Visible','off', ...
             'Color',F.BackgroundColor);

ax = axes('Parent',fig);

imagesc(ax,...
    [xEdges(1) xEdges(end)],...
    [yEdges(1) yEdges(end)],...
    Z);

set(ax,'YDir','normal');

axis(ax,'image');
box(ax,'on');

SPT_FigureStyleAxes(ax,F);

xlabel(ax,'x');
ylabel(ax,'y');

title(ax,titleText,...
    'FontName',F.FontName,...
    'FontSize',F.TitleFontSize,...
    'FontWeight','bold');

colormap(ax,F.Palette);

cb = colorbar(ax);
cb.Label.String = cbLabel;
cb.FontName = F.FontName;
cb.FontSize = F.FontSize;

caxis(ax,[0 cmax]);

SPT_FigureEnsureDir(outDir);

out = SPT_FigureSavePair(...
    fig,...
    fullfile(outDir,baseName),...
    F);

close(fig);

end