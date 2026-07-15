function Project = SPT_RunPipeline(inputMAT, hmmMAT, Config, outputDir)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_RunPipeline
%
% VB3 Companion Toolbox v4.1
%
% Main pipeline controller
%
% Pipeline:
%   VB3_ReadProject
%   VB3_CreateDataset
%   SPT_CreateGeometry (optional)
%   SPT_Localization
%   SPT_Segment
%   SPT_Track
%   SPT_State
%   Transition analysis
%   SPT_MSD (optional)
%   SPT_TurningAngle (optional)
%   SPT_Confinement (optional)
%   SPT_Figures (optional)
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT_RunPipeline\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

if nargin < 1 || isempty(inputMAT)
    error('inputMAT is required.');
end

if nargin < 2 || isempty(hmmMAT)
    error('hmmMAT is required.');
end

if nargin < 3 || isempty(Config)
    Config = VB3_Config();
end

if nargin < 4 || isempty(outputDir)
    outputDir = pwd;
end

if exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

csvDir = fullfile(outputDir, 'CSV');
figDir = fullfile(outputDir, 'Figures');
reportDir = fullfile(outputDir, 'Report');

ensureDir(csvDir);
ensureDir(figDir);
ensureDir(reportDir);

%% --------------------------------------------------------
%% Read project
%% --------------------------------------------------------

Project = VB3_ReadProject(inputMAT, hmmMAT);
Project.Config = Config;

Project.Export.OutputFolder = outputDir;
Project.Export.CSVFolder = csvDir;
Project.Export.FigureFolder = figDir;
Project.Export.ReportFolder = reportDir;

%% --------------------------------------------------------
%% Build dataset
%% --------------------------------------------------------

Project = VB3_CreateDataset(Project, Config);

%% --------------------------------------------------------
%% Geometry layer
%% --------------------------------------------------------

if exist('SPT_CreateGeometry', 'file') == 2
    Project = SPT_CreateGeometry(Project, Config);
else
    warning('SPT_CreateGeometry.m not found. Skipping Geometry layer.');
end

%% --------------------------------------------------------
%% Tables
%% --------------------------------------------------------

Project = SPT_Localization(Project, Config);
Project = SPT_Segment(Project, Config);
Project = SPT_Track(Project, Config);
Project = SPT_State(Project, Config);

%% --------------------------------------------------------
%% Transition analysis
%% --------------------------------------------------------

Project = buildTransitionAnalysis(Project);

%% --------------------------------------------------------
%% Analysis
%% --------------------------------------------------------

if exist('SPT_MSD', 'file') == 2
    Project = SPT_MSD(Project, Config);
else
    warning('SPT_MSD.m not found. Skipping MSD analysis.');
end

if exist('SPT_TurningAngle', 'file') == 2
    Project = SPT_TurningAngle(Project, Config);
else
    warning('SPT_TurningAngle.m not found. Skipping Turning Angle analysis.');
end

if exist('SPT_Confinement', 'file') == 2
    Project = SPT_Confinement(Project, Config);
else
    warning('SPT_Confinement.m not found. Skipping Confinement analysis.');
end

%% --------------------------------------------------------
%% Figures
%% --------------------------------------------------------

if exist('SPT_Figures', 'file') == 2
    maxPreview = getMaxPreview(Config, Project.Dataset.nTraj);
    Project = SPT_Figures(Project, Config, figDir, maxPreview);
else
    warning('SPT_Figures.m not found. Skipping figure generation.');
end

%% --------------------------------------------------------
%% Save outputs
%% --------------------------------------------------------

save(fullfile(outputDir, 'SPT_Project.mat'), 'Project', '-v7.3');

exportAllTables(Project, csvDir);
exportAnalysisTables(Project, csvDir);
writeReport(Project, reportDir, inputMAT, hmmMAT, outputDir);

Project.Flags.Export = true;

