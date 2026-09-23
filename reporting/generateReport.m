function varargout = generateReport(screeningResult, varargin)
%GENERATEREPORT Generate comprehensive clinical DR screening report.
%   REPORTOUTPUT = generateReport(SCREENINGRESULT, 'ResultsRoot', PATH)
%   [PDF, PNG, TXT] = generateReport(SCREENINGRESULT, OUTPUTDIR)
%   creates a professional clinical report (PDF, PNG, and TXT) directly
%   from the canonical 15-field DrishtiSetu screening result object,
%   incorporating both the Estimated 3D Retinal Visualization (M13)
%   and the Quantitative Measurement Engine (M06) biomarkers.

if nargin < 1 || ~isstruct(screeningResult) || ~isscalar(screeningResult)
    error('reporting:InvalidInput', 'A valid scalar screening result structure is required.');
end

resultsRoot = fullfile('results', 'reports');
if numel(varargin) == 1 && (ischar(varargin{1}) || isstring(varargin{1}))
    resultsRoot = char(varargin{1});
elseif numel(varargin) >= 2
    parser = inputParser;
    parser.addParameter('ResultsRoot', fullfile('results', 'reports'), @(x) ischar(x) || isstring(x));
    parser.parse(varargin{:});
    resultsRoot = char(parser.Results.ResultsRoot);
end

if ~isfolder(resultsRoot)
    mkdir(resultsRoot);
end

caseID = 'DS-UNKNOWN';
if isfield(screeningResult, 'caseID'); caseID = char(screeningResult.caseID); end

patientID = 'UNKNOWN';
if isfield(screeningResult, 'patient')
    if isfield(screeningResult.patient, 'pseudoID')
        patientID = char(screeningResult.patient.pseudoID);
    elseif isfield(screeningResult.patient, 'patientID')
        patientID = char(screeningResult.patient.patientID);
    end
end

eye = 'OD';
if isfield(screeningResult, 'eye'); eye = char(screeningResult.eye); end

timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if isfield(screeningResult, 'acquisition') && isfield(screeningResult.acquisition, 'timestamp')
    timestamp = char(screeningResult.acquisition.timestamp);
end

reportBaseName = sprintf('DrishtiSetu_Report_%s_%s', caseID, eye);
pngPath = fullfile(resultsRoot, [reportBaseName '.png']);
pdfPath = fullfile(resultsRoot, [reportBaseName '.pdf']);
txtPath = fullfile(resultsRoot, [reportBaseName '.txt']);

% Create Figure for Graphics Export (1500x1150 high resolution canvas)
fig = figure('Visible', 'off', 'Color', [0.97, 0.98, 0.99], 'Position', [30, 30, 1500, 1150]);
cleanupFig = onCleanup(@() close(fig));

tiled = tiledlayout(fig, 4, 4, 'TileSpacing', 'compact', 'Padding', 'compact');

% Header Title Banner
titleAxes = nexttile(tiled, 1, [1, 4]);
axis(titleAxes, 'off');
headerText = sprintf('DRISHTISETU  |  Offline Explainable AI Retinal Screening Report\nCase ID: %s   |   Patient Pseudo-ID: %s   |   Eye: %s   |   Date: %s', ...
    caseID, patientID, eye, timestamp);
text(titleAxes, 0.01, 0.5, headerText, 'FontSize', 14, 'FontWeight', 'bold', ...
    'Color', [0.08, 0.12, 0.20], 'Interpreter', 'none');

% --- ROW 2: Primary Visual Evidence (Tiles 5, 6, 7, 8) ---
% 1. Original Image
nexttile(tiled, 5);
localShowImg(screeningResult.acquisition.originalImage, '1. Original Fundus Capture');

% 2. Processed Image
nexttile(tiled, 6);
localShowImg(screeningResult.preprocessing.processedImage, '2. Native Retinal Field');

% 3. Grad-CAM Attention
nexttile(tiled, 7);
localShowImg(screeningResult.explainability.gradCAMOverlay, '3. Grad-CAM Attention Saliency');

% 4. Lesion & Anatomy Map
nexttile(tiled, 8);
localShowImg(screeningResult.explainability.lesionOverlay, '4. Lesion Biomarker Localization');

