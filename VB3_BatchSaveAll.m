function Batch = VB3_BatchSaveAll(inputList, hmmList, outputDir, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% VB3_BatchSaveAll
%
% VB3 Companion Toolbox v4.1.1
%
% Batch controller for multiple vbSPT file pairs.
%
% Supported modes:
%   1) Explicit file-list mode
%      VB3_BatchSaveAll({in1,in2}, {hmm1,hmm2}, outputDir, Config)
%
%   2) Folder auto-scan mode
%      VB3_BatchSaveAll(folderPath, '', outputDir, Config)
%
%   3) Single-pair mode
%      VB3_BatchSaveAll(inputMAT, hmmMAT, outputDir, Config)
%
% For each pair, this function runs:
%   SPT_RunPipeline -> SPT_Validation
%
% Then it writes:
%   - pair-level outputs
%   - batch summary MAT/CSV
%   - master MAT/CSV/report
%
% MATLAB R2016b compatible
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1.1\n');
fprintf(' VB3_BatchSaveAll\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Inputs
%% --------------------------------------------------------

if nargin<1 || isempty(inputList)

    inputList = uigetdir(pwd,'Select folder');

    if isequal(inputList,0)
        return
    end

end

if nargin < 2
    hmmList = '';
end

if nargin < 3 || isempty(outputDir)

    outputDir = uigetdir(inputList,'Select output folder');

    if isequal(outputDir,0)
        return
    end

end

fprintf('\n');
fprintf('=====================================================\n');
fprintf('Input folder  : %s\n', inputList);
fprintf('Output folder : %s\n', outputDir);
fprintf('=====================================================\n');

if nargin < 4 || isempty(Config)
    Config = VB3_Config();
end

if exist(outputDir, 'dir') ~= 7
    [ok,msg] = mkdir(outputDir);
    if ~ok
        error('Cannot create outputDir:\n%s\nReason:\n%s', outputDir, msg);
    end
end

%% --------------------------------------------------------
%% Collect file pairs
%% --------------------------------------------------------

mode = '';
inputFiles = {};
hmmFiles = {};

% Explicit file-list mode
if iscell(inputList)

    if ~iscell(hmmList)
        error('When inputList is a cell array, hmmList must also be a cell array.');
    end

    if numel(inputList) ~= numel(hmmList)
        error('inputList and hmmList must have the same length.');
    end

    mode = 'explicit';
    inputFiles = inputList(:);
    hmmFiles = hmmList(:);

% Folder auto-scan mode
elseif ischar(inputList) && exist(inputList, 'dir') == 7 && (isempty(hmmList) || (ischar(hmmList) && isempty(hmmList)))

    mode = 'folder';
    [inputFiles, hmmFiles] = scanFolderForPairs(inputList);

    if isempty(inputFiles)
        error('No valid input/HMM pairs were found in folder:\n%s', inputList);
    end

% Single pair mode
elseif ischar(inputList) && ischar(hmmList) && ...
        exist(inputList, 'file') == 2 && exist(hmmList, 'file') == 2

    mode = 'single';
    inputFiles = {inputList};
    hmmFiles = {hmmList};

else
    error('Invalid input. Use explicit file lists, a folder path, or a single input/HMM pair.');
end

nPairs = numel(inputFiles);

fprintf('\n');
fprintf('Mode              : %s\n', mode);
fprintf('Number of pairs   : %d\n', nPairs);
fprintf('Processing mode    : %s\n', mode);
fprintf('Number of pairs    : %d\n', nPairs);

%% --------------------------------------------------------
%% Batch object
%% --------------------------------------------------------

Batch = struct();
Batch.Version = 'VB3 Companion Toolbox v4.1.1';
Batch.mode = mode;
Batch.outputDir = outputDir;
Batch.config = Config;
Batch.pairs = cell(nPairs, 4);     % {inputFile, hmmFile, pairOut, status}
Batch.projects = cell(nPairs, 1);
Batch.errors = cell(nPairs, 1);
Batch.summary = table();
Batch.master = struct();

summaryRows = cell(nPairs, 1);

%% --------------------------------------------------------
%% Process each pair
%% --------------------------------------------------------

for i = 1:nPairs

    inputMAT = inputFiles{i};
    hmmMAT = hmmFiles{i};

    if exist(inputMAT, 'file') ~= 2
        error('Cannot find input file:\n%s', inputMAT);
    end

    if exist(hmmMAT, 'file') ~= 2
        error('Cannot find HMM file:\n%s', hmmMAT);
    end

    %% --------------------------------------------------------
    %% Output folder (use cell name)

    [~, cellName] = fileparts(inputMAT);

    % Remove "_allTraj" suffix if present
    cellName = regexprep(cellName, '_allTraj$', '');

    pairOut = fullfile(outputDir, cellName);

    ensureDir(pairOut);

    fprintf('\n');
    fprintf('-----------------------------------------\n');
    fprintf('Pair %d of %d\n', i, nPairs);
    fprintf('Input : %s\n', inputMAT);
    fprintf('HMM   : %s\n', hmmMAT);
    fprintf('Out   : %s\n', pairOut);
    fprintf('-----------------------------------------\n');

    status = 'OK';
    errMsg = '';
    Project = [];

    try
        Project = SPT_RunPipeline(inputMAT, hmmMAT, Config, pairOut);
        Project = SPT_Validation(Project, Config);
        Batch.projects{i} = Project;

    catch ME
        status = 'FAILED';
        errMsg = ME.message;
        Batch.projects{i} = [];
        warning('Pair %d failed: %s', i, ME.message);
    end

    Batch.pairs{i,1} = inputMAT;
    Batch.pairs{i,2} = hmmMAT;
    Batch.pairs{i,3} = pairOut;
    Batch.pairs{i,4} = status;
    Batch.errors{i} = errMsg;

    summaryRows{i} = makeSummaryRow(i, inputMAT, hmmMAT, pairOut, Project, status, errMsg); %#ok<AGROW>

end

Batch.summary = vertcat(summaryRows{:});

%% --------------------------------------------------------
%% Master outputs
%% --------------------------------------------------------

Batch.master = buildMasterOutputs(Batch, outputDir);

%% --------------------------------------------------------
%% Save batch object
%% --------------------------------------------------------

save(fullfile(outputDir, 'VB3_BatchSummary.mat'), 'Batch', '-v7.3');

if ~isempty(Batch.summary)
    writeTableCSV(Batch.summary, fullfile(outputDir, 'VB3_BatchSummary.csv'), false);
end

fprintf('\n');
fprintf('Batch completed successfully.\n');
fprintf('Summary MAT        : %s\n', fullfile(outputDir, 'VB3_BatchSummary.mat'));
fprintf('Summary CSV        : %s\n', fullfile(outputDir, 'VB3_BatchSummary.csv'));
fprintf('=====================================================\n');

end

% =====================================================================
function [inputFiles, hmmFiles] = scanFolderForPairs(rootFolder)
% Recursively scan folder tree and auto-pair HMM result files with inputs.

allFiles = listMatFilesRecursive(rootFolder);

inputFiles = {};
hmmFiles = {};

for i = 1:numel(allFiles)
    f = allFiles{i};

    if isHMMResultFile(f)
        inputFile = inferInputFile(f, rootFolder);
        if ~isempty(inputFile) && exist(inputFile, 'file') == 2
            inputFiles{end+1,1} = inputFile; %#ok<AGROW>
            hmmFiles{end+1,1} = f; %#ok<AGROW>
        end
    end
end

end

% =====================================================================
function files = listMatFilesRecursive(rootFolder)

files = {};
stack = {rootFolder};

while ~isempty(stack)

    current = stack{end};
    stack(end) = [];

    d = dir(current);

    for i = 1:numel(d)

        name = d(i).name;

        if strcmp(name, '.') || strcmp(name, '..')
            continue
        end

        fullPath = fullfile(current, name);

        if d(i).isdir
            stack{end+1} = fullPath; %#ok<AGROW>
        else
            [~,~,ext] = fileparts(fullPath);
            if strcmpi(ext, '.mat')
                files{end+1,1} = fullPath; %#ok<AGROW>
            end
        end

    end

end

end

% =====================================================================
function tf = isHMMResultFile(filename)

[~, name, ~] = fileparts(filename);
tf = ~isempty(strfind(name, 'HMMresult')) || ~isempty(strfind(name, 'postanalysis'));

end

% =====================================================================
function inputFile = inferInputFile(hmmFile, rootFolder)
% Infer matching input MAT file from an HMM result file name.

[folder, name, ~] = fileparts(hmmFile);

name0 = name;
name = regexprep(name, '_finalTraj_.*_HMMresult$', '');
name = regexprep(name, '_HMMresult$', '');

%% Preferred input file names

candidateFiles = { ...
    fullfile(folder,[name '_allTraj.mat']); ...
    fullfile(folder,[name '.mat'])};

for k = 1:numel(candidateFiles)

    cand = candidateFiles{k};

    if exist(cand,'file') == 2 && ~isHMMResultFile(cand)

        inputFile = cand;
        return

    end

end

if nargin < 2 || isempty(rootFolder)
    rootFolder = folder;
end

allFiles = listMatFilesRecursive(rootFolder);

for i = 1:numel(allFiles)

    f = allFiles{i};

    if strcmp(f, hmmFile)
        continue
    end

    if ~isHMMResultFile(f)

        [~, bn, ~] = fileparts(f);

        if ~isempty(strfind(bn, name)) || ~isempty(strfind(name0, bn))
            inputFile = f;
            return;
        end

    end

end

inputFile = cand;

if exist(inputFile, 'file') ~= 2
    inputFile = '';
end

end

% =====================================================================
function row = makeSummaryRow(pairID, inputMAT, hmmMAT, pairOut, Project, status, errMsg)

inputName = getShortName(inputMAT);
hmmName   = getShortName(hmmMAT);

[~, cellName] = fileparts(inputMAT);
cellName = regexprep(cellName, '_allTraj$', '');

nTraj = NaN;
nStates = NaN;
dt_s = NaN;
nLocRows = NaN;
nSegRows = NaN;
nTrackRows = NaN;
nStateRows = NaN;
nTrans = NaN;
nMSDLags = NaN;
nTAngleRows = NaN;
nConfRows = NaN;
valOK = false;
nIssues = NaN;

if isstruct(Project)

    if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'nTraj')
        nTraj = Project.Dataset.nTraj;
    end

    if isfield(Project, 'HMM') && isfield(Project.HMM, 'nStates')
        nStates = Project.HMM.nStates;
    end

    if isfield(Project, 'Dataset') && isfield(Project.Dataset, 'dt')
        dt_s = Project.Dataset.dt;
    end

    if isfield(Project, 'Tables')

        if isfield(Project.Tables, 'Localization') && istable(Project.Tables.Localization)
            nLocRows = height(Project.Tables.Localization);
        end

        if isfield(Project.Tables, 'Segment') && istable(Project.Tables.Segment)
            nSegRows = height(Project.Tables.Segment);
        end

        if isfield(Project.Tables, 'Track') && istable(Project.Tables.Track)
            nTrackRows = height(Project.Tables.Track);
        end

        if isfield(Project.Tables, 'State') && istable(Project.Tables.State)
            nStateRows = height(Project.Tables.State);
        end

    end

    if isfield(Project, 'Analysis')

        if isfield(Project.Analysis, 'Transition') && isstruct(Project.Analysis.Transition)
            if isfield(Project.Analysis.Transition, 'nTotalTransitions')
                nTrans = Project.Analysis.Transition.nTotalTransitions;
            elseif isfield(Project.Analysis.Transition, 'CountMatrix')
                nTrans = sum(Project.Analysis.Transition.CountMatrix(:));
            end
        end

        if isfield(Project.Analysis, 'MSD') && isstruct(Project.Analysis.MSD)
            if isfield(Project.Analysis.MSD, 'Ensemble') && isfield(Project.Analysis.MSD.Ensemble, 'Lag')
                nMSDLags = numel(Project.Analysis.MSD.Ensemble.Lag);
            end
        end

        if isfield(Project.Analysis, 'TurningAngle') && isstruct(Project.Analysis.TurningAngle)
            if isfield(Project.Analysis.TurningAngle, 'Table') && istable(Project.Analysis.TurningAngle.Table)
                nTAngleRows = height(Project.Analysis.TurningAngle.Table);
            elseif isfield(Project.Analysis.TurningAngle, 'Ensemble') && isfield(Project.Analysis.TurningAngle.Ensemble, 'nAngles')
                nTAngleRows = Project.Analysis.TurningAngle.Ensemble.nAngles;
            end
        end

        if isfield(Project.Analysis, 'Confinement') && isstruct(Project.Analysis.Confinement)
            if isfield(Project.Analysis.Confinement, 'Table') && istable(Project.Analysis.Confinement.Table)
                nConfRows = height(Project.Analysis.Confinement.Table);
            elseif isfield(Project.Analysis.Confinement, 'Summary') && isfield(Project.Analysis.Confinement.Summary, 'nConfinementRows')
                nConfRows = Project.Analysis.Confinement.Summary.nConfinementRows;
            end
        end

    end

    if isfield(Project, 'Validation')
        if isfield(Project.Validation, 'OK')
            valOK = logical(Project.Validation.OK);
        end
        if isfield(Project.Validation, 'NIssues')
            nIssues = Project.Validation.NIssues;
        end
    end

