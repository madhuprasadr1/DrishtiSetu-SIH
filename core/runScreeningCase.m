function result = runScreeningCase(imageInput, patientInfo, eyeSelection, customConfig)
%RUNSCREENINGCASE Canonical end-to-end clinical screening pipeline for DrishtiSetu.
%   RESULT = runScreeningCase(IMAGEINPUT, PATIENTINFO, EYESELECTION, CONFIG)
%   executes the complete offline screening workflow:
%
%   1. Image Acquisition & Validation (preserves original image untouched)
%   2. Quality Assessment (sharpness, exposure, illumination, FOV)
%   3. Borderline Enhancement & Reassessment / Recapture Triage
%   4. Retinal Preprocessing (uniform train/val/inference parity)
%   5. Retinal Anatomy Analysis (retinal FOV, optic disc, fovea, vessels)
%   6. Lesion Detection & Candidate Segmentation (MAs, HEs, EXs, SEs)
%   7. Diabetic Retinopathy 5-Level Grading & Referable DR Screening
%   8. Temperature Scaling Calibration & Confidence Estimation
%   9. Shannon Entropy Uncertainty Quantification
%   10. Out-of-Distribution (OOD) Anomaly Detection
%   11. Uncertainty-Aware Safety Gating & 3-Way Triage (Auto-Clear, Refer, Escalate)
%   12. Explainability (Grad-CAM, Lesion Map, Vessel Tree, Dynamic Narrative)
%   13. Clinical Screening Report Generation (PDF, PNG, TXT)
%   14. Immutable Local Database & Audit Logging
%
%   Returns the canonical 14-field screening result object.

ticStart = tic;

if nargin < 2 || isempty(patientInfo)
    patientInfo = struct('pseudoID', ['P-' upper(dec2hex(randi([16^4, 16^5-1]), 5))], ...
        'age', 56, 'gender', 'Unspecified', 'diabetesYears', 8);
end
if nargin >= 3 && isstruct(eyeSelection)
    config = eyeSelection;
    if isfield(patientInfo, 'eye')
        eyeSelection = patientInfo.eye;
    else
        eyeSelection = 'OD';
    end
else
    if nargin < 3 || isempty(eyeSelection)
        eyeSelection = 'OD';
    end
    if nargin < 4 || isempty(customConfig)
        config = projectConfig();
    else
        if ischar(customConfig) || isstring(customConfig)
            config = jsondecode(fileread(char(customConfig)));
        else
            config = customConfig;
        end
    end
end

% 1. Create Base Screening Result Object
result = createScreeningResult(imageInput, patientInfo, eyeSelection);

% 2. Acquisition & Image Validation
try
    [originalImage, imagePath, meta] = loadFundusImage(imageInput);
    result.acquisition.originalImage = originalImage;
    result.acquisition.imagePath = imagePath;
    result.acquisition.metadata = meta;
catch ME
    result.quality.qualityClass = 'BAD';
    result.safety.safetyStatus = 'RECAPTURE_REQUIRED';
    result.safety.reasonCodes = {'unreadable-image-file'};
    result.safety.warnings = {sprintf('Image loading error: %s', ME.message)};
    saveAudit('SCREENING_ABORTED', result.caseID, ME.message);
    return;
end

% 3. Quality Assessment
[qResult, qualityProcessedImage] = assessQuality(originalImage, config);
result.quality = qResult;

% If Quality is BAD: halt downstream analysis and return recapture advice
if strcmp(qResult.qualityClass, 'BAD') || strcmp(qResult.qualityClass, 'UNGRADABLE')
    result.status = 'GATED_RECAPTURE';
    result.safety.safetyStatus = 'RECAPTURE_REQUIRED';
    result.safety.gateStatus = 'RECAPTURE_REQUIRED';
    result.safety.reviewRequired = true;
    result.safety.reasonCodes = {'quality-ungradable'};
    result.safety.warnings = qResult.failureReasons;
    result.review.status = 'RECAPTURE_ORDERED';
    result.explainability.explanationNarrative = sprintf('Image quality is ungradable (Score: %.0f/100). Please recapture following guidance.', qResult.qualityScore);
    
    % Save audit & case
    saveAudit('QUALITY_GATE_STOPPED', result.caseID, 'Screening stopped by quality gate.');
    saveCase(result);
    return;
end

% 4. Retinal Preprocessing (Preserve native image quality unaltered)
[modelInputImage, ~, prepMeta] = preprocessFundus(originalImage, config, 'inference');
result.preprocessing.processedImage = originalImage; % Native quality preserved
result.preprocessing.modelInputImage = modelInputImage;
result.preprocessing.cropBBox = prepMeta.fovBoundingBox;
result.preprocessing.qualityPreserved = true;
result.preprocessing.originalImage = originalImage;

% 5. Retinal Anatomy Analysis (Runs on native high-fidelity image)
anatomyRes = analyzeAnatomy(originalImage, config, eyeSelection);
result.anatomy = anatomyRes;

