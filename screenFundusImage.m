function result = screenFundusImage(imagePath, varargin)
%SCREENFUNDUSIMAGE Screen a real retinal fundus photograph using DrishtiSetu.
%   RESULT = screenFundusImage(IMAGEPATH) executes the complete, end-to-end
%   offline-first clinical screening pipeline on the provided real fundus image,
%   performing quality gating, anatomical localization, lesion quantification,
%   calibrated 5-level DR severity grading, safety gating, explainable AI,
%   clinical report generation (PDF, PNG, TXT), and estimated 3D retinal
%   vascular visualization.
%
%   Supported real datasets:
%       - APTOS 2019 (DR grading)
%       - DRIVE (Vessel segmentation)
%       - IDRiD (Lesions, DR grading, anatomy)
%       - Messidor-2 (External clinical validation)
%       - OCTA-500 (Cross-modal microvascular structural learning)
%       - Any arbitrary high-resolution fundus photograph (.png, .jpg, .tif, .dcm)
%
%   Name-Value Arguments:
%       'Eye'          - 'OD' (Right Eye) or 'OS' (Left Eye). Default: 'OD'
%       'PatientID'    - Pseudonymous Patient Identifier string. Default: auto
%       'ExportReport' - true/false: whether to generate PDF/PNG reports. Default: true
%       'Save3D'       - true/false: whether to save 3D render to disk. Default: true
%       'LaunchUI'     - true/false: whether to open the interactive UI. Default: false
%
%   Examples:
%       res = screenFundusImage('data/datasets/aptos2019/train_images/000c1434d8d7.png');
%       res = screenFundusImage('data/datasets/drive/training/images/21_training.tif', 'Eye', 'OS');
%       res = screenFundusImage('data/datasets/idrid/1. Original Images/a. Training Set/IDRiD_01.jpg');

if nargin < 1 || isempty(imagePath)
    error('screenFundusImage:MissingInput', ...
        'Please provide a valid fundus image filepath (e.g. from APTOS, DRIVE, IDRiD, or Messidor-2).');
end

% Ensure project paths are active
projectRoot = fileparts(mfilename('fullpath'));
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
addpath(genpath(fullfile(projectRoot, 'app')));

% Parse arguments
parser = inputParser;
parser.addParameter('Eye', 'OD', @(x) ischar(x) || isstring(x));
parser.addParameter('PatientID', '', @(x) ischar(x) || isstring(x));
parser.addParameter('ExportReport', true, @islogical);
parser.addParameter('Save3D', true, @islogical);
parser.addParameter('LaunchUI', false, @islogical);
parser.parse(varargin{:});

eye = char(parser.Results.Eye);
patientID = char(parser.Results.PatientID);
save3D = parser.Results.Save3D;
launchUI = parser.Results.LaunchUI;

if isempty(patientID)
    patientID = ['P-LIVE-' upper(dec2hex(randi([16^4, 16^5-1]), 5))];
end

patientInfo = struct( ...
    'pseudoID', patientID, ...
    'age', 52, ...
    'gender', 'Unspecified', ...
    'diabetesYears', 8, ...
    'eye', eye);

% Verify file existence
if ~isfile(imagePath)
    error('screenFundusImage:FileNotFound', 'The specified image file does not exist: %s', imagePath);
end

fprintf('\n================================================================================\n');
fprintf('DRISHTISETU: REAL FUNDUS CLINICAL SCREENING PIPELINE\n');
fprintf('================================================================================\n');
fprintf('Target Image:       %s\n', imagePath);
fprintf('Patient Pseudo-ID:  %s\n', patientID);
fprintf('Examined Eye:       %s\n', eye);
fprintf('Deployment Mode:    Offline-First Rural Primary Healthcare (PHC)\n\n');

% Execute full pipeline
fprintf('[1/5] Executing clinical screening pipeline (Modules M01 to M12)...\n');
result = runScreeningCase(imagePath, patientInfo, eye);

