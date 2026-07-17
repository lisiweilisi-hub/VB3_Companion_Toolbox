function Project = SPT_Kinematics_Diffusion(Project, Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_Kinematics_Diffusion
%
% Initialize diffusion analysis from frozen MSD results.
%
% Input
%   Project.Analysis.Kinematics.MSD
%
% Output
%   Project.Analysis.Kinematics.Diffusion
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || ~isstruct(Project) || ~isscalar(Project)
    error('SPT_Kinematics_Diffusion:InvalidProject', ...
        'Project must be a scalar structure.');
end

% Reserved for future diffusion-fit configuration.
if nargin < 2
    Config = []; %#ok<NASGU>
end

if ~isfield(Project, 'Analysis') || ...
        ~isstruct(Project.Analysis) || ~isscalar(Project.Analysis) || ...
        ~isfield(Project.Analysis, 'Kinematics') || ...
        ~isstruct(Project.Analysis.Kinematics) || ...
        ~isscalar(Project.Analysis.Kinematics) || ...
        ~isfield(Project.Analysis.Kinematics, 'MSD') || ...
        ~isstruct(Project.Analysis.Kinematics.MSD) || ...
        ~isscalar(Project.Analysis.Kinematics.MSD)
    error('SPT_Kinematics_Diffusion:MissingMSD', ...
        'Project.Analysis.Kinematics.MSD not found.');
end

MSD = Project.Analysis.Kinematics.MSD;
if ~isfield(MSD, 'ByTrack') || ~istable(MSD.ByTrack)
    error('SPT_Kinematics_Diffusion:InvalidByTrack', ...
        'MSD.ByTrack must be a table.');
end
if ~isfield(MSD, 'Ensemble') || ~isstruct(MSD.Ensemble) || ...
        ~isscalar(MSD.Ensemble)
    error('SPT_Kinematics_Diffusion:InvalidEnsemble', ...
        'MSD.Ensemble must be a scalar structure.');
end

requiredNumeric = {'DatasetIndex','RawIndex','Tid', ...
    'NComputedLags','NMSDPairs'};
requiredLogical = {'MSDComputed'};
requiredCurves = {'Lag','LagTime','MSD','MSDX','MSDY', ...
    'MSDPairCount'};
validateNumericColumns(MSD.ByTrack, requiredNumeric);
validateLogicalColumns(MSD.ByTrack, requiredLogical);
validateCurveColumns(MSD.ByTrack, requiredCurves);
requiredEnsemble = {'LagTime','PooledMSD','PairsByLag'};
validateEnsembleFields(MSD.Ensemble, requiredEnsemble);

requiredByTrack = [requiredNumeric requiredLogical requiredCurves];
[ByTrack, sortedInternally] = ...
    normalizeByTrack(MSD.ByTrack(:, requiredByTrack));

Validation = struct();
Validation.OK = true;
Validation.Issues = {};
Validation.Source = 'Project.Analysis.Kinematics.MSD';
Validation.Upstream = readUpstreamValidation(MSD);
Validation.RequiredByTrackColumns = requiredByTrack;
Validation.RequiredEnsembleFields = requiredEnsemble;
Validation.NInputTrajectories = height(ByTrack);
Validation.SortedInternally = sortedInternally;

if any(~isfinite(ByTrack.DatasetIndex)) || ...
        any(ByTrack.DatasetIndex ~= floor(ByTrack.DatasetIndex))
    Validation = addIssue(Validation, ...
        'ByTrack.DatasetIndex must contain finite integer values.');
end
if numel(unique(ByTrack.DatasetIndex)) ~= height(ByTrack)
    Validation = addIssue(Validation, ...
        'ByTrack.DatasetIndex must be unique for each trajectory.');
end
if any(~isfinite(ByTrack.RawIndex)) || any(~isfinite(ByTrack.Tid))
    Validation = addIssue(Validation, ...
        'ByTrack.RawIndex and ByTrack.Tid must contain finite values.');
end
if any(~isfinite(ByTrack.NComputedLags)) || ...
        any(ByTrack.NComputedLags < 0) || ...
        any(ByTrack.NComputedLags ~= floor(ByTrack.NComputedLags)) || ...
        any(~isfinite(ByTrack.NMSDPairs)) || ...
        any(ByTrack.NMSDPairs < 0) || ...
        any(ByTrack.NMSDPairs ~= floor(ByTrack.NMSDPairs))
    Validation = addIssue(Validation, ...
        'ByTrack MSD counts must contain nonnegative integer values.');
end

[ByTrack, curvesOK, componentsOK] = addSkeletonMetadata(ByTrack);
if ~curvesOK
    Validation = addIssue(Validation, ...
        ['MSD lag, lag-time, value, and pair-count curves must have ' ...
        'consistent finite values and counts.']);
end
if ~componentsOK
    Validation = addIssue(Validation, ...
        'MSD must agree with MSDX plus MSDY.');
end
ensembleCurvesOK = validateEnsembleCurves(MSD.Ensemble);
if ~ensembleCurvesOK
    Validation = addIssue(Validation, ...
        'MSD.Ensemble lag-time, MSD, and pair-count curves are invalid.');
end

Validation.LocalOK = Validation.OK;
if ~Validation.Upstream.OK
    Validation = addIssue(Validation, ...
        'Upstream MSD validation is missing, invalid, or failed.');
end
Validation.OK = Validation.LocalOK && Validation.Upstream.OK;

ByTrack.DiffusionEligible = ByTrack.MSDComputed & ...
    ByTrack.NFiniteMSDPoints >= 2 & logical(Validation.OK);
[ByTrack, fitNumericsOK] = fitByTrack(ByTrack, Validation.OK);
[Ensemble, ensembleNumericsOK] = summarizeEnsemble( ...
    ByTrack, MSD.Ensemble, Validation.OK);
if ~fitNumericsOK || ~ensembleNumericsOK
    Validation = addIssue(Validation, ...
        'Diffusion fit calculations must remain finite.');
    Validation.LocalOK = false;
    Validation.OK = false;
    ByTrack.DiffusionEligible(:) = false;
    ByTrack = fitByTrack(ByTrack, false);
    Ensemble = summarizeEnsemble(ByTrack, MSD.Ensemble, false);
end

Summary = struct();
Summary.nTrajectories = Ensemble.NTrajectories;
Summary.nMSDComputedTrajectories = ...
    Ensemble.NMSDComputedTrajectories;
Summary.nFiniteMSDPoints = Ensemble.NFiniteMSDPoints;
Summary.nEligibleTrajectories = Ensemble.NEligibleTrajectories;
Summary.EligibleFraction = Ensemble.EligibleFraction;
Summary.MaxFiniteLag = Ensemble.MaxFiniteLag;
Summary.nFitSuccessful = Ensemble.NFitSuccessful;
Summary.FitSuccessfulFraction = Ensemble.FitSuccessfulFraction;
Summary.MeanDiffusionCoefficient = Ensemble.MeanDiffusionCoefficient;
Summary.PooledDiffusionCoefficient = ...
    Ensemble.PooledDiffusionCoefficient;
Summary.Dimension = 2;
Summary.FitPointLimit = 10;
Summary.Status = 'Core';

Diffusion = struct();
Diffusion.ByTrack = ByTrack;
Diffusion.Ensemble = Ensemble;
Diffusion.Summary = Summary;
Diffusion.Validation = Validation;

Project.Analysis.Kinematics.Diffusion = Diffusion;

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' SPT Kinematics Diffusion\n');
fprintf('=====================================================\n');
fprintf('Trajectory rows   : %d\n', Summary.nTrajectories);
fprintf('Eligible rows     : %d\n', Summary.nEligibleTrajectories);
fprintf('Diffusion status  : %s\n', Summary.Status);
fprintf('Validation        : %d\n', Validation.OK);
fprintf('=====================================================\n');