% 6. Lesion Detection & Candidate Segmentation (Runs on native high-fidelity image)
lesionRes = detectLesions(originalImage, config, anatomyRes);
result.lesions = lesionRes;

% 6b. Quantitative Measurement Engine (M06)
try
    measRes = measureLesions(originalImage, lesionRes, anatomyRes, config);
    result.measurements = measRes;
catch ME
    warning('measurements:ExecutionFailed', 'Quantitative measurement warning: %s', ME.message);
end

% 7. 5-Level DR Grading & Temperature Scaling
drRes = inferDRGrade(modelInputImage, config, lesionRes);
result.dr = drRes;

% 8. Out-Of-Distribution (OOD) Check
oodRes = detectOOD(originalImage, anatomyRes.retinalMask, qResult.features);

% 9. Uncertainty-Aware Safety Gating
safetyRes = safetyGate(qResult, drRes, lesionRes, oodRes, config);
result.safety = safetyRes;

% 10. Three-Way Clinical Triage Decision
decisionRes = decisionPolicy(result, config);
result.safety.decision = decisionRes.decision;
result.safety.decisionReason = decisionRes.decisionReason;

% 11. Explainability & Attention Heatmaps
modelCheckpoint = '';
if isfield(drRes, 'modelCheckpoint'); modelCheckpoint = drRes.modelCheckpoint; end
[gradHeatmap, gradOverlay] = generateGradCAM(qualityProcessedImage, ...
    drRes.drGrade, modelCheckpoint, lesionRes);
result.explainability.gradCAMHeatmap = gradHeatmap;
result.explainability.gradCAMOverlay = gradOverlay;

% Lesion Map Overlay
lesionMap = generateLesionMap(qualityProcessedImage, lesionRes, anatomyRes);
result.explainability.lesionOverlay = lesionMap;
result.explainability.lesionMapOverlay = lesionMap;

% Vessel Map Overlay
vesselMap = generateVesselMap(qualityProcessedImage, anatomyRes.vesselMask, anatomyRes.vesselSkeleton);
result.explainability.vesselOverlay = vesselMap;
result.explainability.vesselMapOverlay = vesselMap;

% Dynamic Narrative Explanation
narrative = buildExplanation(drRes, lesionRes, anatomyRes, safetyRes);
result.explainability.explanationNarrative = narrative;
result.explainability.narrative = narrative;
result.explainability.spatialAgreement = decisionRes.agreementStatus;

% 12. Human-in-the-Loop Review Seam
if strcmp(safetyRes.safetyStatus, 'HUMAN_REVIEW_REQUIRED')
    result.review.status = 'PENDING';
elseif strcmp(safetyRes.safetyStatus, 'SAFE_FOR_AI_ASSISTED_RESULT')
    result.review.status = 'AI_CLEARED_PENDING_SIGNOFF';
else
    result.review.status = 'RECAPTURE_ORDERED';
end

% Set DR convenience aliases
result.dr.predictedGrade = drRes.drGrade;
result.dr.isReferable = drRes.referable;

% 13. Advanced Estimated 3D Retinal Visualization (M13 - Decoupled)
try
    out3D = constructPseudo3D(originalImage, anatomyRes, lesionRes, config);
    result.advanced3D = out3D;
catch ME
    result.advanced3D.status = 'FAILED';
    result.advanced3D.errorMessage = ME.message;
    warning('advanced3D:PipelineWarning', '3D reconstruction bypassed: %s', ME.message);
end

% 14. Clinical Screening Report Generation
try
    repOut = generateReport(result);
    result.report.reportGenerated = true;
    result.report.reportPDFPath = char(repOut.reportPDFPath);
    result.report.reportPdfPath = char(repOut.reportPDFPath);
    result.report.reportPNGPath = char(repOut.reportPNGPath);
    result.report.reportPngPath = char(repOut.reportPNGPath);
    result.report.reportTextPath = char(repOut.reportTextPath);
    result.report.reportTxtPath = char(repOut.reportTextPath);
    result.report.summaryText = char(repOut.summaryText);
catch ME
    result.report.reportGenerated = false;
    result.report.summaryText = sprintf('Report export notice: %s', ME.message);
end

% 14. Audit & Provenance Timing
result.audit.inferenceDurationSeconds = toc(ticStart);
result.audit.executionEnvironment = 'CPU (Offline Native MATLAB)';
if canUseGPU
    result.audit.executionEnvironment = 'GPU Accelerated';
end

result.status = 'COMPLETED';

% 15. Database Persistence
saveCase(result);
saveAudit('SCREENING_COMPLETED', result.caseID, ...
    sprintf('DR Grade: %d (%s), Decision: %s in %.2fs', ...
    drRes.drGrade, drRes.drLabel, decisionRes.decision, result.audit.inferenceDurationSeconds));
end
