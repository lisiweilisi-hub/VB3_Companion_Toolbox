function Project = SPT_Figures(Project, Config, outputDir, maxPreview)
% SPT_Figures
% Figure Framework v2
% Frozen dispatcher
% MATLAB R2016b compatible

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.2\n');
fprintf(' SPT Figures\n');
fprintf('=====================================================\n');

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

if ~isfield(Project, 'Dataset') || isempty(Project.Dataset) || ...
        ~isfield(Project.Dataset, 'Trajectory') || isempty(Project.Dataset.Trajectory)
    error('Project.Dataset is empty.');
end

F = SPT_FigureConfig(Config);

if nargin < 3 || isempty(outputDir)
    if isfield(Project, 'Export') && isfield(Project.Export, 'FigureFolder') && ~isempty(Project.Export.FigureFolder)
        outputDir = Project.Export.FigureFolder;
    else
        outputDir = pwd;
    end
end

figRoot = outputDir;
dirs.TrackPreview        = fullfile(figRoot, 'Track', 'Preview');
dirs.HeatmapOverall      = fullfile(figRoot, 'Heatmap', 'Overall');
dirs.HeatmapState        = fullfile(figRoot, 'Heatmap', 'State');
dirs.MSDCurve            = fullfile(figRoot, 'MSD', 'Curve');
dirs.MSDFit              = fullfile(figRoot, 'MSD', 'Fit');
dirs.TurningAngleOverall = fullfile(figRoot, 'TurningAngle', 'Overall');
dirs.TurningAngleState   = fullfile(figRoot, 'TurningAngle', 'State');
dirs.ConfinementOverall  = fullfile(figRoot, 'Confinement', 'Overall');
dirs.ConfinementGrouped  = fullfile(figRoot, 'Confinement', 'Grouped');
dirs.ConfinementState    = fullfile(figRoot, 'Confinement', 'State');
dirs.ConfinementProfile  = fullfile(figRoot, 'Confinement', 'Profile');
dirs.PublicationSummary  = fullfile(figRoot, 'Publication', 'Summary');
dirs.PublicationOverview = fullfile(figRoot, 'Publication', 'Overview');

names = fieldnames(dirs);
for i = 1:numel(names)
    SPT_FigureEnsureDir(dirs.(names{i}));
end

if ~isfield(Project, 'Export') || ~isstruct(Project.Export)
    Project.Export = struct();
end
Project.Export.FigureFolder = figRoot;

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;
dt = Dataset.dt;

if nargin < 4 || isempty(maxPreview)
    if F.ExportAllTracks
        maxPreview = nTraj;
    else
        maxPreview = min(F.MaxPreview, nTraj);
    end
end

[stateColors, nStates] = SPT_FigureColors(Project, Config);

if ~isfield(Project, 'Figures') || ~isstruct(Project.Figures)
    Project.Figures = struct();
end
Project.Figures.Track = [];
Project.Figures.Heatmap = [];
Project.Figures.MSD = [];
Project.Figures.TurningAngle = [];
Project.Figures.Confinement = [];
Project.Figures.Publication = [];

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Number of states       : %d\n', nStates);
fprintf('Preview tracks         : %d\n', min(maxPreview, nTraj));
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');

fprintf('Creating track previews ...\n');
Project.Figures.Track = SPT_FigureTrack(Project, F, dirs.TrackPreview, maxPreview, stateColors);

fprintf('Creating heatmaps ...\n');
Project.Figures.Heatmap = SPT_FigureHeatmap(Project, F, dirs.HeatmapOverall, dirs.HeatmapState);

fprintf('Creating MSD figures ...\n');
Project.Figures.MSD = SPT_FigureMSD(Project, F, dirs.MSDCurve, dirs.MSDFit);

fprintf('Creating turning-angle figures ...\n');
Project.Figures.TurningAngle = SPT_FigureTurningAngle(Project, F, dirs.TurningAngleOverall, dirs.TurningAngleState, stateColors);

fprintf('Creating confinement figures ...\n');
Project.Figures.Confinement = SPT_FigureConfinement(Project, F, dirs.ConfinementOverall, dirs.ConfinementGrouped, dirs.ConfinementState, dirs.ConfinementProfile, stateColors);

fprintf('Creating publication summary figures ...\n');
Project.Figures.Publication = SPT_FigurePublication(Project, F, dirs.PublicationSummary, dirs.PublicationOverview, stateColors);

Project.Flags.Figures = true;

fprintf('\n');
fprintf('Figures saved to : %s\n', figRoot);
fprintf('\n');
fprintf('Figure generation completed successfully.\n');
fprintf('=====================================================\n');

end