function Project = VB3_ProjectSchema()

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% VB3 Companion Toolbox v4.1
%
% Project Data Model
%
% MATLAB R2016b
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project = struct();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% INFO
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Info = struct();

Project.Info.ProjectName = '';
Project.Info.Version = 'VB3 Companion Toolbox v4.1';
Project.Info.Software = 'vbSPT 1.1.4';
Project.Info.InputFile = '';
Project.Info.HMMFile = '';
Project.Info.DateCreated = datestr(now);
Project.Info.User = '';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CONFIG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Config = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% RAW  (Never modified)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Raw = struct();

Project.Raw.groupAnalysis = [];

Project.Raw.finalTraj = {};

Project.Raw.memberTid = [];

Project.Raw.memberIdx = [];

Project.Raw.dt = [];

Project.Raw.nTraj = 0;

Project.Raw.Metadata = struct();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DATASET  (Analysis Ready Dataset)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Dataset = struct();

Project.Dataset.nTraj = 0;

Project.Dataset.Trajectory = {};

Project.Dataset.State = {};

Project.Dataset.Posterior = {};

Project.Dataset.Tid = [];

Project.Dataset.RawIndex = [];

Project.Dataset.Length = [];

Project.Dataset.dt = [];

Project.Dataset.Mapping = table();

Project.Dataset.Metadata = struct();

Project.Dataset.Summary = struct();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GEOMETRY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Geometry = struct();

Project.Geometry.StepLength = {};

Project.Geometry.Displacement = {};

Project.Geometry.Direction = {};

Project.Geometry.Velocity = {};

Project.Geometry.Acceleration = {};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% HMM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.HMM = struct();

Project.HMM.Wbest = [];

Project.HMM.est = [];

Project.HMM.est2 = [];

Project.HMM.viterbi = {};

Project.HMM.posterior = {};

Project.HMM.nStates = 0;

Project.HMM.nTraj = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% TABLES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Tables = struct();

Project.Tables.Localization = table();

Project.Tables.Segment = table();

Project.Tables.Track = table();

Project.Tables.State = table();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ANALYSIS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Analysis = struct();

Project.Analysis.MSD = struct();

Project.Analysis.TurningAngle = struct();

Project.Analysis.Confinement = struct();

Project.Analysis.Diffusion = struct();

Project.Analysis.ResidenceTime = struct();

Project.Analysis.Transition = struct();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FIGURES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Figures = struct();

Project.Figures.Track = [];

Project.Figures.Heatmap = [];

Project.Figures.MSD = [];

Project.Figures.TurningAngle = [];

Project.Figures.Confinement = [];

Project.Figures.Transition = [];

Project.Figures.Publication = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXPORT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Export = struct();

Project.Export.OutputFolder = '';

Project.Export.CSVFolder = '';

Project.Export.FigureFolder = '';

Project.Export.ReportFolder = '';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% VALIDATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Validation = struct();

Project.Validation.RawOK = false;

Project.Validation.DatasetOK = false;

Project.Validation.GeometryOK = false;

Project.Validation.MappingOK = false;

Project.Validation.LocalizationOK = false;

Project.Validation.SegmentOK = false;

Project.Validation.TrackOK = false;

Project.Validation.AnalysisOK = false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FLAGS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Project.Flags = struct();

Project.Flags.Loaded = false;

Project.Flags.Dataset = false;

Project.Flags.Geometry = false;

Project.Flags.Localization = false;

Project.Flags.Segmentation = false;

Project.Flags.Track = false;

Project.Flags.Transition = false;

Project.Flags.Statistics = false;

Project.Flags.Analysis = false;

Project.Flags.Figures = false;

Project.Flags.Export = false;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Display
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf('\n');

fprintf('=====================================================\n');
fprintf(' VB3 Companion Toolbox v4.1\n');
fprintf(' Project Schema Initialized\n');
fprintf('=====================================================\n');

fprintf('Project Layers\n');
fprintf('  Info\n');
fprintf('  Config\n');
fprintf('  Raw\n');
fprintf('  Dataset\n');
fprintf('  Geometry\n');
fprintf('  HMM\n');
fprintf('  Tables\n');
fprintf('  Analysis\n');
fprintf('  Figures\n');
fprintf('  Export\n');
fprintf('  Validation\n');
fprintf('  Flags\n');

fprintf('=====================================================\n');

end