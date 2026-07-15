function Config = VB3_Config()

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% VB3 Companion Toolbox v4.1
%
% Configuration file
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config = struct();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% General
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.Version = 'VB3 Companion Toolbox v4.1';

Config.Verbose = true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Trajectory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Must be identical to runinput.m

Config.MinTrajectoryLength = 10;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% MSD
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.MSD.MaxLag = 100;

Config.MSD.Dimension = 2;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Turning Angle
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.TurningAngle.Bin = 20; % 5 is the default

Config.TurningAngle.Range = [-180 180];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Confinement
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.Confinement.Window = 20;

Config.Confinement.MinPoints = 10;

Config.Confinement.CalculateRadiusGyration = true;

Config.Confinement.CalculateConvexHull = true;

Config.Confinement.CalculatePackingCoefficient = true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Figures
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ============================================================
% Figure Framework v2 frozen config
% ============================================================
Config.Figure = struct();

Config.Figure.SavePNG = true;
Config.Figure.SavePDF = false;
Config.Figure.DPI = 300;

Config.Figure.ExportAllTracks = false;
Config.Figure.MaxPreview = 12;

Config.Figure.ShowStart = true;
Config.Figure.ShowEnd = true;
Config.Figure.ShowState = true;
Config.Figure.ShowScaleBar = true;
Config.Figure.ShowStateSwitch = true;
Config.Figure.ShowTrackID = true;
Config.Figure.ShowLegend = true;
Config.Figure.TimeGradient = false;

Config.Figure.StartMarker = 'o';
Config.Figure.EndMarker = 's';
Config.Figure.SwitchMarker = 'p';

Config.Figure.LineWidth = 1.8;
Config.Figure.MarkerSize = 8;

Config.Figure.BackgroundColor = [1 1 1];
Config.Figure.StartColor = [0.10 0.70 0.20];
Config.Figure.EndColor = [0.85 0.10 0.10];
Config.Figure.SwitchColor = [0.95 0.75 0.10];

Config.Figure.FontName = 'Arial';
Config.Figure.FontSize = 10;
Config.Figure.TitleFontSize = 11;
Config.Figure.AxisLineWidth = 1.0;

Config.Figure.Palette = 'parula';

Config.Figure.HeatmapBins = 80;
Config.Figure.NormalizeHeatmap = true;
Config.Figure.UseLogHeatmap = false;
Config.Figure.HeatmapSmoothing = 0.8;

Config.Figure.TurningAngleBins = 72;

Config.Figure.ConfBins = 40;
Config.Figure.ConfProfilePreview = 12;

% Optional: kept for color fallback
Config.ColorMap = lines(20);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Heatmap
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.Heatmap.Bins = 50;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Batch
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.Batch.SaveProject = true;

Config.Batch.ExportCSV = true;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Color map
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.ColorMap = lines(20);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Statistics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Config.Statistics.Alpha = 0.05;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Display
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');

fprintf('=========================================\n');

fprintf(' VB3 Companion Toolbox v4.1\n');

fprintf(' Configuration Loaded\n');

fprintf('=========================================\n');

fprintf('Minimum trajectory length : %d\n',Config.MinTrajectoryLength);

fprintf('Heatmap bins             : %d\n',Config.Heatmap.Bins);

fprintf('Save PNG                 : %d\n',Config.Figure.SavePNG);

fprintf('Save PDF                 : %d\n',Config.Figure.SavePDF);

fprintf('Turning Angle Bin        : %d degree\n',Config.TurningAngle.Bin);

fprintf('MSD Max Lag              : %d\n',Config.MSD.MaxLag);

fprintf('=========================================\n');