end

row = table( ...
    pairID, ...
    {cellName}, ...
    {inputName},...
    {hmmName}, ...
    {pairOut}, ...
    {status}, ...
    {errMsg}, ...
    nTraj, ...
    nStates, ...
    dt_s, ...
    nLocRows, ...
    nSegRows, ...
    nTrackRows, ...
    nStateRows, ...
    nTrans, ...
    nMSDLags, ...
    nTAngleRows, ...
    nConfRows, ...
    valOK, ...
    nIssues, ...
    'VariableNames', { ...
        'pairID', ...
        'cellName',...
        'inputFile', ...
        'hmmFile', ...
        'outputDir', ...
        'status', ...
        'message', ...
        'nTraj', ...
        'nStates', ...
        'dt_s', ...
        'nLocalizationRows', ...
        'nSegmentRows', ...
        'nTrackRows', ...
        'nStateRows', ...
        'nTransitions', ...
        'nMSDLags', ...
        'nTurningAngleRows', ...
        'nConfinementRows', ...
        'validationOK', ...
        'nValidationIssues'});

end

% =====================================================================
function master = buildMasterOutputs(Batch, outputDir)

master = struct();
master.nPairs = numel(Batch.projects);
master.projectsOK = 0;
master.projectsFailed = 0;
master.maxStates = 1;
master.outputDir = outputDir;

