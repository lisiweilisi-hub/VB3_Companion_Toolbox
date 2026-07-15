function [Project, Snapshot] = VB3_RunRegressionBaseline(mode, inputMAT, hmmMAT, runOutputDir, baselineFile)
% VB3_RunRegressionBaseline  Capture or verify the v4.2 Cell4 baseline.
%
% MATLAB R2016b compatible.
%
% Capture, using the unmodified v4.2 implementation:
%   VB3_RunRegressionBaseline('capture');
%
% Verify a later implementation against the captured baseline:
%   VB3_RunRegressionBaseline('verify');
%
% Optional arguments override the known-good input pair, temporary pipeline
% output directory, and baseline MAT-file. Capture also writes a readable
% text manifest next to the MAT-file.

if nargin < 1 || isempty(mode)
    mode = 'verify';
end

knownDir = fullfile('C:\Program Files\MATLAB\R2016b', ...
    'vbSPT1.1.4_20170411', 'Lisi Data', '20260626', 'Cell4', ...
    'Cell4_1_172105_minflux_split');

if nargin < 2 || isempty(inputMAT)
    inputMAT = fullfile(knownDir, ...
        'Cell4_1_172105_minflux_group02_dt0.000500s.mat');
end

if nargin < 3 || isempty(hmmMAT)
    hmmMAT = fullfile(knownDir, ...
        'Cell4_1_172105_minflux_group02_dt0.000500s_finalTraj_10_Jul_2026_HMMresult.mat');
end

if nargin < 4 || isempty(runOutputDir)
    runOutputDir = fullfile(tempdir, 'VB3_v42_Cell4_regression');
end

thisDir = fileparts(mfilename('fullpath'));
if nargin < 5 || isempty(baselineFile)
    baselineFile = fullfile(thisDir, 'baselines', ...
        'v42_cell4_group02_baseline.mat');
end

mode = lower(char(mode));
if ~strcmp(mode, 'capture') && ~strcmp(mode, 'verify')
    error('mode must be either ''capture'' or ''verify''.');
end

requireFile(inputMAT, 'known-good trajectory MAT-file');
requireFile(hmmMAT, 'known-good HMM result MAT-file');

if exist(runOutputDir, 'dir') ~= 7
    mkdir(runOutputDir);
end

Config = VB3_Config();
Config.MinTrajectoryLength = 10;

Project = SPT_RunPipeline(inputMAT, hmmMAT, Config, runOutputDir);
Project = SPT_Validation(Project, Config);
Snapshot = collectSnapshot(Project, inputMAT, hmmMAT, runOutputDir);

if strcmp(mode, 'capture')
    baselineDir = fileparts(baselineFile);
    if exist(baselineDir, 'dir') ~= 7
        mkdir(baselineDir);
    end
    Baseline = Snapshot; %#ok<NASGU>
    save(baselineFile, 'Baseline', '-v7');
    manifestFile = replaceExtension(baselineFile, '.txt');
    writeManifest(Snapshot, manifestFile);
    fprintf('Captured regression baseline:\n  %s\n  %s\n', ...
        baselineFile, manifestFile);
else
    requireFile(baselineFile, 'captured regression baseline');
    loaded = load(baselineFile, 'Baseline');
    if ~isfield(loaded, 'Baseline')
        error('Baseline file does not contain a variable named Baseline.');
    end
    compareSnapshots(loaded.Baseline, Snapshot);
    fprintf('VB3 v4.2 regression baseline verification passed.\n');
end

end

% =====================================================================
function Snapshot = collectSnapshot(Project, inputMAT, hmmMAT, outputDir)

Snapshot = struct();
Snapshot.FormatVersion = 1;
Snapshot.SourceBaselineCommit = '11e78837b3dce49ef5e1bed59f26adf3fa4bfee4';
Snapshot.CapturedWith = version;
Snapshot.InputMAT = inputMAT;
Snapshot.HMMMAT = hmmMAT;
Snapshot.Tables = collectTables(Project);
Snapshot.AnalysisInventory = inventoryValue(Project.Analysis, 'Project.Analysis', 0);
Snapshot.ValidationFlags = collectValidationFlags(Project);
Snapshot.NumericOutputs = collectNumericOutputs(Project);
Snapshot.TableNumericSummary = collectTableNumericSummary(Project);
Snapshot.CSVOutputs = collectGeneratedFiles(fullfile(outputDir, 'CSV'));
Snapshot.FigureOutputs = collectGeneratedFiles(fullfile(outputDir, 'Figures'));

end

% =====================================================================
function result = collectTables(Project)

