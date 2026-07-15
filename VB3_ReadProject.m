function Project = VB3_ReadProject(inputMAT,hmmMAT)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% VB3 Companion Toolbox v4.1
%
% Module 001
%
% Read Project
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');
fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' Module 001 : Read Project\n');
fprintf('=====================================================\n');

%% --------------------------------------------------------
%% Check files
%% --------------------------------------------------------

if exist(inputMAT,'file')~=2
    error('Cannot find input MAT file.');
end

if exist(hmmMAT,'file')~=2
    error('Cannot find HMM MAT file.');
end

%% --------------------------------------------------------
%% Create empty project
%% --------------------------------------------------------

Project = VB3_ProjectSchema();

%% --------------------------------------------------------
%% Load files
%% --------------------------------------------------------

fprintf('Loading input MAT...\n');
Input = load(inputMAT);

fprintf('Loading HMM MAT...\n');
HMM = load(hmmMAT);

fprintf('Done.\n');

%% ========================================================
%% INFO
%% ========================================================

Project.Info.ProjectName = '';

[~,name,~] = fileparts(inputMAT);

Project.Info.ProjectName = name;

Project.Info.InputFile = inputMAT;

Project.Info.HMMFile = hmmMAT;

Project.Info.Version = 'VB3 Companion Toolbox v4.1';

Project.Info.DateCreated = datestr(now);

Project.Info.Software = 'vbSPT 1.1.4';

%% ========================================================
%% CONFIG
%% ========================================================

Project.Config = VB3_Config();

%% ========================================================
%% RAW
%% ========================================================

Project.Raw.groupAnalysis = Input.groupAnalysis;

Project.Raw.finalTraj = Input.groupAnalysis.finalTraj;

Project.Raw.memberTid = Input.groupAnalysis.memberTids;

Project.Raw.memberIdx = Input.groupAnalysis.memberIdx;

Project.Raw.dt = Input.groupAnalysis.vbSPT_timestep_s;

Project.Raw.nTraj = length(Project.Raw.finalTraj);

Project.Raw.Metadata = struct();

Project.Raw.Metadata.GroupID = Input.groupAnalysis.groupID;

Project.Raw.Metadata.TotalPoints = Input.groupAnalysis.totalPoints;

Project.Raw.Metadata.Source = Input.groupAnalysis.source;

%% ========================================================
%% HMM
%% ========================================================

Project.HMM.Wbest = HMM.Wbest;

Project.HMM.est = HMM.Wbest.est;

Project.HMM.est2 = HMM.Wbest.est2;

Project.HMM.viterbi = HMM.Wbest.est2.viterbi;

Project.HMM.posterior = HMM.Wbest.est2.pst;

Project.HMM.nTraj = length(Project.HMM.viterbi);

%% ========================================================
%% Number of states
%% ========================================================

states = [];

for i = 1:Project.HMM.nTraj

    if isempty(Project.HMM.viterbi{i})
        continue
    end

    states = [states ; Project.HMM.viterbi{i}(:)];

end

Project.HMM.nStates = max(states);

%% ========================================================
%% Validation
%% ========================================================

Project.Validation.RawOK = true;

%% ========================================================
%% Flags
%% ========================================================

Project.Flags.Loaded = true;

%% ========================================================
%% Display
%% ========================================================

fprintf('\n');

fprintf('Project Name       : %s\n',Project.Info.ProjectName);

fprintf('Input trajectories : %d\n',Project.Raw.nTraj);

fprintf('HMM trajectories   : %d\n',Project.HMM.nTraj);

fprintf('Hidden states      : %d\n',Project.HMM.nStates);

fprintf('Time step          : %.4f ms\n',Project.Raw.dt*1000);

fprintf('Total localizations: %d\n',Project.Raw.Metadata.TotalPoints);

fprintf('\n');

fprintf('Project loaded successfully.\n');

fprintf('=====================================================\n');

end