for i = 1:numel(Batch.projects)
    P = Batch.projects{i};
    if isempty(P)
        master.projectsFailed = master.projectsFailed + 1;
    else
        master.projectsOK = master.projectsOK + 1;
        if isfield(P, 'HMM') && isfield(P.HMM, 'nStates')
            if P.HMM.nStates > master.maxStates
                master.maxStates = P.HMM.nStates;
            end
        end
    end
end

allLoc = table();
allSeg = table();
allTrack = table();
allState = table();
allManifest = Batch.summary;
masterTransCounts = zeros(master.maxStates, master.maxStates);

for i = 1:numel(Batch.projects)

    P = Batch.projects{i};
    if isempty(P)
        continue
    end

    if isfield(P, 'Tables')
        
        cellName = Batch.summary.cellName{i};

        if isfield(P.Tables, 'Localization') && istable(P.Tables.Localization)
            T = harmonizeLocalizationTable(P.Tables.Localization, i, cellName, master.maxStates);
            allLoc = [allLoc; T]; %#ok<AGROW>
        end

        if isfield(P.Tables, 'Segment') && istable(P.Tables.Segment)
            T = harmonizeSegmentTable(P.Tables.Segment, i, cellName, master.maxStates);
            allSeg = [allSeg; T]; %#ok<AGROW>
        end

        if isfield(P.Tables, 'Track') && istable(P.Tables.Track)
            T = harmonizeTrackTable(P.Tables.Track, i, cellName, master.maxStates);
            allTrack = [allTrack; T]; %#ok<AGROW>
        end

        if isfield(P.Tables, 'State') && istable(P.Tables.State)
            T = harmonizeStateTable(P.Tables.State, i, cellName, master.maxStates);
            allState = [allState; T]; %#ok<AGROW>
        end

    end

    if isfield(P, 'Analysis') && isfield(P.Analysis, 'Transition')
        if isfield(P.Analysis.Transition, 'CountMatrix')
            C = padMatrix(P.Analysis.Transition.CountMatrix, master.maxStates);
            masterTransCounts = masterTransCounts + C;
        end
    end