result = struct('Names', {{}}, 'Details', struct([]));
if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables)
    return
end

names = fieldnames(Project.Tables);
details = struct('Name', {}, 'Columns', {}, 'RowCount', {}, 'Size', {});
keptNames = {};

for i = 1:numel(names)
    value = Project.Tables.(names{i});
    if ~istable(value)
        continue
    end
    d = struct();
    d.Name = names{i};
    d.Columns = value.Properties.VariableNames;
    d.RowCount = height(value);
    d.Size = size(value);
    details(end + 1) = d; %#ok<AGROW>
    keptNames{end + 1} = names{i}; %#ok<AGROW>
end

result.Names = keptNames;
result.Details = details;

end


% =====================================================================
function items = inventoryValue(value, path, depth)

item = struct('Path', path, 'Class', class(value), ...
    'Size', size(value), 'FieldNames', {{}});
if isstruct(value)
    item.FieldNames = fieldnames(value).';
elseif istable(value)
    item.FieldNames = value.Properties.VariableNames;
end
items = item;

if depth >= 8 || isempty(value)
    return
end

if isstruct(value)
    fields = fieldnames(value);
    sample = value(1);
    for i = 1:numel(fields)
        childPath = [path '.' fields{i}];
        child = inventoryValue(sample.(fields{i}), childPath, depth + 1);
        items = [items child]; %#ok<AGROW>
    end
elseif istable(value)
    names = value.Properties.VariableNames;
    for i = 1:numel(names)
        childPath = [path '.' names{i}];
        child = inventoryValue(value.(names{i}), childPath, depth + 1);
        items = [items child]; %#ok<AGROW>
    end
elseif iscell(value)
    sampleIndex = find(~cellfun(@isempty, value), 1, 'first');
    if ~isempty(sampleIndex)
        child = inventoryValue(value{sampleIndex}, ...
            [path '{firstNonempty}'], depth + 1);
        items = [items child]; %#ok<AGROW>
    end
end

end

% =====================================================================
function flags = collectValidationFlags(Project)

flags = struct('Name', {}, 'Value', {});
if ~isfield(Project, 'Validation') || ~isstruct(Project.Validation)
    return
end

names = fieldnames(Project.Validation);
for i = 1:numel(names)
    value = Project.Validation.(names{i});
    if (islogical(value) || isnumeric(value)) && isscalar(value)
        flags(end + 1).Name = names{i}; %#ok<AGROW>
        flags(end).Value = double(value);
    end
end

end

% =====================================================================
function metrics = collectNumericOutputs(Project)

paths = { ...
    'Dataset.nTraj', ...
    'Dataset.dt', ...
    'Geometry.Summary.TotalSteps', ...
    'Geometry.Summary.TotalDistance', ...
    'Geometry.Summary.MeanTrackLength', ...
    'Geometry.Summary.MeanNetDisplacement', ...
    'Geometry.Summary.MeanCumulativeDistance', ...
    'Analysis.Transition.nTotalTransitions', ...
    'Analysis.MSD.Fit.Linear.D', ...
    'Analysis.MSD.Fit.Linear.R2', ...
    'Analysis.MSD.Fit.PowerLaw.Alpha', ...
    'Analysis.MSD.Fit.PowerLaw.A', ...
    'Analysis.TurningAngle.Ensemble.nAngles', ...
    'Analysis.TurningAngle.Ensemble.MeanAbsAngle_deg', ...
    'Analysis.TurningAngle.Ensemble.ResultantLength', ...
    'Analysis.Confinement.Ensemble.nWindows', ...
    'Analysis.Confinement.Ensemble.MeanRadiusOfGyration', ...
    'Analysis.Confinement.Ensemble.MeanPackingCoefficient', ...
    'Analysis.Confinement.Ensemble.MeanConfinementRatio', ...
    'Analysis.Confinement.Ensemble.MeanConfinementIndex'};

metrics = struct('Path', {}, 'Value', {});
for i = 1:numel(paths)
    [found, value] = getNestedValue(Project, paths{i});
    if found && isnumeric(value) && isscalar(value)
        metrics(end + 1).Path = paths{i}; %#ok<AGROW>
        metrics(end).Value = double(value);
    end
end

end

% =====================================================================
function summary = collectTableNumericSummary(Project)

summary = struct('Table', {}, 'Column', {}, 'N', {}, 'NFinite', {}, ...
    'NNaN', {}, 'Sum', {}, 'Mean', {}, 'Min', {}, 'Max', {});
if ~isfield(Project, 'Tables') || ~isstruct(Project.Tables)
    return
end

