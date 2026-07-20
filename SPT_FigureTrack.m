function figures = SPT_FigureTrack(Project, F, trackDir, maxPreview, stateColors)
% SPT_FigureTrack
% Figure Framework v2
% Frozen version
% MATLAB R2016b compatible

figures = struct([]);

if ~isfield(Project, 'Dataset') || isempty(Project.Dataset) || ...
        ~isfield(Project.Dataset, 'Trajectory') || ~iscell(Project.Dataset.Trajectory)
    return;
end

Dataset = Project.Dataset;
nTraj = numel(Dataset.Trajectory);

nPreview = min(maxPreview, nTraj);
if nPreview == 0
    figures = struct([]);
    return;
end

figures = repmat(struct( ...
    'DatasetIndex', [], ...
    'RawIndex', [], ...
    'Tid', [], ...
    'NPoints', [], ...
    'NStates', [], ...
    'BaseName', '', ...
    'PNGFile', '', ...
    'PDFFile', ''), nPreview, 1);

for i = 1:nPreview

    trj = Dataset.Trajectory{i};

    state = [];
    if isfield(Dataset, 'State') && numel(Dataset.State) >= i
        state = Dataset.State{i};
    end

    if isempty(trj) || isempty(state)
        continue;
    end

    [x, y] = SPT_FigureExtractXY(trj);
    x = x(:);
    y = y(:);
    state = state(:);

    n = min(numel(x), numel(state));
    if n < 2
        continue;
    end

    x = x(1:n);
    y = y(1:n);
    state = state(1:n);

    tid = localGetTid(Dataset, i);
    rawIndex = localGetRawIndex(Dataset, i);

    fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
    ax = axes('Parent', fig);
    hold(ax, 'on');

    if F.ShowState
        for j = 1:(n-1)
            c = SPT_FigureStateColor(state(j), stateColors);
            plot(ax, x(j:j+1), y(j:j+1), '-', ...
                'Color', c, ...
                'LineWidth', F.LineWidth);
        end
    else
        plot(ax, x, y, '-', ...
            'Color', [0.25 0.25 0.25], ...
            'LineWidth', F.LineWidth);
    end

    if F.ShowStart
        plot(ax, x(1), y(1), F.StartMarker, ...
            'MarkerSize', F.MarkerSize, ...
            'MarkerFaceColor', F.StartColor, ...
            'MarkerEdgeColor', [0 0 0], ...
            'LineWidth', 1.0);
    end

    if F.ShowEnd
        plot(ax, x(end), y(end), F.EndMarker, ...
            'MarkerSize', F.MarkerSize, ...
            'MarkerFaceColor', F.EndColor, ...
            'MarkerEdgeColor', [0 0 0], ...
            'LineWidth', 1.0);
    end

    if F.ShowStateSwitch
        swIdx = find(diff(state) ~= 0) + 1;
        if ~isempty(swIdx)
            plot(ax, x(swIdx), y(swIdx), F.SwitchMarker, ...
                'MarkerSize', F.SwitchMarkerSize, ...
                'MarkerFaceColor', F.SwitchColor, ...
                'MarkerEdgeColor', [0 0 0], ...
                'LineWidth', 1.0);
        end
    end

    if F.ShowTrackID
        dx = max(x) - min(x);
        if dx == 0, dx = 1; end
        dy = max(y) - min(y);
        if dy == 0, dy = 1; end
        text(ax, min(x) + 0.03*dx, max(y) - 0.05*dy, sprintf('Tid %d', tid), ...
            'FontName', F.FontName, ...
            'FontSize', F.FontSize, ...
            'FontWeight', 'bold', ...
            'Color', [0 0 0]);
    end

    if F.ShowScaleBar
        localAddScaleBar(ax, x, y, F);
    end

    axis(ax, 'equal');
    box(ax, 'on');
    set(ax, ...
        'FontName', F.FontName, ...
        'FontSize', F.FontSize, ...
        'LineWidth', F.AxisLineWidth, ...
        'TickDir', 'out', ...
        'Color', F.BackgroundColor);

    xlabel(ax, 'x');
    ylabel(ax, 'y');
    title(ax, sprintf('Track %d | Tid = %d | N = %d', i, tid, n), ...
        'FontName', F.FontName, ...
        'FontSize', F.TitleFontSize, ...
        'FontWeight', 'bold');

    if F.ShowLegend
        h1 = plot(ax, nan, nan, '-', 'Color', [0.25 0.25 0.25], 'LineWidth', F.LineWidth);
        h2 = plot(ax, nan, nan, F.StartMarker, ...
            'MarkerSize', F.MarkerSize, ...
            'MarkerFaceColor', F.StartColor, ...
            'MarkerEdgeColor', [0 0 0]);
        h3 = plot(ax, nan, nan, F.EndMarker, ...
            'MarkerSize', F.MarkerSize, ...
            'MarkerFaceColor', F.EndColor, ...
            'MarkerEdgeColor', [0 0 0]);
        h4 = plot(ax, nan, nan, F.SwitchMarker, ...
            'MarkerSize', F.SwitchMarkerSize, ...
            'MarkerFaceColor', F.SwitchColor, ...
            'MarkerEdgeColor', [0 0 0]);

        legend(ax, [h1 h2 h3 h4], ...
            {'Track', 'Start', 'End', 'Switch'}, ...
            'Location', 'best');
    end

    baseName = sprintf('track_%03d_tid_%d', i, tid);
    pngFile = '';
    pdfFile = '';

    if F.SavePNG
        pngFile = fullfile(trackDir, [baseName '.png']);
        print(fig, pngFile, '-dpng', ['-r' num2str(F.DPI)]);
    end

    if F.SavePDF
        pdfFile = fullfile(trackDir, [baseName '.pdf']);
        try
            print(fig, pdfFile, '-dpdf', '-painters');
        catch ME
            warning('PDF export failed for %s: %s', baseName, ME.message);
            pdfFile = '';
        end
    end

    figures(i).DatasetIndex = i;
    figures(i).RawIndex = rawIndex;
    figures(i).Tid = tid;
    figures(i).NPoints = n;
    figures(i).NStates = numel(unique(state));
    figures(i).BaseName = baseName;
    figures(i).PNGFile = pngFile;
    figures(i).PDFFile = pdfFile;

    close(fig);
