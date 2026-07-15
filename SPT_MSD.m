function Project = SPT_MSD(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SPT_MSD
%
% VB3 Companion Toolbox v4.1
%
% Build MSD Analysis
%
% Input
%   Project.Dataset
%
% Output
%   Project.Analysis.MSD
%
% MATLAB R2016b
%
% 支持 N-state 环境下的数据结构，但 MSD 本身不依赖 state
% 同时输出：
% 每条轨迹的 MSD
% 全体轨迹的 pooled ensemble MSD
% 轨迹平均 MSD
% 线性拟合得到的 D
% 幂律拟合得到的 alpha
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' SPT MSD\n');
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
    error('Dataset contains no trajectories.');
end

if ~isfield(Project.Dataset, 'dt') || isempty(Project.Dataset.dt) || ~isnumeric(Project.Dataset.dt)
    error('Dataset.dt is invalid.');
end

%% --------------------------------------------------------
%% Configuration
%% --------------------------------------------------------

if ~isfield(Config, 'MSD') || ~isstruct(Config.MSD)
    Config.MSD = struct();
end

if ~isfield(Config.MSD, 'MaxLag') || isempty(Config.MSD.MaxLag)
    Config.MSD.MaxLag = 100;
end

if ~isfield(Config.MSD, 'Dimension') || isempty(Config.MSD.Dimension)
    Config.MSD.Dimension = 2;
end

if ~isfield(Config.MSD, 'FitLagMax') || isempty(Config.MSD.FitLagMax)
    Config.MSD.FitLagMax = min(10, Config.MSD.MaxLag);
end

if ~isfield(Config.MSD, 'MinFitPoints') || isempty(Config.MSD.MinFitPoints)
    Config.MSD.MinFitPoints = 3;
end

maxLagCfg = Config.MSD.MaxLag;
dim = Config.MSD.Dimension;
fitLagMaxCfg = Config.MSD.FitLagMax;
minFitPoints = Config.MSD.MinFitPoints;

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Dataset = Project.Dataset;
nTraj = Dataset.nTraj;
dt = Dataset.dt;

%% --------------------------------------------------------
%% Initialize
%% --------------------------------------------------------

MSD = struct();
MSD.Config = Config.MSD;
MSD.PerTrajectory = cell(nTraj, 1);
MSD.Ensemble = struct();
MSD.Summary = struct();

fprintf('Number of trajectories : %d\n', nTraj);
fprintf('Max lag                : %d\n', maxLagCfg);
fprintf('Time step              : %.4f ms\n', dt * 1000);
fprintf('\n');
fprintf('Building MSD ...\n');

%% --------------------------------------------------------
%% Preallocate ensemble buffers
%% --------------------------------------------------------

maxLagGlobal = 0;
trajLengths = zeros(nTraj, 1);

for i = 1:nTraj
    if ~isempty(Dataset.Trajectory{i})
        trajLengths(i) = size(Dataset.Trajectory{i}, 1);
        if trajLengths(i) > maxLagGlobal
            maxLagGlobal = trajLengths(i) - 1;
        end
    end
end

maxLagGlobal = min(maxLagGlobal, maxLagCfg);

if maxLagGlobal < 1
    error('Trajectories are too short for MSD calculation.');
end

msdMat = nan(nTraj, maxLagGlobal);
msdXMat = nan(nTraj, maxLagGlobal);
msdYMat = nan(nTraj, maxLagGlobal);
pairCountMat = zeros(nTraj, maxLagGlobal);

aggSumSq = zeros(maxLagGlobal, 1);
aggSumSqX = zeros(maxLagGlobal, 1);
aggSumSqY = zeros(maxLagGlobal, 1);
aggPairs = zeros(maxLagGlobal, 1);

%% --------------------------------------------------------
%% Main loop
%% --------------------------------------------------------