end

% =====================================================================
function validateNumericColumns(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_Diffusion:MissingColumn', ...
            'MSD.ByTrack missing column: %s', name);
    end
    value = T.(name);
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || ...
            numel(value) ~= height(T)
        error('SPT_Kinematics_Diffusion:InvalidColumn', ...
            ['MSD.ByTrack column %s must be a real numeric ' ...
            'vector.'], name);
    end
end

end

% =====================================================================
function validateLogicalColumns(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_Diffusion:MissingColumn', ...
            'MSD.ByTrack missing column: %s', name);
    end
    value = T.(name);
    validType = islogical(value) || ...
        (isnumeric(value) && isreal(value));
    if ~validType || ~isvector(value) || numel(value) ~= height(T) || ...
            any(~isfinite(value)) || any(~(value == 0 | value == 1))
        error('SPT_Kinematics_Diffusion:InvalidColumn', ...
            'MSD.ByTrack column %s must be a logical vector.', name);
    end
end

end

% =====================================================================
function validateCurveColumns(T, required)

for i = 1:numel(required)
    name = required{i};
    if ~ismember(name, T.Properties.VariableNames)
        error('SPT_Kinematics_Diffusion:MissingColumn', ...
            'MSD.ByTrack missing column: %s', name);
    end
    if ~iscell(T.(name)) || numel(T.(name)) ~= height(T)
        error('SPT_Kinematics_Diffusion:InvalidColumn', ...
            'MSD.ByTrack column %s must be a cell vector.', name);
    end
