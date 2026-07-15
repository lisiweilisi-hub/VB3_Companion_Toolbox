function F = SPT_FigureConfig(Config)
% SPT_FigureConfig
% Figure Framework v2 frozen config parser.
% MATLAB R2016b compatible.

F = struct();

if nargin < 1 || isempty(Config) || ~isstruct(Config)
    Config = struct();
end

if ~isfield(Config, 'Figure') || ~isstruct(Config.Figure)
    Config.Figure = struct();
end

FG = Config.Figure;

% ------------------------------------------------------------
% Export / rendering
% ------------------------------------------------------------
F.SavePNG = getFieldOrDefault(FG, 'SavePNG', true);
F.SavePDF = getFieldOrDefault(FG, 'SavePDF', false);
F.DPI = getFieldOrDefault(FG, 'DPI', 300);

% ------------------------------------------------------------
% Track preview
% ------------------------------------------------------------
F.ExportAllTracks = getFieldOrDefault(FG, 'ExportAllTracks', false);
F.MaxPreview = getFieldOrDefault(FG, 'MaxPreview', 12);

F.ShowStart = getFieldOrDefault(FG, 'ShowStart', true);
F.ShowEnd = getFieldOrDefault(FG, 'ShowEnd', true);
F.ShowState = getFieldOrDefault(FG, 'ShowState', true);
F.ShowScaleBar = getFieldOrDefault(FG, 'ShowScaleBar', true);
F.ShowStateSwitch = getFieldOrDefault(FG, 'ShowStateSwitch', true);
F.ShowTrackID = getFieldOrDefault(FG, 'ShowTrackID', true);
F.ShowLegend = getFieldOrDefault(FG, 'ShowLegend', true);
F.TimeGradient = getFieldOrDefault(FG, 'TimeGradient', false);

F.StartMarker = getFieldOrDefault(FG, 'StartMarker', 'o');
F.EndMarker = getFieldOrDefault(FG, 'EndMarker', 's');
F.SwitchMarker = getFieldOrDefault(FG, 'SwitchMarker', 'p');

F.LineWidth = getFieldOrDefault(FG, 'LineWidth', 1.8);
F.MarkerSize = getFieldOrDefault(FG, 'MarkerSize', 8);

F.BackgroundColor = getFieldOrDefault(FG, 'BackgroundColor', [1 1 1]);
F.StartColor = getFieldOrDefault(FG, 'StartColor', [0.10 0.70 0.20]);
F.EndColor = getFieldOrDefault(FG, 'EndColor', [0.85 0.10 0.10]);
F.SwitchColor = getFieldOrDefault(FG, 'SwitchColor', [0.95 0.75 0.10]);

% ------------------------------------------------------------
% Text / axes
% ------------------------------------------------------------
F.FontName = getFieldOrDefault(FG, 'FontName', 'Arial');
F.FontSize = getFieldOrDefault(FG, 'FontSize', 10);
F.TitleFontSize = getFieldOrDefault(FG, 'TitleFontSize', 11);
F.AxisLineWidth = getFieldOrDefault(FG, 'AxisLineWidth', 1.0);

% ------------------------------------------------------------
% Color / palette
% ------------------------------------------------------------
F.Palette = getFieldOrDefault(FG, 'Palette', 'parula');

% ------------------------------------------------------------
% Heatmap
% ------------------------------------------------------------
F.HeatmapBins = getFieldOrDefault(FG, 'HeatmapBins', 80);
F.NormalizeHeatmap = getFieldOrDefault(FG, 'NormalizeHeatmap', true);
F.UseLogHeatmap = getFieldOrDefault(FG, 'UseLogHeatmap', false);
F.HeatmapSmoothing = getFieldOrDefault(FG, 'HeatmapSmoothing', 0.8);

% ------------------------------------------------------------
% Turning angle
% ------------------------------------------------------------
F.TurningAngleBins = getFieldOrDefault(FG, 'TurningAngleBins', 72);

% ------------------------------------------------------------
% Confinement
% ------------------------------------------------------------
F.ConfBins = getFieldOrDefault(FG, 'ConfBins', 40);
F.ConfProfilePreview = getFieldOrDefault(FG, 'ConfProfilePreview', 12);

end

% =====================================================================
function val = getFieldOrDefault(S, fieldName, defaultVal)

val = defaultVal;

if isstruct(S) && isfield(S, fieldName)
    tmp = S.(fieldName);
    if ~isempty(tmp)
        val = tmp;
    end
end

end