% --- ROW 3: Structural & Advanced 3D Visualization (Tiles 9-10, 11-12) ---
% 5. Retinal Vessel Tree & Density Map (Tile 9, span 1x2)
axVessel = nexttile(tiled, 9, [1, 2]);
if isfield(screeningResult.explainability, 'vesselOverlay') && ~isempty(screeningResult.explainability.vesselOverlay)
    localShowImg(screeningResult.explainability.vesselOverlay, '5. Retinal Vascular Tree & Density Map');
else
    localShowImg(screeningResult.anatomy.vesselMask, '5. Retinal Vascular Segmentation');
end

% 6. Estimated 3D Retinal Vascular Topography (Tile 11, span 1x2)
ax3D = nexttile(tiled, 11, [1, 2]);
has3DImg = false;
if isfield(screeningResult, 'advanced3D') && isfield(screeningResult.advanced3D, 'rendered3DImage') && ...
   ~isempty(screeningResult.advanced3D.rendered3DImage)
    localShowImg(screeningResult.advanced3D.rendered3DImage, ...
        sprintf('6. Estimated 3D Retinal Vascular Visualization (Span: %.0f \\mum)', ...
        screeningResult.advanced3D.elevationSpan));
    has3DImg = true;
elseif isfield(screeningResult, 'advanced3D') && isfield(screeningResult.advanced3D, 'depthInfo') && ...
       isfield(screeningResult.advanced3D.depthInfo, 'zSurface')
    % Render on the fly if needed
    renderedImg = visualizeRetina3D(screeningResult.advanced3D.depthInfo, 'TargetAxes', ax3D);
    has3DImg = true;
end

if ~has3DImg
    axis(ax3D, 'off');
    text(ax3D, 0.1, 0.5, '3D Retinal Visualization: Independent Research Branch', ...
        'FontSize', 11, 'Color', [0.4, 0.4, 0.5]);
    title(ax3D, '6. Estimated 3D Retinal Topography (M13)', 'FontSize', 10, 'FontWeight', 'bold');
end

% --- ROW 4: Clinical Findings & Quantitative Measurements (Tiles 13, 14, 15, 16) ---
% Findings Tile 1: Quality & AI Severity (Tile 13)
axQ = nexttile(tiled, 13);
axis(axQ, 'off');
qClass = screeningResult.quality.qualityClass;
qScore = screeningResult.quality.qualityScore;
drGrade = screeningResult.dr.drGrade;
drLabel = screeningResult.dr.drLabel;
calRisk = screeningResult.dr.calibratedReferableProbability * 100;
conf = screeningResult.safety.confidenceScore * 100;

qText = sprintf(['[IMAGE QUALITY]\nStatus: %s (Score: %.0f/100)\n\n' ...
                 '[AI PREDICTION]\nSeverity: %s\nReferable DR: %s\nCalibrated Risk: %.1f%%\nConfidence: %.1f%%'], ...
    qClass, qScore, drLabel, string(screeningResult.dr.referable), calRisk, conf);
text(axQ, 0.05, 0.5, qText, 'FontSize', 10, 'FontWeight', 'bold', ...
    'Color', [0.1, 0.15, 0.25], 'Interpreter', 'none');

% Findings Tile 2: Quantitative Lesion Measurements (M06) (Tile 14)
axM = nexttile(tiled, 14);
axis(axM, 'off');
ma = screeningResult.lesions.microaneurysms.count;
he = screeningResult.lesions.haemorrhages.count;
ex = screeningResult.lesions.hardExudates.count;
se = screeningResult.lesions.softExudates.count;
vDens = screeningResult.anatomy.vesselDensity * 100;

totCount = ma + he + ex + se;
totArea = 0;
macThreat = 0;
qST = 0; qIT = 0; qSN = 0; qIN = 0;
unitA = 'px';

if isfield(screeningResult, 'measurements') && isstruct(screeningResult.measurements)
    if isfield(screeningResult.measurements, 'totalLesionCount')
        totCount = screeningResult.measurements.totalLesionCount;
    end
    if isfield(screeningResult.measurements, 'totalLesionArea')
        totArea = screeningResult.measurements.totalLesionArea;
    end
    if isfield(screeningResult.measurements, 'macularThreatCount')
        macThreat = screeningResult.measurements.macularThreatCount;
    end
    if isfield(screeningResult.measurements, 'quadrantCounts')
        qST = screeningResult.measurements.quadrantCounts.ST;
        qIT = screeningResult.measurements.quadrantCounts.IT;
        qSN = screeningResult.measurements.quadrantCounts.SN;
        qIN = screeningResult.measurements.quadrantCounts.IN;
    end
    if isfield(screeningResult.measurements, 'unitArea')
        unitA = screeningResult.measurements.unitArea;
    end