for i = 1:nTraj

    trj = Dataset.Trajectory{i};

    if isempty(trj)
        continue
    end

    if size(trj, 2) < 2
        error('Trajectory %d has fewer than 2 columns.', i);
    end

    x = trj(:, 1);
    y = trj(:, 2);

    nPoint = size(trj, 1);

    if nPoint < 2
        continue
    end

    nLag = min(maxLagCfg, nPoint - 1);

    [lagVec, msdVec, msdXVec, msdYVec, pairCountVec, sumSqVec, sumSqXVec, sumSqYVec] = ...
        computeTrajectoryMSD(x, y, nLag);

    % Store per-trajectory result
    T = struct();
    T.Lag = lagVec;
    T.Time_s = lagVec * dt;
    T.MSD = msdVec;
    T.MSD_X = msdXVec;
    T.MSD_Y = msdYVec;
    T.NPairs = pairCountVec;
    T.NPoints = nPoint;
    T.TrackIndex = i;
    T.Tid = Dataset.Tid(i);
    MSD.PerTrajectory{i} = T;

    % Fill matrices for ensemble statistics
    msdMat(i, 1:nLag) = msdVec(:)';
    msdXMat(i, 1:nLag) = msdXVec(:)';
    msdYMat(i, 1:nLag) = msdYVec(:)';
    pairCountMat(i, 1:nLag) = pairCountVec(:)';

    % Weighted pooled sums
    aggSumSq(1:nLag) = aggSumSq(1:nLag) + sumSqVec(:);
    aggSumSqX(1:nLag) = aggSumSqX(1:nLag) + sumSqXVec(:);
    aggSumSqY(1:nLag) = aggSumSqY(1:nLag) + sumSqYVec(:);
    aggPairs(1:nLag) = aggPairs(1:nLag) + pairCountVec(:);

end

%% --------------------------------------------------------
%% Ensemble statistics
%% --------------------------------------------------------

ensembleLag = (1:maxLagGlobal)';
ensembleTime = ensembleLag * dt;

% Pooled MSD across all displacement pairs
pooledMSD = nan(maxLagGlobal, 1);
pooledMSDX = nan(maxLagGlobal, 1);
pooledMSDY = nan(maxLagGlobal, 1);

validPool = aggPairs > 0;
pooledMSD(validPool) = aggSumSq(validPool) ./ aggPairs(validPool);
pooledMSDX(validPool) = aggSumSqX(validPool) ./ aggPairs(validPool);
pooledMSDY(validPool) = aggSumSqY(validPool) ./ aggPairs(validPool);

% Trajectory-averaged MSD
trajMeanMSD = nan(maxLagGlobal, 1);
trajSEMMSD = nan(maxLagGlobal, 1);
trajN = zeros(maxLagGlobal, 1);

for l = 1:maxLagGlobal
    vals = msdMat(:, l);
    vals = vals(~isnan(vals));
    trajN(l) = numel(vals);
    if ~isempty(vals)
        trajMeanMSD(l) = mean(vals);
        if numel(vals) > 1
            trajSEMMSD(l) = std(vals) / sqrt(numel(vals));
        else
            trajSEMMSD(l) = NaN;
        end
    end
end

%% --------------------------------------------------------
%% Fits
%% --------------------------------------------------------

fitMaxLag = min([fitLagMaxCfg, maxLagGlobal]);
fitIdx = (1:fitMaxLag)';

fitTau = ensembleTime(fitIdx);
fitMSD = pooledMSD(fitIdx);

fitMask = isfinite(fitTau) & isfinite(fitMSD) & fitMSD > 0;

MSD.Fit = struct();

if nnz(fitMask) >= minFitPoints

    xFit = fitTau(fitMask);
    yFit = fitMSD(fitMask);

    % Linear fit: MSD = slope * tau + intercept
    p = polyfit(xFit, yFit, 1);
    yPred = polyval(p, xFit);

    ssRes = sum((yFit - yPred).^2);
    ssTot = sum((yFit - mean(yFit)).^2);

    if ssTot > 0
        r2 = 1 - (ssRes / ssTot);
    else
        r2 = NaN;
    end

    D = p(1) / (2 * dim);

    MSD.Fit.Linear = struct();
    MSD.Fit.Linear.Slope = p(1);
    MSD.Fit.Linear.Intercept = p(2);
    MSD.Fit.Linear.R2 = r2;
    MSD.Fit.Linear.D = D;
    MSD.Fit.Linear.Dim = dim;

    % Power-law fit: MSD = A * tau^alpha
    lx = log(xFit);
    ly = log(yFit);
    p2 = polyfit(lx, ly, 1);

    alpha = p2(1);
    A = exp(p2(2));

    MSD.Fit.PowerLaw = struct();
    MSD.Fit.PowerLaw.Alpha = alpha;
    MSD.Fit.PowerLaw.A = A;