fprintf('\n');
fprintf('Project saved to      : %s\n', fullfile(outputDir, 'SPT_Project.mat'));
fprintf('CSV folder            : %s\n', csvDir);
fprintf('Figures folder        : %s\n', figDir);
fprintf('Report folder         : %s\n', reportDir);

fprintf('\n');
fprintf('SPT_RunPipeline completed successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function Project = buildTransitionAnalysis(Project)

if ~isfield(Project, 'Dataset') || ~isfield(Project.Dataset, 'State')
    warning('Project.Dataset.State not found. Transition analysis skipped.');
    return;
end

stateCell = Project.Dataset.State;
nTraj = numel(stateCell);

if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates') && Project.HMM.nStates > 0
    nStates = Project.HMM.nStates;
else
    nStates = inferNStatesFromStateCell(stateCell);
end

if nStates < 1
    nStates = 1;
end

CountMatrix = zeros(nStates, nStates);
nTotalTransitions = 0;

for i = 1:nTraj
    st = stateCell{i};
    if isempty(st)
        continue
    end

    st = st(:);
    if numel(st) < 2
        continue
    end

    for j = 1:(numel(st) - 1)
        a = st(j);
        b = st(j + 1);

        if a >= 1 && a <= nStates && b >= 1 && b <= nStates
            CountMatrix(a, b) = CountMatrix(a, b) + 1;
            nTotalTransitions = nTotalTransitions + 1;
        end
    end
end

ProbMatrix = zeros(nStates, nStates);

for i = 1:nStates
    rs = sum(CountMatrix(i, :));
    if rs > 0
        ProbMatrix(i, :) = CountMatrix(i, :) ./ rs;
    end
end

varNames = cell(1, nStates);
rowNames = cell(1, nStates);

for k = 1:nStates
    varNames{k} = ['State' num2str(k)];
    rowNames{k} = ['State' num2str(k)];
end

CountTable = array2table(CountMatrix, ...
    'VariableNames', varNames, ...
    'RowNames', rowNames);

ProbTable = array2table(ProbMatrix, ...
    'VariableNames', varNames, ...
    'RowNames', rowNames);

Transition = struct();
Transition.CountMatrix = CountMatrix;
Transition.ProbMatrix = ProbMatrix;
Transition.CountTable = CountTable;
Transition.ProbTable = ProbTable;
Transition.nTotalTransitions = nTotalTransitions;
Transition.nStates = nStates;

Project.Analysis.Transition = Transition;

if ~isfield(Project.Validation, 'TransitionOK')
    Project.Validation.TransitionOK = false;
end
Project.Validation.TransitionOK = true;

Project.Flags.Transition = true;

end

% =====================================================================
function exportAllTables(Project, csvDir)

if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'Mapping') && istable(Project.Dataset.Mapping)
    writeTableCSV(Project.Dataset.Mapping, fullfile(csvDir, 'Dataset_Mapping.csv'), false);
end

if isfield(Project, 'Tables') && isstruct(Project.Tables)

    if isfield(Project.Tables, 'Localization') && istable(Project.Tables.Localization)
        writeTableCSV(Project.Tables.Localization, fullfile(csvDir, 'LocalizationTable.csv'), false);
    end

    if isfield(Project.Tables, 'Segment') && istable(Project.Tables.Segment)
        writeTableCSV(Project.Tables.Segment, fullfile(csvDir, 'SegmentTable.csv'), false);
    end

    if isfield(Project.Tables, 'Track') && istable(Project.Tables.Track)
        writeTableCSV(Project.Tables.Track, fullfile(csvDir, 'TrackSummary.csv'), false);
    end

    if isfield(Project.Tables, 'State') && istable(Project.Tables.State)
        writeTableCSV(Project.Tables.State, fullfile(csvDir, 'StateStats.csv'), false);
    end

end