tableNames = fieldnames(Project.Tables);
for i = 1:numel(tableNames)
    T = Project.Tables.(tableNames{i});
    if ~istable(T)
        continue
    end
    columns = T.Properties.VariableNames;
    for j = 1:numel(columns)
        x = T.(columns{j});
        if ~isnumeric(x) && ~islogical(x)
            continue
        end
        x = double(x(:));
        finiteValues = x(isfinite(x));
        row = struct();
        row.Table = tableNames{i};
        row.Column = columns{j};
        row.N = numel(x);
        row.NFinite = numel(finiteValues);
        row.NNaN = sum(isnan(x));
        if isempty(finiteValues)
            row.Sum = NaN;
            row.Mean = NaN;
            row.Min = NaN;
            row.Max = NaN;
        else
            row.Sum = sum(finiteValues);
            row.Mean = mean(finiteValues);
            row.Min = min(finiteValues);
            row.Max = max(finiteValues);
        end
        summary(end + 1) = row; %#ok<AGROW>
    end
end

end

% =====================================================================
function files = collectGeneratedFiles(rootDir)

files = struct('RelativePath', {}, 'Bytes', {});
if exist(rootDir, 'dir') ~= 7
    return
end

files = walkDirectory(rootDir, rootDir);
if ~isempty(files)
    [~, order] = sort({files.RelativePath});
    files = files(order);
end

end

% =====================================================================
function files = walkDirectory(rootDir, currentDir)

files = struct('RelativePath', {}, 'Bytes', {});
entries = dir(currentDir);
for i = 1:numel(entries)
    name = entries(i).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue
    end
    fullName = fullfile(currentDir, name);
    if entries(i).isdir
        child = walkDirectory(rootDir, fullName);
        files = [files child]; %#ok<AGROW>
    else
        rel = fullName((numel(rootDir) + 2):end);
        row = struct('RelativePath', rel, 'Bytes', entries(i).bytes);
        files(end + 1) = row; %#ok<AGROW>
    end
end

end

% =====================================================================
function compareSnapshots(expected, actual)

issues = {};

if ~isequal(expected.FormatVersion, actual.FormatVersion)
    issues{end + 1} = 'Baseline snapshot format version changed.'; %#ok<AGROW>
end
if ~isequal(expected.SourceBaselineCommit, actual.SourceBaselineCommit)
    issues{end + 1} = 'Baseline source commit identifier changed.'; %#ok<AGROW>
end
if ~isequal(expected.Tables, actual.Tables)
    issues{end + 1} = 'Table names, columns, row counts, or sizes changed.'; %#ok<AGROW>
end
if ~isequal(expected.AnalysisInventory, actual.AnalysisInventory)
    issues{end + 1} = 'Analysis field names, classes, or array sizes changed.'; %#ok<AGROW>
end
if ~isequaln(expected.ValidationFlags, actual.ValidationFlags)
    issues{end + 1} = 'Validation flags changed.'; %#ok<AGROW>
end

issues = compareNumericStructArray(expected.NumericOutputs, ...
    actual.NumericOutputs, 'representative numeric output', issues);
issues = compareNumericStructArray(expected.TableNumericSummary, ...
    actual.TableNumericSummary, 'numeric table summary', issues);

if ~isequal({expected.CSVOutputs.RelativePath}, {actual.CSVOutputs.RelativePath})
    issues{end + 1} = 'Generated CSV file set changed.'; %#ok<AGROW>
end
if ~isequal({expected.FigureOutputs.RelativePath}, {actual.FigureOutputs.RelativePath})
    issues{end + 1} = 'Generated Figure file set changed.'; %#ok<AGROW>
end

if ~isempty(issues)
    fprintf(2, 'Regression verification failed:\n');
    for i = 1:numel(issues)
        fprintf(2, '  - %s\n', issues{i});
    end
    error('VB3:RegressionMismatch', '%d baseline checks failed.', numel(issues));
end

end

% =====================================================================
function issues = compareNumericStructArray(expected, actual, label, issues)

if ~isequal(fieldnames(expected), fieldnames(actual)) || numel(expected) ~= numel(actual)
    issues{end + 1} = [label ' shape changed.']; %#ok<AGROW>
    return
end

absoluteTolerance = 1e-12;
relativeTolerance = 1e-9;

for i = 1:numel(expected)
    fields = fieldnames(expected);
    for j = 1:numel(fields)
        a = expected(i).(fields{j});
        b = actual(i).(fields{j});
        if isnumeric(a) && isnumeric(b)
            if ~numericEqual(a, b, absoluteTolerance, relativeTolerance)
                issues{end + 1} = [label ' changed at item ' num2str(i) '.']; %#ok<AGROW>
                return
            end
        elseif ~isequal(a, b)
            issues{end + 1} = [label ' identity changed at item ' num2str(i) '.']; %#ok<AGROW>
            return
        end
    end
