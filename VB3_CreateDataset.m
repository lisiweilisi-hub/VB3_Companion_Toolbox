function Project = VB3_CreateDataset(Project,Config)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% VB3 Companion Toolbox v4.1
%
% Module 002
%
% Create Analysis Ready Dataset
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' Module 002 : Create Dataset\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

if ~Project.Flags.Loaded
    error('Project has not been loaded.');
end

if ~Project.Validation.RawOK
    error('Raw data validation failed.');
end

%% --------------------------------------------------------
%% Parameter
%% --------------------------------------------------------

if nargin<2 || isempty(Config)
    Config = Project.Config;
end

minLength = Config.MinTrajectoryLength;

%% --------------------------------------------------------
%% Shortcuts
%% --------------------------------------------------------

Raw = Project.Raw;
HMM = Project.HMM;

%% --------------------------------------------------------
%% Initialize Dataset
%% --------------------------------------------------------

Dataset = struct();

Dataset.nTraj = 0;

Dataset.Trajectory = {};

Dataset.Tid = [];

Dataset.RawIndex = [];

Dataset.Length = [];

Dataset.dt = Raw.dt;

Dataset.State = {};

Dataset.Posterior = {};

Dataset.Mapping = table();

Dataset.Metadata = struct();

Dataset.Summary = struct();

%% --------------------------------------------------------
%% Trajectory filtering
%% --------------------------------------------------------

keep = false(Raw.nTraj,1);

Length = zeros(Raw.nTraj,1);

for i = 1:Raw.nTraj

    trj = Raw.finalTraj{i};

    if isempty(trj)

        Length(i)=0;
        continue

    end

    % Official vbSPT definition
    Length(i)=size(trj,1);

    if Length(i)>=minLength

        keep(i)=true;

    end

end

%% --------------------------------------------------------
%% Copy trajectories
%% --------------------------------------------------------

Dataset.Trajectory = Raw.finalTraj(keep);

Dataset.Tid = Raw.memberTid(keep);

Dataset.RawIndex = Raw.memberIdx(keep);

Dataset.Length = Length(keep);

Dataset.nTraj = length(Dataset.Trajectory);

Dataset.dt = Raw.dt;

%% --------------------------------------------------------
%% HMM Mapping
%% --------------------------------------------------------

if Dataset.nTraj ~= HMM.nTraj

    error(['Dataset trajectories (' num2str(Dataset.nTraj) ...
        ') do not match HMM trajectories (' ...
        num2str(HMM.nTraj) ').']);

end

Dataset.State = HMM.viterbi;

Dataset.Posterior = HMM.posterior;

%% --------------------------------------------------------
%% Mapping Table
%% --------------------------------------------------------

Mapping = table();

Mapping.DatasetIndex = (1:Dataset.nTraj)';

Mapping.RawIndex = Dataset.RawIndex(:);

Mapping.Tid = Dataset.Tid(:);

Mapping.Length = Dataset.Length(:);

Dataset.Mapping = Mapping;

%% --------------------------------------------------------
%% Metadata
%% --------------------------------------------------------

Metadata = struct();

Metadata.Software = Project.Info.Software;

Metadata.Version = Project.Info.Version;

Metadata.MinTrajectoryLength = minLength;

Metadata.Created = datestr(now);

Metadata.TimeStep = Dataset.dt;

Dataset.Metadata = Metadata;

%% --------------------------------------------------------
%% Summary
%% --------------------------------------------------------

Summary = struct();

Summary.nTraj = Dataset.nTraj;

Summary.TotalLocalizations = sum(Dataset.Length);

Summary.TotalTime = Summary.TotalLocalizations * Dataset.dt;

Summary.MeanLength = mean(Dataset.Length);

Summary.MedianLength = median(Dataset.Length);

Summary.MinLength = min(Dataset.Length);

Summary.MaxLength = max(Dataset.Length);

Summary.dt = Dataset.dt;

Summary.nStates = HMM.nStates;

Dataset.Summary = Summary;

%% --------------------------------------------------------
%% Save
%% --------------------------------------------------------

Project.Dataset = Dataset;

%% --------------------------------------------------------
%% Validation
%% --------------------------------------------------------

Project.Validation.DatasetOK = true;

Project.Validation.MappingOK = true;

%% --------------------------------------------------------
%% Flags
%% --------------------------------------------------------

Project.Flags.Dataset = true;

%% --------------------------------------------------------
%% Display
%% --------------------------------------------------------

fprintf('Dataset trajectories : %d\n',Dataset.nTraj);

fprintf('Number of states     : %d\n',Summary.nStates);

fprintf('Total localizations  : %d\n',Summary.TotalLocalizations);

fprintf('Mean length          : %.2f\n',Summary.MeanLength);

fprintf('Median length        : %.2f\n',Summary.MedianLength);

fprintf('Trajectory length    : %d - %d\n', ...
    Summary.MinLength,...
    Summary.MaxLength);

fprintf('Time step            : %.4f ms\n',Dataset.dt*1000);

fprintf('\n');

fprintf('Dataset created successfully.\n');

fprintf('=====================================================\n');

end