if isfield(Project, 'Analysis') && isstruct(Project.Analysis)

    if isfield(Project.Analysis, 'Transition') && isstruct(Project.Analysis.Transition)

        if isfield(Project.Analysis.Transition, 'CountTable') && istable(Project.Analysis.Transition.CountTable)
            writeTableCSV(Project.Analysis.Transition.CountTable, fullfile(csvDir, 'TransitionCountMatrix.csv'), true);
        end

        if isfield(Project.Analysis.Transition, 'ProbTable') && istable(Project.Analysis.Transition.ProbTable)
            writeTableCSV(Project.Analysis.Transition.ProbTable, fullfile(csvDir, 'TransitionProbMatrix.csv'), true);
        end

    end

    if isfield(Project.Analysis, 'MSD') && isstruct(Project.Analysis.MSD)
        T = msdEnsembleToTable(Project.Analysis.MSD);
        if ~isempty(T)
            writeTableCSV(T, fullfile(csvDir, 'MSD_Ensemble.csv'), false);
        end
        T = msdSummaryToTable(Project.Analysis.MSD);
        if ~isempty(T)
            writeTableCSV(T, fullfile(csvDir, 'MSD_Summary.csv'), false);
        end
    end

    if isfield(Project.Analysis, 'TurningAngle') && isstruct(Project.Analysis.TurningAngle)
        if isfield(Project.Analysis.TurningAngle, 'Table') && istable(Project.Analysis.TurningAngle.Table)
            writeTableCSV(Project.Analysis.TurningAngle.Table, fullfile(csvDir, 'TurningAngle_Table.csv'), false);
        end
        T = turningAngleSummaryToTable(Project.Analysis.TurningAngle);
        if ~isempty(T)
            writeTableCSV(T, fullfile(csvDir, 'TurningAngle_Summary.csv'), false);
        end
    end

    if isfield(Project.Analysis, 'Confinement') && isstruct(Project.Analysis.Confinement)
        if isfield(Project.Analysis.Confinement, 'Table') && istable(Project.Analysis.Confinement.Table)
            writeTableCSV(Project.Analysis.Confinement.Table, fullfile(csvDir, 'Confinement_Table.csv'), false);
        end
        T = confinementSummaryToTable(Project.Analysis.Confinement);
        if ~isempty(T)
            writeTableCSV(T, fullfile(csvDir, 'Confinement_Summary.csv'), false);
        end
    end

end

end

% =====================================================================
function exportAnalysisTables(Project, csvDir)
% kept for interface clarity; all export handled in exportAllTables
end

% =====================================================================
function T = msdEnsembleToTable(MSD)

T = table();

if ~isfield(MSD, 'Ensemble') || ~isstruct(MSD.Ensemble)
    return;
end

E = MSD.Ensemble;

if ~isfield(E, 'Lag') || isempty(E.Lag)
    return;
end

n = numel(E.Lag);

T.Lag = E.Lag(:);

if isfield(E, 'Time_s'), T.Time_s = padToLen(E.Time_s, n); end
if isfield(E, 'PooledMSD'), T.PooledMSD = padToLen(E.PooledMSD, n); end
if isfield(E, 'PooledMSD_X'), T.PooledMSD_X = padToLen(E.PooledMSD_X, n); end
if isfield(E, 'PooledMSD_Y'), T.PooledMSD_Y = padToLen(E.PooledMSD_Y, n); end
if isfield(E, 'TrajectoryMeanMSD'), T.TrajectoryMeanMSD = padToLen(E.TrajectoryMeanMSD, n); end
if isfield(E, 'TrajectorySEMMSD'), T.TrajectorySEMMSD = padToLen(E.TrajectorySEMMSD, n); end
if isfield(E, 'NPairs'), T.NPairs = padToLen(E.NPairs, n); end
if isfield(E, 'NTraj'), T.NTraj = padToLen(E.NTraj, n); end

end

% =====================================================================
function T = msdSummaryToTable(MSD)

T = table();

if ~isfield(MSD, 'Summary') || ~isstruct(MSD.Summary)
    return;
end

S = MSD.Summary;