end

mText = sprintf(['[QUANTITATIVE LESIONS (M06)]\n' ...
                 'Total Count: %d | Total Area: %.0f %s\n' ...
                 'MA: %d | HE: %d | EX: %d | SE: %d\n' ...
                 'Macular Threat (<1 DD to Fovea): %d\n' ...
                 'Quadrants: ST:%d IT:%d SN:%d IN:%d\n' ...
                 'Vessel Density: %.1f%%'], ...
    totCount, totArea, unitA, ma, he, ex, se, macThreat, qST, qIT, qSN, qIN, vDens);
text(axM, 0.05, 0.5, mText, 'FontSize', 9.5, 'Color', [0.1, 0.15, 0.25], 'Interpreter', 'none');

% Findings Tile 3: Safety Gating & Clinical Triage (Tile 15)
axS = nexttile(tiled, 15);
axis(axS, 'off');
sStat = screeningResult.safety.safetyStatus;
uncert = screeningResult.safety.uncertaintyScore * 100;
ood = string(screeningResult.safety.oodFlag);
revReq = string(screeningResult.safety.reviewRequired);

sText = sprintf(['[SAFETY GATING]\nStatus: %s\nUncertainty: %.1f%%\nOOD Flag: %s\nReview Req: %s\n\n' ...
                 '[CLINICAL TRIAGE]\nTriage: %s'], ...
    sStat, uncert, ood, revReq, upper(screeningResult.review.status));
text(axS, 0.05, 0.5, sText, 'FontSize', 10, 'FontWeight', 'bold', ...
    'Color', [0.1, 0.15, 0.25], 'Interpreter', 'none');

% Findings Tile 4: Review Sign-Off & Legal Notice (Tile 16)
axR = nexttile(tiled, 16);
axis(axR, 'off');
revID = screeningResult.review.reviewerID;
if isempty(revID); revID = 'Pending Ophthalmologist Review'; end
rText = sprintf(['[HUMAN REVIEW SIGN-OFF]\nReviewer: %s\nNotes: %s\n\n' ...
                 'NOTICE: Offline Screening decision support. Clinician sign-off mandatory.'], ...
    revID, screeningResult.review.clinicianNotes);
text(axR, 0.05, 0.5, rText, 'FontSize', 9, 'Color', [0.35, 0.1, 0.1], 'Interpreter', 'none');

% Export PNG and PDF
try
    exportgraphics(fig, pngPath, 'Resolution', 150);
    exportgraphics(fig, pdfPath, 'ContentType', 'vector');
catch
    saveas(fig, pngPath);
end

% Export Companion Text File
elevSpan = 0;
elevMode = 'N/A';
if isfield(screeningResult, 'advanced3D')
    if isfield(screeningResult.advanced3D, 'elevationSpan')
        elevSpan = screeningResult.advanced3D.elevationSpan;
    end
    if isfield(screeningResult.advanced3D, 'mode')
        elevMode = screeningResult.advanced3D.mode;
    end
end