else
    MSD.Fit.Linear = struct();
    MSD.Fit.Linear.Slope = NaN;
    MSD.Fit.Linear.Intercept = NaN;
    MSD.Fit.Linear.R2 = NaN;
    MSD.Fit.Linear.D = NaN;
    MSD.Fit.Linear.Dim = dim;

    MSD.Fit.PowerLaw = struct();
    MSD.Fit.PowerLaw.Alpha = NaN;
    MSD.Fit.PowerLaw.A = NaN;
end

%% --------------------------------------------------------
%% Summary
%% --------------------------------------------------------

MSD.Summary = struct();
MSD.Summary.nTraj = nTraj;
MSD.Summary.MaxLag = maxLagGlobal;
MSD.Summary.Dimension = dim;
MSD.Summary.dt = dt;
MSD.Summary.TotalPairs = aggPairs;
MSD.Summary.TrajectoryLengths = trajLengths;

%% --------------------------------------------------------
%% Save
%% --------------------------------------------------------

MSD.Ensemble = struct();
MSD.Ensemble.Lag = ensembleLag;
MSD.Ensemble.Time_s = ensembleTime;
MSD.Ensemble.PooledMSD = pooledMSD;
MSD.Ensemble.PooledMSD_X = pooledMSDX;
MSD.Ensemble.PooledMSD_Y = pooledMSDY;
MSD.Ensemble.TrajectoryMeanMSD = trajMeanMSD;
MSD.Ensemble.TrajectorySEMMSD = trajSEMMSD;
MSD.Ensemble.NTraj = trajN;
MSD.Ensemble.NPairs = aggPairs;

Project.Analysis.MSD = MSD;

if ~isfield(Project.Validation, 'AnalysisOK')
    Project.Validation.AnalysisOK = false;
end
Project.Validation.AnalysisOK = true;

Project.Flags.Analysis = true;

%% --------------------------------------------------------
%% Display
%% --------------------------------------------------------

fprintf('MSD trajectories     : %d\n', nTraj);
fprintf('Max lag used         : %d\n', maxLagGlobal);
fprintf('Fit lag max          : %d\n', fitMaxLag);

if isfield(MSD, 'Fit') && isfield(MSD.Fit, 'Linear')
    fprintf('Estimated D          : %.6g\n', MSD.Fit.Linear.D);
    fprintf('Linear fit R2        : %.4f\n', MSD.Fit.Linear.R2);
end

if isfield(MSD, 'Fit') && isfield(MSD.Fit, 'PowerLaw')
    fprintf('Estimated alpha      : %.4f\n', MSD.Fit.PowerLaw.Alpha);
end

fprintf('\n');
fprintf('MSD analysis created successfully.\n');
fprintf('=====================================================\n');

end

% =====================================================================
function [lagVec, msdVec, msdXVec, msdYVec, pairCountVec, sumSqVec, sumSqXVec, sumSqYVec] = ...
    computeTrajectoryMSD(x, y, nLag)

lagVec = (1:nLag)';
msdVec = nan(nLag, 1);
msdXVec = nan(nLag, 1);
msdYVec = nan(nLag, 1);
pairCountVec = zeros(nLag, 1);
sumSqVec = zeros(nLag, 1);
sumSqXVec = zeros(nLag, 1);
sumSqYVec = zeros(nLag, 1);

nPoint = numel(x);

for l = 1:nLag
    dx = x(1+l:nPoint) - x(1:nPoint-l);
    dy = y(1+l:nPoint) - y(1:nPoint-l);

    sqX = dx .^ 2;
    sqY = dy .^ 2;
    sq = sqX + sqY;

    pairCountVec(l) = numel(sq);

    if pairCountVec(l) > 0
        msdVec(l) = mean(sq);
        msdXVec(l) = mean(sqX);
        msdYVec(l) = mean(sqY);

        sumSqVec(l) = sum(sq);
        sumSqXVec(l) = sum(sqX);
        sumSqYVec(l) = sum(sqY);
    end
end

end