vars = {};
vals = {};

if isfield(S, 'nTraj'), vars{end+1} = 'nTraj'; vals{end+1} = S.nTraj; end
if isfield(S, 'MaxLag'), vars{end+1} = 'MaxLag'; vals{end+1} = S.MaxLag; end
if isfield(S, 'Dimension'), vars{end+1} = 'Dimension'; vals{end+1} = S.Dimension; end
if isfield(S, 'dt'), vars{end+1} = 'dt'; vals{end+1} = S.dt; end
if isfield(MSD, 'Fit') && isfield(MSD.Fit, 'Linear')
    if isfield(MSD.Fit.Linear, 'D'), vars{end+1} = 'D'; vals{end+1} = MSD.Fit.Linear.D; end
    if isfield(MSD.Fit.Linear, 'R2'), vars{end+1} = 'R2'; vals{end+1} = MSD.Fit.Linear.R2; end
end
if isfield(MSD, 'Fit') && isfield(MSD.Fit, 'PowerLaw')
    if isfield(MSD.Fit.PowerLaw, 'Alpha'), vars{end+1} = 'Alpha'; vals{end+1} = MSD.Fit.PowerLaw.Alpha; end
    if isfield(MSD.Fit.PowerLaw, 'A'), vars{end+1} = 'A'; vals{end+1} = MSD.Fit.PowerLaw.A; end
end

if isempty(vars)
    return;
end

T = cell2table(vals, 'VariableNames', vars);

end

% =====================================================================
function T = turningAngleSummaryToTable(TA)

T = table();

if ~isfield(TA, 'Ensemble') || ~isstruct(TA.Ensemble)
    return;
end

E = TA.Ensemble;
vars = {};
vals = {};

if isfield(E, 'nAngles'), vars{end+1} = 'nAngles'; vals{end+1} = E.nAngles; end
if isfield(E, 'MeanAngle_deg'), vars{end+1} = 'MeanAngle_deg'; vals{end+1} = E.MeanAngle_deg; end
if isfield(E, 'MeanAbsAngle_deg'), vars{end+1} = 'MeanAbsAngle_deg'; vals{end+1} = E.MeanAbsAngle_deg; end
if isfield(E, 'ResultantLength'), vars{end+1} = 'ResultantLength'; vals{end+1} = E.ResultantLength; end
if isfield(E, 'CircularVariance'), vars{end+1} = 'CircularVariance'; vals{end+1} = E.CircularVariance; end

if isempty(vars)
    return;
end

T = cell2table(vals, 'VariableNames', vars);

end

% =====================================================================
function T = confinementSummaryToTable(CA)

T = table();

if ~isfield(CA, 'Ensemble') || ~isstruct(CA.Ensemble)
    return;
end

E = CA.Ensemble;
vars = {};
vals = {};

if isfield(E, 'nTraj'), vars{end+1} = 'nTraj'; vals{end+1} = E.nTraj; end
if isfield(E, 'nStates'), vars{end+1} = 'nStates'; vals{end+1} = E.nStates; end
if isfield(E, 'WindowSize'), vars{end+1} = 'WindowSize'; vals{end+1} = E.WindowSize; end
if isfield(E, 'MinPoints'), vars{end+1} = 'MinPoints'; vals{end+1} = E.MinPoints; end
if isfield(E, 'MeanRadiusOfGyration'), vars{end+1} = 'MeanRadiusOfGyration'; vals{end+1} = E.MeanRadiusOfGyration; end
if isfield(E, 'MeanConvexHullArea'), vars{end+1} = 'MeanConvexHullArea'; vals{end+1} = E.MeanConvexHullArea; end
if isfield(E, 'MeanPackingCoefficient'), vars{end+1} = 'MeanPackingCoefficient'; vals{end+1} = E.MeanPackingCoefficient; end
if isfield(E, 'MeanConfinementRatio'), vars{end+1} = 'MeanConfinementRatio'; vals{end+1} = E.MeanConfinementRatio; end
if isfield(E, 'MeanConfinementIndex'), vars{end+1} = 'MeanConfinementIndex'; vals{end+1} = E.MeanConfinementIndex; end