end

end

% =====================================================================
function [T, sortedInternally] = normalizeByTrack(T)

sortedInternally = false;
if isempty(T)
    return
end

[T, order] = sortrows(T, 'DatasetIndex');
sortedInternally = ~isequal(order(:), (1:height(T))');

end

% =====================================================================
function [T, curvesOK, componentsOK] = addSkeletonMetadata(T)

n = height(T);
T.NFiniteMSDPoints = zeros(n, 1);
T.MaxFiniteLag = zeros(n, 1);
curvesOK = true;
componentsOK = true;

for i = 1:n
    curveNames = {'Lag','LagTime','MSD','MSDX','MSDY','MSDPairCount'};
    rowCurvesOK = true;
    for j = 1:numel(curveNames)
        value = T.(curveNames{j}){i};
        if ~isnumeric(value) || ~isreal(value) || ...
                (~isempty(value) && ~isvector(value))
            rowCurvesOK = false;
            value = zeros(0, 1);
        end
        T.(curveNames{j}){i} = value(:);
    end

    lag = T.Lag{i};
    lagTime = T.LagTime{i};
    msd = T.MSD{i};
    msdX = T.MSDX{i};
    msdY = T.MSDY{i};
    pairCount = T.MSDPairCount{i};
    lengths = [numel(lag), numel(lagTime), numel(msd), ...
        numel(msdX), numel(msdY), numel(pairCount)];
    if any(lengths ~= lengths(1))
        rowCurvesOK = false;
    end

    nPoints = lengths(1);
    if nPoints > 0
        validLag = all(isfinite(lag)) && all(lag > 0) && ...
            all(lag == floor(lag)) && all(diff(lag) > 0);
        validLagTime = all(isfinite(lagTime)) && all(lagTime > 0) && ...
            all(diff(lagTime) > 0);
        validMSD = all(isfinite(msd)) && all(msd >= 0) && ...
            all(isfinite(msdX)) && all(msdX >= 0) && ...
            all(isfinite(msdY)) && all(msdY >= 0);
        validPairs = all(isfinite(pairCount)) && all(pairCount > 0) && ...
            all(pairCount == floor(pairCount));
        rowCurvesOK = rowCurvesOK && validLag && validLagTime && ...
            validMSD && validPairs;

        if validMSD && all(lengths == nPoints)
            difference = abs(msd - (msdX + msdY));
            scale = max(1, abs(msd));
            if any(difference > 1e-12 .* scale)
                componentsOK = false;
            end
        end
    end

    countsOK = T.NComputedLags(i) == nPoints && ...
        T.NMSDPairs(i) == sum(pairCount) && ...
        logical(T.MSDComputed(i)) == (nPoints > 0);
    rowCurvesOK = rowCurvesOK && countsOK;
    if ~rowCurvesOK
        curvesOK = false;
    end

    if rowCurvesOK
        T.NFiniteMSDPoints(i) = nPoints;
        if nPoints > 0
            T.MaxFiniteLag(i) = max(lag);
        end
    end
end

end

% =====================================================================
function validateEnsembleFields(E, required)

for i = 1:numel(required)
    name = required{i};
    if ~isfield(E, name)
        error('SPT_Kinematics_Diffusion:MissingEnsembleField', ...
            'MSD.Ensemble missing field: %s', name);
    end
    value = E.(name);
    if ~isnumeric(value) || ~isreal(value) || ...
            (~isempty(value) && ~isvector(value))
        error('SPT_Kinematics_Diffusion:InvalidEnsembleField', ...
            'MSD.Ensemble field %s must be a real numeric vector.', ...
            name);
    end
end

end

% =====================================================================
function tf = validateEnsembleCurves(E)

lagTime = E.LagTime(:);
msd = E.PooledMSD(:);
pairCount = E.PairsByLag(:);
tf = numel(lagTime) == numel(msd) && ...
    numel(lagTime) == numel(pairCount);
if ~tf || isempty(lagTime)
    return
end

tf = all(isfinite(lagTime)) && all(lagTime > 0) && ...
    all(diff(lagTime) > 0) && all(isfinite(msd)) && ...
    all(msd >= 0) && all(isfinite(pairCount)) && ...
    all(pairCount > 0) && all(pairCount == floor(pairCount));

end

% =====================================================================
function [T, numericsOK] = fitByTrack(T, validationOK)

n = height(T);
T.DiffusionCoefficient = nan(n, 1);
T.FitSlope = nan(n, 1);
T.FitIntercept = nan(n, 1);
T.FitRSquared = nan(n, 1);
T.NFitPoints = zeros(n, 1);
T.FitSuccessful = false(n, 1);
numericsOK = true;

for i = 1:n
    allowed = logical(validationOK) && T.DiffusionEligible(i);
    [slope, intercept, rSquared, nFitPoints, successful, rowOK] = ...
        fitInitialCurve(T.LagTime{i}, T.MSD{i}, allowed);
    T.NFitPoints(i) = nFitPoints;
    if ~rowOK
        numericsOK = false;
    end
    if successful
        T.DiffusionCoefficient(i) = slope / 4;
        T.FitSlope(i) = slope;
        T.FitIntercept(i) = intercept;
        T.FitRSquared(i) = rSquared;
        T.FitSuccessful(i) = true;
    end
end

end

% =====================================================================
function [slope, intercept, rSquared, nFitPoints, successful, ...
        numericsOK] = fitInitialCurve(lagTime, msd, allowed)

slope = NaN;
intercept = NaN;
rSquared = NaN;
nFitPoints = 0;
successful = false;
numericsOK = true;
if ~allowed
    return
end

lagTime = double(lagTime(:));
msd = double(msd(:));
nFitPoints = min(10, min(numel(lagTime), numel(msd)));
if nFitPoints < 2
    return
end

x = lagTime(1:nFitPoints);
y = msd(1:nFitPoints);
if any(~isfinite(x)) || any(~isfinite(y)) || ...
        any(x <= 0) || any(y < 0) || numel(unique(x)) < 2
    return
end

xMean = mean(x);
yMean = mean(y);
xCentered = x - xMean;
yCentered = y - yMean;
denominator = sum(xCentered .^ 2);
numerator = sum(xCentered .* yCentered);
if ~isfinite(denominator) || ~isfinite(numerator)
    numericsOK = false;
    return
end
if denominator <= 0
    return
end

slopeCandidate = numerator / denominator;
interceptCandidate = yMean - slopeCandidate * xMean;
fitted = interceptCandidate + slopeCandidate * x;
residual = y - fitted;
ssResidual = sum(residual .^ 2);
ssTotal = sum(yCentered .^ 2);
if any(~isfinite(fitted)) || ~isfinite(slopeCandidate) || ...
        ~isfinite(interceptCandidate) || ~isfinite(ssResidual) || ...
        ~isfinite(ssTotal)
    numericsOK = false;
    return
end

if ssTotal <= 0
    return
end
rSquaredCandidate = 1 - ssResidual / ssTotal;
if ~isfinite(rSquaredCandidate)
    numericsOK = false;
    return
end

if slopeCandidate < 0
    return
end

slope = slopeCandidate;
intercept = interceptCandidate;
rSquared = rSquaredCandidate;
successful = true;

end

% =====================================================================
function Upstream = readUpstreamValidation(MSD)

Upstream = struct();
Upstream.Source = ...
    'Project.Analysis.Kinematics.MSD.Validation';
Upstream.Available = false;
Upstream.OK = false;
Upstream.Issues = {};

if ~isfield(MSD, 'Validation') || ...
        ~isstruct(MSD.Validation) || ~isscalar(MSD.Validation) || ...
        ~isfield(MSD.Validation, 'OK')
    Upstream.Issues{end + 1, 1} = 'MSD.Validation.OK not found.';
    return
end

value = MSD.Validation.OK;
Upstream.Available = true;
if ~isscalar(value) || ...
        ~(islogical(value) || (isnumeric(value) && isreal(value))) || ...
        (isnumeric(value) && (~isfinite(value) || ...
        ~(value == 0 || value == 1)))
    Upstream.Issues{end + 1, 1} = ...
        'MSD.Validation.OK must be a logical scalar.';
    return
end

Upstream.OK = logical(value);
if ~Upstream.OK
    Upstream.Issues{end + 1, 1} = 'MSD.Validation.OK is false.';
end

end

% =====================================================================
function [E, numericsOK] = summarizeEnsemble(T, MSDEnsemble, validationOK)

E = struct();
E.NTrajectories = height(T);
E.NMSDComputedTrajectories = sum(logical(T.MSDComputed));
E.NFiniteMSDPoints = sum(T.NFiniteMSDPoints);
E.NEligibleTrajectories = sum(T.DiffusionEligible);
if E.NTrajectories == 0
    E.EligibleFraction = NaN;
else
    E.EligibleFraction = E.NEligibleTrajectories / E.NTrajectories;
end
if isempty(T)
    E.MaxFiniteLag = 0;
else
    E.MaxFiniteLag = max(T.MaxFiniteLag);
end

E.NFitSuccessful = sum(T.FitSuccessful);
if E.NEligibleTrajectories == 0
    E.FitSuccessfulFraction = NaN;
else
    E.FitSuccessfulFraction = ...
        E.NFitSuccessful / E.NEligibleTrajectories;
end
successfulD = T.DiffusionCoefficient(T.FitSuccessful);
if isempty(successfulD)
    E.MeanDiffusionCoefficient = NaN;
    E.MedianDiffusionCoefficient = NaN;
else
    E.MeanDiffusionCoefficient = mean(successfulD);
    E.MedianDiffusionCoefficient = median(successfulD);
end

E.PooledDiffusionCoefficient = NaN;
E.PooledFitSlope = NaN;
E.PooledFitIntercept = NaN;
E.PooledFitRSquared = NaN;
E.PooledNFitPoints = 0;
E.PooledFitSuccessful = false;
numericsOK = true;
valid = MSDEnsemble.PairsByLag(:) > 0;
lagTime = MSDEnsemble.LagTime(:);
pooledMSD = MSDEnsemble.PooledMSD(:);
if numel(valid) == numel(lagTime) && numel(valid) == numel(pooledMSD)
    lagTime = lagTime(valid);
    pooledMSD = pooledMSD(valid);
end
[slope, intercept, rSquared, nFitPoints, successful, rowOK] = ...
    fitInitialCurve(lagTime, pooledMSD, logical(validationOK));
E.PooledNFitPoints = nFitPoints;
numericsOK = rowOK;
if successful
    E.PooledDiffusionCoefficient = slope / 4;
    E.PooledFitSlope = slope;
    E.PooledFitIntercept = intercept;
    E.PooledFitRSquared = rSquared;
    E.PooledFitSuccessful = true;
end

end

% =====================================================================
function Validation = addIssue(Validation, message)

Validation.OK = false;
Validation.Issues{end + 1, 1} = message;

end
