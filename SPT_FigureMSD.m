function figures = SPT_FigureMSD(Project, F, msdCurveDir, msdFitDir)
% SPT_FigureMSD
% Figure Framework v2
% Frozen version
% MATLAB R2016b compatible

figures = struct([]);

if ~isfield(Project, 'Analysis') || ~isfield(Project.Analysis, 'MSD') || isempty(Project.Analysis.MSD)
    return;
end

MSD = Project.Analysis.MSD;

if ~isfield(MSD, 'Ensemble') || isempty(MSD.Ensemble)
    return;
end

E = MSD.Ensemble;

if ~isfield(E, 'Time_s') || ~isfield(E, 'PooledMSD')
    return;
end

t = E.Time_s(:);
y = E.PooledMSD(:);

valid = isfinite(t) & isfinite(y);
t = t(valid);
y = y(valid);

if isempty(t)
    return;
end

yMean = [];
if isfield(E, 'TrajectoryMeanMSD') && ~isempty(E.TrajectoryMeanMSD)
    yMean = E.TrajectoryMeanMSD(:);
    yMean = yMean(1:min(numel(yMean), numel(t)));
end

ySEM = [];
if isfield(E, 'TrajectorySEMMSD') && ~isempty(E.TrajectorySEMMSD)
    ySEM = E.TrajectorySEMMSD(:);
    ySEM = ySEM(1:min(numel(ySEM), numel(t)));
end

% ------------------------------------------------------------
% 1) MSD curve figure
% ------------------------------------------------------------
fig = figure('Visible', 'off', 'Color', F.BackgroundColor);
ax = axes('Parent', fig);
hold(ax, 'on');

if ~isempty(ySEM)
    n = min(numel(y), numel(ySEM));
    tt = t(1:n);
    yy = y(1:n);
    ee = ySEM(1:n);

    xBand = [tt; flipud(tt)];
    yBand = [yy - ee; flipud(yy + ee)];

    fill(ax, xBand, yBand, [0.75 0.85 1.00], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.40);
end

plot(ax, t, y, '-o', ...
    'Color', [0 0 0], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 4, ...
    'MarkerFaceColor', [0.15 0.15 0.15]);

if ~isempty(yMean)
    n2 = min(numel(yMean), numel(t));
    plot(ax, t(1:n2), yMean(1:n2), '-s', ...
        'Color', [0.10 0.35 0.85], ...
        'LineWidth', 1.4, ...
        'MarkerSize', 4, ...
        'MarkerFaceColor', [0.10 0.35 0.85]);
end

SPT_FigureStyleAxes(ax, F);
xlabel(ax, 'Lag time (s)');
ylabel(ax, 'MSD');
title(ax, 'Mean squared displacement', ...
    'FontName', F.FontName, ...
    'FontSize', F.TitleFontSize, ...
    'FontWeight', 'bold');

legendCells = {'Pooled MSD'};
if ~isempty(ySEM)
    legendCells{end+1} = 'Pooled MSD \pm SEM';
end
if ~isempty(yMean)
    legendCells{end+1} = 'Trajectory mean MSD';
end
legend(ax, legendCells, 'Location', 'best');

SPT_FigureEnsureDir(msdCurveDir);
out = SPT_FigureSavePair(fig, fullfile(msdCurveDir, 'msd_curve'), F);

figures(end+1).Name = 'msd_curve'; %#ok<AGROW>
figures(end).PNGFile = out.PNGFile;
figures(end).PDFFile = out.PDFFile;

close(fig);

% ------------------------------------------------------------
% 2) MSD fit figure
% ------------------------------------------------------------
hasLinearFit = isfield(MSD, 'Fit') && isfield(MSD.Fit, 'Linear') && isstruct(MSD.Fit.Linear);
hasPowerFit  = isfield(MSD, 'Fit') && isfield(MSD.Fit, 'PowerLaw') && isstruct(MSD.Fit.PowerLaw);