end

end

% =====================================================================
function localAddScaleBar(ax, x, y, F)
% Draw a simple scale bar in data units.

xmin = min(x);
xmax = max(x);
ymin = min(y);
ymax = max(y);

dx = xmax - xmin;
if dx == 0
    dx = 1;
end

dy = ymax - ymin;
if dy == 0
    dy = 1;
end

barLen = F.ScaleBarLength;

if ~isfinite(barLen) || barLen <= 0
    barLen = 0.5;
end

x0 = xmax - 0.08 * dx - barLen;
x1 = x0 + barLen;
y0 = ymin + 0.08 * dy;

plot(ax, [x0 x1], [y0 y0], '-', ...
    'Color', [0 0 0], ...
    'LineWidth', 2.0);

plot(ax, [x0 x0], [y0 - 0.01*dy, y0 + 0.01*dy], '-', ...
    'Color', [0 0 0], ...
    'LineWidth', 2.0);

plot(ax, [x1 x1], [y0 - 0.01*dy, y0 + 0.01*dy], '-', ...
    'Color', [0 0 0], ...
    'LineWidth', 2.0);

if barLen < 1

    label = sprintf('%d nm', round(barLen*1000));

else

    label = sprintf('%.1f \\mum', barLen);

end

text(ax, (x0 + x1) / 2, y0 - 0.04 * dy, ...
    label, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', ...
    'FontName', F.FontName, ...
    'FontSize', F.FontSize - 1, ...
    'Color', [0 0 0]);

end

% =====================================================================
function tid = localGetTid(Dataset, i)
% Extract trajectory ID if available.

tid = i;

if isfield(Dataset, 'Tid') && numel(Dataset.Tid) >= i && ~isempty(Dataset.Tid(i))
    tid = Dataset.Tid(i);
elseif isfield(Dataset, 'tid') && numel(Dataset.tid) >= i && ~isempty(Dataset.tid(i))
    tid = Dataset.tid(i);
elseif isfield(Dataset, 'TrackID') && numel(Dataset.TrackID) >= i && ~isempty(Dataset.TrackID(i))
    tid = Dataset.TrackID(i);
end

end

% =====================================================================
function rawIndex = localGetRawIndex(Dataset, i)
% Extract raw index if available.

rawIndex = i;

if isfield(Dataset, 'RawIndex') && numel(Dataset.RawIndex) >= i && ~isempty(Dataset.RawIndex(i))
    rawIndex = Dataset.RawIndex(i);
elseif isfield(Dataset, 'rawIndex') && numel(Dataset.rawIndex) >= i && ~isempty(Dataset.rawIndex(i))
    rawIndex = Dataset.rawIndex(i);
elseif isfield(Dataset, 'SourceIndex') && numel(Dataset.SourceIndex) >= i && ~isempty(Dataset.SourceIndex(i))
    rawIndex = Dataset.SourceIndex(i);
end

end