end

end

% =====================================================================
function tf = numericEqual(a, b, absoluteTolerance, relativeTolerance)

if ~isequal(size(a), size(b))
    tf = false;
    return
end
sameNaN = isnan(a) & isnan(b);
sameInf = isinf(a) & isinf(b) & (sign(a) == sign(b));
finite = isfinite(a) & isfinite(b);
delta = abs(a - b);
limit = absoluteTolerance + relativeTolerance .* max(abs(a), abs(b));
tf = all(sameNaN(:) | sameInf(:) | (finite(:) & delta(:) <= limit(:)));

end

% =====================================================================
function writeManifest(Snapshot, filename)

fid = fopen(filename, 'w');
if fid < 0
    error('Could not open baseline manifest for writing: %s', filename);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'VB3 v4.2 Cell4 regression baseline\n');
fprintf(fid, 'Source commit: %s\n', Snapshot.SourceBaselineCommit);
fprintf(fid, 'MATLAB: %s\n', Snapshot.CapturedWith);
fprintf(fid, 'Input: %s\n', Snapshot.InputMAT);
fprintf(fid, 'HMM: %s\n\n', Snapshot.HMMMAT);

fprintf(fid, '[Tables]\n');
for i = 1:numel(Snapshot.Tables.Details)
    d = Snapshot.Tables.Details(i);
    fprintf(fid, '%s: %d rows; columns: %s\n', d.Name, d.RowCount, ...
        joinCell(d.Columns, ', '));
end

fprintf(fid, '\n[Analysis inventory]\n');
for i = 1:numel(Snapshot.AnalysisInventory)
    d = Snapshot.AnalysisInventory(i);
    fprintf(fid, '%s | %s | %s\n', d.Path, d.Class, sizeText(d.Size));
end

fprintf(fid, '\n[Validation flags]\n');
for i = 1:numel(Snapshot.ValidationFlags)
    fprintf(fid, '%s = %.17g\n', Snapshot.ValidationFlags(i).Name, ...
        Snapshot.ValidationFlags(i).Value);
end

fprintf(fid, '\n[Representative numeric outputs]\n');
for i = 1:numel(Snapshot.NumericOutputs)
    fprintf(fid, '%s = %.17g\n', Snapshot.NumericOutputs(i).Path, ...
        Snapshot.NumericOutputs(i).Value);
end

fprintf(fid, '\n[Numeric table-column summaries]\n');
for i = 1:numel(Snapshot.TableNumericSummary)
    d = Snapshot.TableNumericSummary(i);
    fprintf(fid, '%s.%s | N=%d finite=%d NaN=%d sum=%.17g mean=%.17g min=%.17g max=%.17g\n', ...
        d.Table, d.Column, d.N, d.NFinite, d.NNaN, d.Sum, d.Mean, d.Min, d.Max);
end

fprintf(fid, '\n[CSV outputs]\n');
writeFileList(fid, Snapshot.CSVOutputs);
fprintf(fid, '\n[Figure outputs]\n');
writeFileList(fid, Snapshot.FigureOutputs);

end

% =====================================================================
function writeFileList(fid, files)

for i = 1:numel(files)
    fprintf(fid, '%s | %d bytes\n', files(i).RelativePath, files(i).Bytes);
end

end

% =====================================================================
function text = joinCell(values, separator)

if isempty(values)
    text = '';
    return
end
text = values{1};
for i = 2:numel(values)
    text = [text separator values{i}]; %#ok<AGROW>
end

end

% =====================================================================
function text = sizeText(sz)

text = num2str(sz(1));
for i = 2:numel(sz)
    text = [text 'x' num2str(sz(i))]; %#ok<AGROW>
end

end

% =====================================================================
function [found, value] = getNestedValue(root, path)

parts = regexp(path, '\.', 'split');
value = root;
found = true;
for i = 1:numel(parts)
    if ~isstruct(value) || ~isfield(value, parts{i})
        found = false;
        value = [];
        return
    end
    value = value.(parts{i});
end

end

% =====================================================================
function requireFile(filename, description)

if exist(filename, 'file') ~= 2
    error('Missing %s:\n  %s', description, filename);
end

end

% =====================================================================
function filename = replaceExtension(filename, extension)

[folder, name] = fileparts(filename);
filename = fullfile(folder, [name extension]);

end