if hasLinearFit || hasPowerFit
    fig = figure('Visible', 'off', 'Color', F.BackgroundColor);

    ax1 = subplot(2, 1, 1, 'Parent', fig);
    hold(ax1, 'on');

    plot(ax1, t, y, '-o', ...
        'Color', [0 0 0], ...
        'LineWidth', 1.6, ...
        'MarkerSize', 4, ...
        'MarkerFaceColor', [0.15 0.15 0.15]);

    fitText = '';

    if hasLinearFit
        LF = MSD.Fit.Linear;

        if isfield(LF, 'Slope') && isfield(LF, 'Intercept') && ...
                isfinite(LF.Slope) && isfinite(LF.Intercept)
            yfit = LF.Slope * t + LF.Intercept;
            plot(ax1, t, yfit, '--', ...
                'Color', [0.85 0.10 0.10], ...
                'LineWidth', 1.8);
        end

        if isfield(LF, 'D') && isfinite(LF.D)
            fitText = [fitText sprintf('D = %.4g\n', LF.D)];
        end
        if isfield(LF, 'R2') && isfinite(LF.R2)
            fitText = [fitText sprintf('R^2 = %.4f\n', LF.R2)];
        end
    end

    if hasPowerFit
        PF = MSD.Fit.PowerLaw;

        if isfield(PF, 'A') && isfield(PF, 'Alpha') && ...
                isfinite(PF.A) && isfinite(PF.Alpha)
            ypow = PF.A * (t .^ PF.Alpha);
            plot(ax1, t, ypow, ':', ...
                'Color', [0.10 0.35 0.85], ...
                'LineWidth', 1.8);
        end

        if isfield(PF, 'Alpha') && isfinite(PF.Alpha)
            fitText = [fitText sprintf('alpha = %.4f\n', PF.Alpha)];
        end
    end

    if ~isempty(fitText)
        xl = xlim(ax1);
        yl = ylim(ax1);
        text(ax1, xl(1) + 0.05 * (xl(2) - xl(1)), ...
            yl(2) - 0.10 * (yl(2) - yl(1)), ...
            fitText, ...
            'FontName', F.FontName, ...
            'FontSize', F.FontSize, ...
            'VerticalAlignment', 'top', ...
            'BackgroundColor', [1 1 1], ...
            'EdgeColor', [0.7 0.7 0.7]);
    end

    SPT_FigureStyleAxes(ax1, F);
    xlabel(ax1, 'Lag time (s)');
    ylabel(ax1, 'MSD');
    title(ax1, 'MSD fit', ...
        'FontName', F.FontName, ...
        'FontSize', F.TitleFontSize, ...
        'FontWeight', 'bold');

    legend1 = {'Pooled MSD'};
    if hasLinearFit
        legend1{end+1} = 'Linear fit';
    end
    if hasPowerFit
        legend1{end+1} = 'Power-law fit';
    end
    legend(ax1, legend1, 'Location', 'best');

    ax2 = subplot(2, 1, 2, 'Parent', fig);
    hold(ax2, 'on');

    if hasLinearFit && isfield(MSD.Fit.Linear, 'Slope') && isfield(MSD.Fit.Linear, 'Intercept') && ...
            isfinite(MSD.Fit.Linear.Slope) && isfinite(MSD.Fit.Linear.Intercept)

        yfit = MSD.Fit.Linear.Slope * t + MSD.Fit.Linear.Intercept;
        resid = y - yfit;

        plot(ax2, t, resid, '-o', ...
            'Color', [0.25 0.25 0.25], ...
            'LineWidth', 1.2, ...
            'MarkerSize', 4, ...
            'MarkerFaceColor', [0.25 0.25 0.25]);

        plot(ax2, [min(t) max(t)], [0 0], '-', ...
            'Color', [0.85 0.10 0.10], ...
            'LineWidth', 1.2);

        ylabel(ax2, 'Residual');
    else
        plot(ax2, t, y, '-o', ...
            'Color', [0.25 0.25 0.25], ...
            'LineWidth', 1.2, ...
            'MarkerSize', 4, ...
            'MarkerFaceColor', [0.25 0.25 0.25]);
        ylabel(ax2, 'MSD');
    end

    SPT_FigureStyleAxes(ax2, F);
    xlabel(ax2, 'Lag time (s)');
    title(ax2, 'Fit residuals', ...
        'FontName', F.FontName, ...
        'FontSize', F.TitleFontSize, ...
        'FontWeight', 'bold');

    SPT_FigureEnsureDir(msdFitDir);
    out = SPT_FigureSavePair(fig, fullfile(msdFitDir, 'msd_fit'), F);

    figures(end+1).Name = 'msd_fit'; %#ok<AGROW>
    figures(end).PNGFile = out.PNGFile;
    figures(end).PDFFile = out.PDFFile;

    close(fig);
end

end

% =====================================================================
function localPlotResidual(ax, t, y, MSD)
% Plot residuals for the linear MSD fit when available.

resid = localComputeResidual(MSD, t, y);

if isempty(resid)
    plot(ax, t, y, '-o', ...
        'Color', [0.25 0.25 0.25], ...
        'LineWidth', 1.2, ...
        'MarkerSize', 4, ...
        'MarkerFaceColor', [0.25 0.25 0.25]);
    ylabel(ax, 'MSD');
    return;
end

plot(ax, t, resid, '-o', ...
    'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.2, ...
    'MarkerSize', 4, ...
    'MarkerFaceColor', [0.25 0.25 0.25]);

plot(ax, [min(t) max(t)], [0 0], '-', ...
    'Color', [0.85 0.10 0.10], ...
    'LineWidth', 1.2);

ylabel(ax, 'Residual');

end