end

masterTransProb = zeros(master.maxStates, master.maxStates);
for r = 1:master.maxStates
    rs = sum(masterTransCounts(r, :));
    if rs > 0
        masterTransProb(r, :) = masterTransCounts(r, :) ./ rs;
    end
end

master.CountMatrix = masterTransCounts;
master.ProbMatrix = masterTransProb;
master.Localization = allLoc;
master.Segment = allSeg;
master.Track = allTrack;
master.State = allState;
master.Manifest = allManifest;

masterDir = outputDir;
ensureDir(masterDir);

if ~isempty(allLoc)
    writeTableCSV(allLoc, fullfile(masterDir, 'Master_Localization.csv'), false);
end
if ~isempty(allSeg)
    writeTableCSV(allSeg, fullfile(masterDir, 'Master_Segment.csv'), false);
end
if ~isempty(allTrack)
    writeTableCSV(allTrack, fullfile(masterDir, 'Master_TrackSummary.csv'), false);
end
if ~isempty(allState)
    writeTableCSV(allState, fullfile(masterDir, 'Master_StateStats.csv'), false);
end
if ~isempty(allManifest)
    writeTableCSV(allManifest, fullfile(masterDir, 'Master_Manifest.csv'), false);
end

Tcount = matrixToTable(masterTransCounts);
Tprob = matrixToTable(masterTransProb);