txtContent = sprintf([...
    '================================================================================\n' ...
    'DRISHTISETU CLINICAL RETINAL SCREENING REPORT\n' ...
    'Positioning: Explainable AI for Diabetic Retinopathy Screening in Rural India\n' ...
    '================================================================================\n' ...
    'Case ID:                 %s\n' ...
    'Patient Pseudo-ID:       %s\n' ...
    'Examined Eye:            %s\n' ...
    'Acquisition Timestamp:   %s\n' ...
    'Camera ID:               %s\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'IMAGE QUALITY:\n' ...
    '  Quality Status:        %s\n' ...
    '  Numerical Score:       %.1f / 100\n' ...
    '  Enhancement Applied:   %s\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'DIABETIC RETINOPATHY GRADING:\n' ...
    '  ICDR Severity Grade:   %d - %s\n' ...
    '  Referable DR Status:   %s\n' ...
    '  Calibrated DR Risk:    %.2f%%\n' ...
    '  Softmax Probabilities: [%.3f, %.3f, %.3f, %.3f, %.3f]\n' ...
    '  Model Calibration:     Temperature scaling (T = %.4f)\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'SAFETY & UNCERTAINTY GATING:\n' ...
    '  Confidence Score:      %.2f%%\n' ...
    '  Uncertainty Score:     %.2f%%\n' ...
    '  Out-Of-Distribution:   %s\n' ...
    '  Safety Status:         %s\n' ...
    '  Review Mandatory:      %s\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'LESION & ANATOMICAL FINDINGS (M05 & M06):\n' ...
    '  Microaneurysms:        %d candidates\n' ...
    '  Haemorrhages:          %d candidates\n' ...
    '  Hard Exudates:         %d candidates\n' ...
    '  Soft Exudates:         %d candidates\n' ...
    '  Total Lesion Count:    %d\n' ...
    '  Total Lesion Area:     %.1f %s\n' ...
    '  Macular Threat (<1DD): %d candidates\n' ...
    '  Retinal Quadrants:     ST: %d, IT: %d, SN: %d, IN: %d\n' ...
    '  Retinal Vessel Density:%.2f%%\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'ADVANCED 3D VASCULAR VISUALIZATION (M13 - Decoupled):\n' ...
    '  3D Status:             %s\n' ...
    '  Elevation Span:        %.1f microns\n' ...
    '  Reconstruction Mode:   %s\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'EXPLANATION & DECISION SUPPORT:\n' ...
    '%s\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'HUMAN-IN-THE-LOOP REVIEW:\n' ...
    '  Review Status:         %s\n' ...
    '  Reviewer ID:           %s\n' ...
    '  Clinician Notes:       %s\n' ...
    '--------------------------------------------------------------------------------\n' ...
    'DISCLAIMER & REGULATORY NOTICE:\n' ...
    '  Investigational Screening Decision Support. Clinician verification mandatory.\n' ...
    '================================================================================\n'], ...
    caseID, patientID, eye, timestamp, screeningResult.acquisition.cameraID, ...
    qClass, qScore, string(screeningResult.quality.isEnhanced), ...
    drGrade, drLabel, string(screeningResult.dr.referable), calRisk, ...
    screeningResult.dr.rawProbabilities(1), screeningResult.dr.rawProbabilities(2), ...
    screeningResult.dr.rawProbabilities(3), screeningResult.dr.rawProbabilities(4), ...
    screeningResult.dr.rawProbabilities(5), screeningResult.dr.temperature, ...
    conf, uncert, ood, sStat, revReq, ...
    ma, he, ex, se, totCount, totArea, unitA, macThreat, qST, qIT, qSN, qIN, vDens, ...
    screeningResult.advanced3D.status, elevSpan, elevMode, ...
    screeningResult.explainability.explanationNarrative, ...
    screeningResult.review.status, revID, screeningResult.review.clinicianNotes);

fid = fopen(txtPath, 'w');
if fid ~= -1
    fwrite(fid, txtContent, 'char');
    fclose(fid);
end

reportOutput = struct();
reportOutput.reportPDFPath = string(pdfPath);
reportOutput.reportPNGPath = string(pngPath);
reportOutput.reportTextPath = string(txtPath);
reportOutput.reportPdfPath = string(pdfPath);
reportOutput.reportPngPath = string(pngPath);
reportOutput.reportTxtPath = string(txtPath);
reportOutput.summaryText = string(txtContent);

% Update screeningResult structure
screeningResult.report.reportGenerated = true;
screeningResult.report.reportPDFPath = char(pdfPath);
screeningResult.report.reportPNGPath = char(pngPath);
screeningResult.report.reportTextPath = char(txtPath);
screeningResult.report.summaryText = char(txtContent);

if nargout <= 1
    varargout{1} = reportOutput;
else
    varargout{1} = char(pdfPath);
    varargout{2} = char(pngPath);
    varargout{3} = char(txtPath);
end
end

function localShowImg(img, titleStr)
if isempty(img)
    axis off;
    text(0.1, 0.5, 'Image not available', 'FontSize', 10);
    title(titleStr, 'FontSize', 10, 'FontWeight', 'bold');
else
    imshow(img);
    title(titleStr, 'FontSize', 10, 'FontWeight', 'bold');
end
end
