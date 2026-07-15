function Project = SPT_PlotTrajectory(Project, Config, outputDir, maxPreview)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_PlotTrajectory
%
% VB3 Companion Toolbox v4.1
%
% Plot trajectories with:
%   - state-colored segments
%   - green start marker
%   - red end marker
%
% Input
%   Project.Dataset
%   Project.Geometry (optional)
%
% Output
%   Project.Figures.Track
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT Plot Trajectory\n');
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

if ~isfield(Config, 'Figure') || ~isstruct(Config.Figure)
    Config.Figure = struct();
end

if ~isfield(Config.Figure, 'SavePNG') || isempty(Config.Figure.SavePNG)
    Config.Figure.SavePNG = true;
end

if ~isfield(Config.Figure, 'SavePDF') || isempty(Config.Figure.SavePDF)
    Config.Figure.SavePDF = false;
end

if ~isfield(Config.Figure, 'DPI') || isempty(Config.Figure.DPI)
    Config.Figure.DPI = 220;
end

if ~isfield(Config.Figure, 'ShowStart') || isempty(Config.Figure.ShowStart)
    Config.Figure.ShowStart = true;
end

if ~isfield(Config.Figure, 'ShowEnd') || isempty(Config.Figure.ShowEnd)
    Config.Figure.ShowEnd = true;
end

if ~isfield(Config.Figure, 'ShowState') || isempty(Config.Figure.ShowState)
    Config.Figure.ShowState = true;
end

if ~isfield(Config.Figure, 'LineWidth') || isempty(Config.Figure.LineWidth)
    Config.Figure.LineWidth = 1.5;
end

if ~isfield(Config.Figure, 'StartMarker') || isempty(Config.Figure.StartMarker)
    Config.Figure.StartMarker = 'o';
end

if ~isfield(Config.Figure, 'EndMarker') || isempty(Config.Figure.EndMarker)
    Config.Figure.EndMarker = 's';
end

if ~isfield(Config.Figure, 'MarkerSize') || isempty(Config.Figure.MarkerSize)
    Config.Figure.MarkerSize = 8;
end

if nargin < 3 || isempty(outputDir)
    if isfield(Project, 'Export') && isfield(Project.Export, 'FigureFolder') && ~isempty(Project.Export.FigureFolder)
        outputDir = Project.Export.FigureFolder;
    else
        outputDir = pwd;
    end
end

if nargin < 4 || isempty(maxPreview)
    maxPreview = min(12, Project.Dataset.nTraj);
end

if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

if ~isfield(Project, 'Export') || ~isstruct(Project.Export)
    Project.Export = struct();
end
Project.Export.FigureFolder = outputDir;

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
%% State Engine / colors
%% --------------------------------------------------------

if exist('VB3_StateEngine', 'file') == 2
    Engine = VB3_StateEngine(Project, Config);
    if isfield(Engine, 'Color') && ~isempty(Engine.Color)
        stateColors = Engine.Color;
    else
        stateColors = lines(max(nStates, 1));
    end
else
    stateColors = lines(max(nStates, 1));
end

%% --------------------------------------------------------
%% Initialization
%% --------------------------------------------------------

nPreview = min(maxPreview, nTraj);

TrackFigures = repmat(struct( ...
    'DatasetIndex', [], ...
    'RawIndex', [], ...
    'Tid', [], ...
    'NPoints', [], ...
    'NStates', [], ...
    'BaseName', '', ...
    'PNGFile', '', ...
    'PDFFile', ''), nPreview, 1);

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Preview tracks         : %d\n', nPreview);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building trajectory plots ...\n');

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

for i = 1:nPreview

    trj = Dataset.Trajectory{i};
    state = Dataset.State{i};
    tid = Dataset.Tid(i);
    rawIndex = Dataset.RawIndex(i);

    if isempty(trj) || isempty(state)
        continue
    end

    [x, y] = localExtractXY(trj);

    nPoint = numel(x);
    nStatePoint = numel(state);
    n = min(nPoint, nStatePoint);

    if n < 2
        continue
    end

    x = x(1:n);
    y = y(1:n);
    state = state(:);
    state = state(1:n);

    fig = figure('Visible', 'off', 'Color', 'w');
    ax = axes('Parent', fig);
    hold(ax, 'on');

    % State-colored segments
    if Config.Figure.ShowState
        for j = 1:(n-1)
            s = state(j);
            c = localStateColor(s, stateColors);
            plot(ax, x(j:j+1), y(j:j+1), '-', 'Color', c, 'LineWidth', Config.Figure.LineWidth);
        end
    else
        plot(ax, x, y, 'k-', 'LineWidth', Config.Figure.LineWidth);
    end

    % Start marker
    if Config.Figure.ShowStart
        plot(ax, x(1), y(1), Config.Figure.StartMarker, ...
            'MarkerSize', Config.Figure.MarkerSize, ...
            'MarkerFaceColor', [0.1 0.7 0.2], ...
            'MarkerEdgeColor', [0.0 0.5 0.1], ...
            'LineWidth', 1.0);
    end

    % End marker
    if Config.Figure.ShowEnd
        plot(ax, x(end), y(end), Config.Figure.EndMarker, ...
            'MarkerSize', Config.Figure.MarkerSize, ...
            'MarkerFaceColor', [0.85 0.1 0.1], ...
            'MarkerEdgeColor', [0.55 0.0 0.0], ...
            'LineWidth', 1.0);
    end

    axis(ax, 'equal');
    box(ax, 'on');
    xlabel(ax, 'x');
    ylabel(ax, 'y');
    title(ax, sprintf('Track %d | tid = %d | N = %d', i, tid, n));

    baseName = sprintf('track_%03d_tid_%d', i, tid);
    pngFile = '';
    pdfFile = '';

    if Config.Figure.SavePNG
        pngFile = fullfile(outputDir, [baseName '.png']);
        print(fig, pngFile, '-dpng', ['-r' num2str(Config.Figure.DPI)]);
    end

    if Config.Figure.SavePDF
        pdfFile = fullfile(outputDir, [baseName '.pdf']);
        try
            print(fig, pdfFile, '-dpdf', '-painters');
        catch ME
            warning('PDF export failed for %s: %s', baseName, ME.message);
            pdfFile = '';
        end
    end

    TrackFigures(i).DatasetIndex = i;
    TrackFigures(i).RawIndex = rawIndex;
    TrackFigures(i).Tid = tid;
    TrackFigures(i).NPoints = n;
    TrackFigures(i).NStates = nStates;
    TrackFigures(i).BaseName = baseName;
    TrackFigures(i).PNGFile = pngFile;
    TrackFigures(i).PDFFile = pdfFile;

    close(fig);

end

%% --------------------------------------------------------
%% Save
%% --------------------------------------------------------

Project.Figures.Track = TrackFigures;
Project.Flags.Figures = true;

fprintf('\n');
fprintf('Trajectory plots saved to : %s\n', outputDir);
fprintf('Preview tracks            : %d\n', nPreview);

fprintf('\n');
fprintf('Trajectory plot created successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function [x, y] = localExtractXY(trj)

if isempty(trj) || ~isnumeric(trj) || ~ismatrix(trj)
    x = [];
    y = [];
    return;
end

[r, c] = size(trj);

% Most vbSPT-derived trajectories in your data are N x 3
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
function c = localStateColor(state, stateColors)

if isempty(stateColors)
    c = [0 0 0];
    return;
end

nColor = size(stateColors, 1);

if state < 1 || isnan(state)
    c = [0 0 0];
    return;
end

idx = mod(state - 1, nColor) + 1;
c = stateColors(idx, :);

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