% Check 3D Visualization (Module M13)
fprintf('[2/5] Checking Estimated 3D Retinal Vascular Visualization (Module M13)...\n');
if isfield(result, 'advanced3D') && strcmp(result.advanced3D.status, 'COMPLETED')
    fprintf('  + 3D Retinal Surface: Reconstructed (Elevation Span: %.1f um)\n', result.advanced3D.elevationSpan);
    
    if save3D && ~isempty(result.advanced3D.rendered3DImage)
        out3DDir = fullfile('results', '3d_visualizations');
        if ~isfolder(out3DDir); mkdir(out3DDir); end
        out3DPath = fullfile(out3DDir, sprintf('DrishtiSetu_3D_%s_%s.png', result.caseID, eye));
        imwrite(result.advanced3D.rendered3DImage, out3DPath);
        result.advanced3D.savedImagePath = out3DPath;
        fprintf('  + 3D Visualization render saved to: %s\n', out3DPath);
    end
else
    fprintf('  * 3D Visualization: %s (Primary DR screening completed independently)\n', ...
        result.advanced3D.status);
end

% Quantitative Measurements (Module M06)
fprintf('[3/5] Extracting Quantitative Lesion Biomarkers (Module M06)...\n');
maCount = result.lesions.microaneurysms.count;
heCount = result.lesions.haemorrhages.count;
exCount = result.lesions.hardExudates.count;
seCount = result.lesions.softExudates.count;
totCount = maCount + heCount + exCount + seCount;

macThreat = 0;
if isfield(result, 'measurements') && isfield(result.measurements, 'macularThreatCount')
    macThreat = result.measurements.macularThreatCount;
end

fprintf('  + Lesion Candidates: Total %d (MA: %d, HE: %d, EX: %d, SE: %d)\n', ...
    totCount, maCount, heCount, exCount, seCount);
fprintf('  + Macular Threat (<1 DD to Fovea): %d candidates\n', macThreat);
fprintf('  + Retinal Vessel Density: %.1f%%\n', result.anatomy.vesselDensity * 100);

% Reports & Persistence
fprintf('[4/5] Checking Clinical Report & Database Persistence...\n');
if result.report.reportGenerated
    fprintf('  + Vector PDF Report: %s\n', result.report.reportPDFPath);
    fprintf('  + PNG Screening Card: %s\n', result.report.reportPNGPath);
    fprintf('  + Clinical Text Summary: %s\n', result.report.reportTextPath);
end

% Executive Summary
fprintf('\n--------------------------------------------------------------------------------\n');
fprintf('EXECUTIVE SCREENING SUMMARY\n');
fprintf('--------------------------------------------------------------------------------\n');
fprintf('Quality Assessment:       %s (Score: %.0f / 100)\n', result.quality.qualityClass, result.quality.qualityScore);
fprintf('ICDR Severity Grade:      Level %d - %s\n', result.dr.drGrade, result.dr.drLabel);
fprintf('Referable DR Decision:    %s (Calibrated Risk: %.1f%%)\n', ...
    string(result.dr.referable), result.dr.calibratedReferableProbability * 100);
fprintf('Model Confidence:         %.1f%%  |  Uncertainty Score: %.1f%%\n', ...
    result.safety.confidenceScore * 100, result.safety.uncertaintyScore * 100);
fprintf('Safety Gate Determination:%s\n', result.safety.safetyStatus);
fprintf('Clinical Triage Action:   %s\n', upper(result.review.status));
if isfield(result, 'advanced3D') && strcmp(result.advanced3D.status, 'COMPLETED')
    fprintf('Estimated 3D Retina (M13):ACTIVE (Span: %.1f um, Mode: %s)\n', ...
        result.advanced3D.elevationSpan, result.advanced3D.mode);
end
fprintf('--------------------------------------------------------------------------------\n\n');

% Optional UI Launch
if launchUI
    fprintf('[5/5] Launching DrishtiSetu UI with this case loaded...\n');
    try
        app = DrishtiSetuApp();
        app.loadUserImage(imagePath);
        app.renderScreeningResult(result);
    catch ME
        warning('screenFundusImage:UILaunch', 'Could not open UI window: %s', ME.message);
    end
else
    fprintf('[5/5] Screening complete. Inspect generated reports and result object.\n\n');
end
end