writeTableCSV(Tcount, fullfile(masterDir, 'Master_TransitionCountMatrix.csv'), true);
writeTableCSV(Tprob, fullfile(masterDir, 'Master_TransitionProbMatrix.csv'), true);

save(fullfile(masterDir, 'VB3_BatchMaster.mat'), ...
    'allLoc', 'allSeg', 'allTrack', 'allState', 'allManifest', ...
    'masterTransCounts', 'masterTransProb', 'Tcount', 'Tprob', '-v7.3');

fid = fopen(fullfile(masterDir, 'Master_Report.txt'), 'w');
if fid > 0
    fprintf(fid, 'VB3 Companion Toolbox v4.1.1 Batch Master Report\n');
    fprintf(fid, '=============================================\n\n');
    fprintf(fid, 'Pairs total      : %d\n', master.nPairs);
    fprintf(fid, 'Pairs OK         : %d\n', master.projectsOK);
    fprintf(fid, 'Pairs failed     : %d\n', master.projectsFailed);
    fprintf(fid, 'Max states       : %d\n\n', master.maxStates);
    fprintf(fid, 'Localization rows: %d\n', height(allLoc));
    fprintf(fid, 'Segment rows     : %d\n', height(allSeg));
    fprintf(fid, 'Track rows       : %d\n', height(allTrack));
    fprintf(fid, 'State rows       : %d\n', height(allState));
    fprintf(fid, 'Transitions      : %d\n', sum(masterTransCounts(:)));
    fclose(fid);
end

fprintf('\nMaster outputs written to: %s\n', masterDir);

end

% =====================================================================
function T = harmonizeLocalizationTable(T, pairID, cellName, maxStates)

if isempty(T)
    return;
end

if ~ismember('sourcePair', T.Properties.VariableNames)
    T.sourcePair = repmat(pairID, height(T), 1);
end

if ~ismember('cellName', T.Properties.VariableNames)
    T.cellName = repmat({cellName}, height(T), 1);
end

for k = 1:maxStates
    v = ['pState' num2str(k)];
    if ~ismember(v, T.Properties.VariableNames)
        T.(v) = nan(height(T), 1);
    end
end

T = reorderLocalizationColumns(T);

end

% =====================================================================
function T = harmonizeSegmentTable(T, pairID, cellName, maxStates)

if isempty(T)
    return;
end

if ~ismember('sourcePair', T.Properties.VariableNames)
    T.sourcePair = repmat(pairID, height(T), 1);
end

if ~ismember('cellName', T.Properties.VariableNames)
    T.cellName = repmat({cellName}, height(T), 1);
end

for k = 1:maxStates
    v = ['meanPState' num2str(k)];
    if ~ismember(v, T.Properties.VariableNames)
        T.(v) = nan(height(T), 1);
    end
end

T = reorderTablePreserve(T);

end

% =====================================================================
function T = harmonizeTrackTable(T, pairID, cellName, maxStates)

if isempty(T)
    return;
end

if ~ismember('sourcePair', T.Properties.VariableNames)
    T.sourcePair = repmat(pairID, height(T), 1);
end

if ~ismember('cellName', T.Properties.VariableNames)
    T.cellName = repmat({cellName}, height(T), 1);
end

for k = 1:maxStates
    v = ['state' num2str(k) '_fraction'];
    if ~ismember(v, T.Properties.VariableNames)
        T.(v) = nan(height(T), 1);
    end