if isempty(vars)
    return;
end

T = cell2table(vals, 'VariableNames', vars);

end

% =====================================================================
function writeReport(Project, reportDir, inputMAT, hmmMAT, outputDir)

ensureDir(reportDir);
reportFile = fullfile(reportDir, 'VB3_Report.txt');

fid = fopen(reportFile, 'w');
if fid < 0
    warning('Could not write report file: %s', reportFile);
    return;
end

fprintf(fid, 'VB3 Companion Toolbox v4.1 Report\n');
fprintf(fid, '=================================\n\n');
fprintf(fid, 'Input MAT : %s\n', inputMAT);
fprintf(fid, 'HMM MAT   : %s\n', hmmMAT);
fprintf(fid, 'OutputDir  : %s\n\n', outputDir);

if isfield(Project, 'Info')
    if isfield(Project.Info, 'ProjectName')
        fprintf(fid, 'ProjectName : %s\n', Project.Info.ProjectName);
    end
    if isfield(Project.Info, 'Version')
        fprintf(fid, 'Version     : %s\n', Project.Info.Version);
    end
    if isfield(Project.Info, 'Software')
        fprintf(fid, 'Software    : %s\n', Project.Info.Software);
    end
end

fprintf(fid, '\n');

if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'Summary')
    S = Project.Dataset.Summary;
    if isfield(S, 'nTraj'), fprintf(fid, 'Dataset nTraj           : %d\n', S.nTraj); end
    if isfield(S, 'TotalLocalizations'), fprintf(fid, 'Total localizations     : %d\n', S.TotalLocalizations); end
    if isfield(S, 'MeanLength'), fprintf(fid, 'Mean length             : %.6g\n', S.MeanLength); end
    if isfield(S, 'MedianLength'), fprintf(fid, 'Median length           : %.6g\n', S.MedianLength); end
    if isfield(S, 'MinLength'), fprintf(fid, 'Min length              : %.6g\n', S.MinLength); end
    if isfield(S, 'MaxLength'), fprintf(fid, 'Max length              : %.6g\n', S.MaxLength); end
    if isfield(S, 'dt'), fprintf(fid, 'Time step (s)           : %.6g\n', S.dt); end
    if isfield(S, 'nStates'), fprintf(fid, 'nStates                 : %d\n', S.nStates); end
end

fprintf(fid, '\n');

if isfield(Project, 'Tables')
    if isfield(Project.Tables, 'Localization') && istable(Project.Tables.Localization)
        fprintf(fid, 'Localization rows       : %d\n', height(Project.Tables.Localization));
    end
    if isfield(Project.Tables, 'Segment') && istable(Project.Tables.Segment)
        fprintf(fid, 'Segment rows            : %d\n', height(Project.Tables.Segment));
    end
    if isfield(Project.Tables, 'Track') && istable(Project.Tables.Track)
        fprintf(fid, 'Track rows              : %d\n', height(Project.Tables.Track));
    end
    if isfield(Project.Tables, 'State') && istable(Project.Tables.State)
        fprintf(fid, 'State rows              : %d\n', height(Project.Tables.State));
    end
end

fprintf(fid, '\n');

