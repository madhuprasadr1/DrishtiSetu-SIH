function appInstance = main_DrishtiSetu(varargin)
%MAIN_DRISHTISETU Canonical startup and initialization entry point for DrishtiSetu.
%   app = main_DrishtiSetu() initializes paths, checks required toolboxes,
%   validates local database persistence, checks model availability,
%   populates demo dataset if needed, and launches the DrishtiSetuApp UI.
%
%   Name-value arguments:
%       'Headless' - true/false: if true, performs checks and returns without UI.

parser = inputParser;
parser.addParameter('Headless', false, @islogical);
parser.parse(varargin{:});
headless = parser.Results.Headless;

fprintf('================================================================================\n');
fprintf('DRISHTISETU: Explainable AI for Diabetic Retinopathy Screening in Rural India\n');
fprintf('Version: 1.0.0-MVP  |  Offline-First Primary Healthcare Deployment\n');
fprintf('================================================================================\n\n');

% 1. Initialize Paths
projectRoot = fileparts(mfilename('fullpath'));
fprintf('[1/6] Initializing project paths at %s...\n', projectRoot);
addpath(projectRoot);
addpath(genpath(fullfile(projectRoot, 'config')));
addpath(genpath(fullfile(projectRoot, 'core')));
addpath(genpath(fullfile(projectRoot, 'acquisition')));
addpath(genpath(fullfile(projectRoot, 'quality')));
addpath(genpath(fullfile(projectRoot, 'preprocessing')));
addpath(genpath(fullfile(projectRoot, 'anatomy')));
addpath(genpath(fullfile(projectRoot, 'lesions')));
addpath(genpath(fullfile(projectRoot, 'measurements')));
addpath(genpath(fullfile(projectRoot, 'grading')));
addpath(genpath(fullfile(projectRoot, 'safety')));
addpath(genpath(fullfile(projectRoot, 'explainability')));
addpath(genpath(fullfile(projectRoot, 'advanced3D')));
addpath(genpath(fullfile(projectRoot, 'review')));
addpath(genpath(fullfile(projectRoot, 'reporting')));
addpath(genpath(fullfile(projectRoot, 'database')));
addpath(genpath(fullfile(projectRoot, 'simulation')));
addpath(genpath(fullfile(projectRoot, 'validation')));
addpath(genpath(fullfile(projectRoot, 'demo')));
addpath(genpath(fullfile(projectRoot, 'app')));

% 2. Check Required Toolboxes
fprintf('[2/6] Verifying MATLAB toolboxes...\n');
requiredToolboxes = {'Image Processing Toolbox', 'Computer Vision Toolbox', ...
    'Deep Learning Toolbox', 'Statistics and Machine Learning Toolbox'};
v = ver;
installedNames = {v.Name};

for k = 1:numel(requiredToolboxes)
    tName = requiredToolboxes{k};
    if ismember(tName, installedNames)
        fprintf('  + %-40s: INSTALLED\n', tName);
    else
        fprintf('  ! %-40s: NOT FOUND (some features may run in fallback mode)\n', tName);
    end
end

% Check Simulink / Stateflow for simulation
if ismember('Simulink', installedNames) && ismember('Stateflow', installedNames)
    fprintf('  + %-40s: INSTALLED (PHC discrete-event model enabled)\n', 'Simulink & Stateflow');
else
    fprintf('  ! %-40s: UNAVAILABLE (Simulink simulation disabled)\n', 'Simulink / Stateflow');
end

% 3. Initialize Local Database
fprintf('[3/6] Initializing local database and audit subsystem...\n');
try
    db = initializeDatabase();
    fprintf('  + Local screening registry initialized (%d cases on record).\n', height(db.cases));
catch ME
    warning('database:InitFailed', 'Failed to initialize database: %s', ME.message);
end

% 4. Check Models
fprintf('[4/6] Checking AI model checkpoints...\n');
mCfg = modelConfig();
models = { ...
    'DR 5-Level ResNet50 Classifier', mCfg.grading.checkpoint; ...
    'Multi-Head Lesion U-Net', mCfg.lesions.checkpoint; ...
    'Retinal Vessel U-Net', mCfg.vessels.checkpoint ...
};

for m = 1:size(models, 1)
    mName = models{m, 1};
    mPath = models{m, 2};
    if isfile(mPath)
        fprintf('  + %-35s: READY (%s)\n', mName, mPath);
    else
        fprintf('  * %-35s: NOT FOUND -> Transparent Rule/Morphological Fallback Enabled\n', mName);
    end
end

% 5. Live Clinical Intake Readiness
fprintf('[5/5] Ready for live clinical fundus intake (Original high-fidelity image mode enabled).\n');

% 6. Launch Application or Return Headless
appInstance = [];
if headless
    fprintf('Headless mode: initialization complete.\n\n');
else
    fprintf('Launching DrishtiSetu Clinical Screening Interface...\n\n');
    try
        appInstance = DrishtiSetuApp();
        fprintf('DrishtiSetu application window opened successfully.\n');
    catch ME
        warning('app:LaunchFailed', 'Failed to open UI: %s\nRun core screening functions via runScreeningCase().', ME.message);
    end
end
end