end

T = reorderTablePreserve(T);

end

% =====================================================================
function T = harmonizeStateTable(T, pairID, cellName, maxStates)

if isempty(T)
    T = table();
end

if ~ismember('sourcePair', T.Properties.VariableNames)
    T.sourcePair = repmat(pairID, height(T), 1);
end

if ~ismember('cellName', T.Properties.VariableNames)
    T.cellName = repmat({cellName}, height(T), 1);
end

if ismember('State', T.Properties.VariableNames) && ~ismember('state', T.Properties.VariableNames)
    T.state = T.State;
end

if ~ismember('state', T.Properties.VariableNames)
    return;
end

rows = cell(maxStates, 1);

for k = 1:maxStates
    idx = (T.state == k);
    if any(idx)
        rows{k} = T(find(idx, 1, 'first'), :);
    else
        rows{k} = emptyStateRow(pairID, cellName, k, T);
    end
end

T = rows{1};
for k = 2:maxStates
    T = [T; rows{k}]; %#ok<AGROW>
end

T = reorderTablePreserve(T);

end

% =====================================================================
function row = emptyStateRow(pairID, cellName, stateID, template)

row = template(1, :);

for i = 1:width(row)
    v = row.(row.Properties.VariableNames{i});
    if isnumeric(v)
        row.(row.Properties.VariableNames{i}) = NaN;
    end
end

if ismember('sourcePair', row.Properties.VariableNames)
    row.sourcePair = pairID;
end

if ismember('cellName', row.Properties.VariableNames)
    row.cellName = {cellName};
end

if ismember('state', row.Properties.VariableNames)
    row.state = stateID;
elseif ismember('State', row.Properties.VariableNames)
    row.State = stateID;
end

end

% =====================================================================
function T = reorderLocalizationColumns(T)

preferred = {'sourcePair','cellName','DatasetIndex','RawIndex','Tid','Frame','Time','X','Y','State','StepLength'};
vars = T.Properties.VariableNames;

for k = 1:numel(vars)
    if strncmp(vars{k}, 'pState', 6)
        preferred{end+1} = vars{k}; %#ok<AGROW>
    end
end

preferred = unique(preferred, 'stable');
preferred = intersect(preferred, vars, 'stable');

others = setdiff(vars, preferred, 'stable');
T = T(:, [preferred others]);

end

% =====================================================================
function T = reorderTablePreserve(T)

vars = T.Properties.VariableNames;

preferred = {};

if ismember('sourcePair', vars)
    preferred{end+1} = 'sourcePair';
end

if ismember('cellName', vars)
    preferred{end+1} = 'cellName';
end

if ismember('DatasetIndex', vars)
    preferred{end+1} = 'DatasetIndex';
end

if ismember('RawIndex', vars)
    preferred{end+1} = 'RawIndex';
end

if ismember('Tid', vars)
    preferred{end+1} = 'Tid';
end

if ismember('trackIndex', vars)
    preferred{end+1} = 'trackIndex';
end

if ismember('segmentID', vars)
    preferred{end+1} = 'segmentID';
end

if ismember('state', vars)
    preferred{end+1} = 'state';
end

if ismember('State', vars)
    preferred{end+1} = 'State';
end

preferred = unique(preferred, 'stable');
preferred = intersect(preferred, vars, 'stable');

others = setdiff(vars, preferred, 'stable');
T = T(:, [preferred others]);

end

% =====================================================================
function M = padMatrix(M, nStates)

if isempty(M)
    M = zeros(nStates, nStates);
    return;
end

m = zeros(nStates, nStates);
r = min(size(M,1), nStates);
c = min(size(M,2), nStates);
m(1:r,1:c) = M(1:r,1:c);
M = m;

end

% =====================================================================
function T = matrixToTable(M)

nStates = size(M, 1);

varNames = cell(1, nStates);
rowNames = cell(1, nStates);

for k = 1:nStates
    varNames{k} = ['State' num2str(k)];
    rowNames{k} = ['State' num2str(k)];
end

T = array2table(M, 'VariableNames', varNames, 'RowNames', rowNames);

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
function name = getShortName(pathStr)
[~, name, ext] = fileparts(pathStr);
name = [name ext];
end

% =====================================================================
function ensureDir(d)

if exist(d, 'dir') ~= 7
    mkdir(d);
end

end