if isfield(Project, 'Analysis')
    if isfield(Project.Analysis, 'Transition') && isstruct(Project.Analysis.Transition)
        if isfield(Project.Analysis.Transition, 'nTotalTransitions')
            fprintf(fid, 'Total transitions       : %d\n', Project.Analysis.Transition.nTotalTransitions);
        end
    end

    if isfield(Project.Analysis, 'MSD') && isstruct(Project.Analysis.MSD)
        if isfield(Project.Analysis.MSD, 'Fit') && isfield(Project.Analysis.MSD.Fit, 'Linear')
            if isfield(Project.Analysis.MSD.Fit.Linear, 'D')
                fprintf(fid, 'MSD D                   : %.6g\n', Project.Analysis.MSD.Fit.Linear.D);
            end
            if isfield(Project.Analysis.MSD.Fit.Linear, 'R2')
                fprintf(fid, 'MSD R2                  : %.6g\n', Project.Analysis.MSD.Fit.Linear.R2);
            end
        end
        if isfield(Project.Analysis.MSD, 'Fit') && isfield(Project.Analysis.MSD.Fit, 'PowerLaw')
            if isfield(Project.Analysis.MSD.Fit.PowerLaw, 'Alpha')
                fprintf(fid, 'MSD alpha               : %.6g\n', Project.Analysis.MSD.Fit.PowerLaw.Alpha);
            end
        end
    end

    if isfield(Project.Analysis, 'TurningAngle') && isstruct(Project.Analysis.TurningAngle)
        if isfield(Project.Analysis.TurningAngle, 'Ensemble')
            if isfield(Project.Analysis.TurningAngle.Ensemble, 'MeanAbsAngle_deg')
                fprintf(fid, 'Mean |angle| (deg)      : %.6g\n', Project.Analysis.TurningAngle.Ensemble.MeanAbsAngle_deg);
            end
        end
    end

    if isfield(Project.Analysis, 'Confinement') && isstruct(Project.Analysis.Confinement)
        if isfield(Project.Analysis.Confinement, 'Ensemble')
            if isfield(Project.Analysis.Confinement.Ensemble, 'MeanRadiusOfGyration')
                fprintf(fid, 'Mean Rg                 : %.6g\n', Project.Analysis.Confinement.Ensemble.MeanRadiusOfGyration);
            end
            if isfield(Project.Analysis.Confinement.Ensemble, 'MeanPackingCoefficient')
                fprintf(fid, 'Mean packing coeff      : %.6g\n', Project.Analysis.Confinement.Ensemble.MeanPackingCoefficient);
            end
            if isfield(Project.Analysis.Confinement.Ensemble, 'MeanConfinementRatio')
                fprintf(fid, 'Mean confinement ratio  : %.6g\n', Project.Analysis.Confinement.Ensemble.MeanConfinementRatio);
            end
        end
    end
end

fprintf(fid, '\nFlags\n');
fprintf(fid, '---------------------------------\n');
if isfield(Project, 'Flags')
    flds = fieldnames(Project.Flags);
    for i = 1:numel(flds)
        val = Project.Flags.(flds{i});
        if isnumeric(val) || islogical(val)
            fprintf(fid, '%-20s : %d\n', flds{i}, val);
        end
    end
end

fclose(fid);

end

% =====================================================================
function writeTableCSV(T, filename, useRowNames)
if nargin < 3
    useRowNames = false;
end
if isempty(T)
    fid = fopen(filename, 'w');
    if fid > 0
        fclose(fid);
    end
    return;
end
if useRowNames
    writetable(T, filename, 'WriteRowNames', true);
else
    writetable(T, filename);
end
end

% =====================================================================
function y = padToLen(x, n)
if isempty(x)
    y = nan(n, 1);
    return;
end
x = x(:);
if numel(x) >= n
    y = x(1:n);
else
    y = [x; nan(n - numel(x), 1)];
end
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

% =====================================================================
function maxPreview = getMaxPreview(Config, nTraj)
maxPreview = min(12, nTraj);
if isfield(Config, 'Figure') && isstruct(Config.Figure)
    if isfield(Config.Figure, 'MaxPreview') && ~isempty(Config.Figure.MaxPreview)
        if isnumeric(Config.Figure.MaxPreview) && isscalar(Config.Figure.MaxPreview)
            maxPreview = min(Config.Figure.MaxPreview, nTraj);
        end
    end
end
end

% =====================================================================
function ensureDir(d)
if exist(d, 'dir') ~= 7
    mkdir(d);
end
end