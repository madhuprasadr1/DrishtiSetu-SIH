function db = saveCase(screeningResult, dbPath)
%SAVECASE Persist a complete screening case and register it in the database index.
%   DB = saveCase(SCREENINGRESULT, DBPATH) saves the detailed result struct
%   to <dataDir>/cases/<caseID>.mat and appends/updates the case row in the index table.

if nargin < 1 || isempty(screeningResult)
    error('database:MissingResult', 'A screening result structure is required.');
end
if nargin < 2 || isempty(dbPath)
    dbPath = fullfile('data', 'drishtisetu_db.mat');
end

if isfolder(dbPath) || ~endsWith(char(dbPath), '.mat')
    dataDir = char(dbPath);
    dbFile = fullfile(dataDir, 'drishtisetu_db.mat');
else
    dbFile = dbPath;
    dataDir = fileparts(dbFile);
    if isempty(dataDir); dataDir = '.'; end
end

db = initializeDatabase(dbFile);

% Extract fields safely
caseID = string(screeningResult.caseID);

patientID = "UNKNOWN";
if isfield(screeningResult, 'patient')
    if isfield(screeningResult.patient, 'pseudoID')
        patientID = string(screeningResult.patient.pseudoID);
    elseif isfield(screeningResult.patient, 'patientID')
        patientID = string(screeningResult.patient.patientID);
    end
end

eye = "OD";
if isfield(screeningResult, 'eye')
    eye = string(screeningResult.eye);
end

timestamp = string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
if isfield(screeningResult, 'acquisition') && isfield(screeningResult.acquisition, 'timestamp')
    timestamp = string(screeningResult.acquisition.timestamp);
end

cameraID = "Standard";
if isfield(screeningResult, 'acquisition') && isfield(screeningResult.acquisition, 'cameraID')
    cameraID = string(screeningResult.acquisition.cameraID);
end

qScore = NaN;
qClass = "UNKNOWN";
if isfield(screeningResult, 'quality')
    if isfield(screeningResult.quality, 'qualityScore')
        qScore = double(screeningResult.quality.qualityScore);
    elseif isfield(screeningResult.quality, 'overallScore')
        qScore = double(screeningResult.quality.overallScore);
    end
    if isfield(screeningResult.quality, 'qualityClass')
        qClass = string(screeningResult.quality.qualityClass);
    elseif isfield(screeningResult.quality, 'overallStatus')
        qClass = string(screeningResult.quality.overallStatus);
    end
end

drGrade = NaN;
calRisk = NaN;
if isfield(screeningResult, 'dr')
    if isfield(screeningResult.dr, 'drGrade')
        drGrade = double(screeningResult.dr.drGrade);
    elseif isfield(screeningResult.dr, 'predictedGrade')
        drGrade = double(screeningResult.dr.predictedGrade);
    end
    if isfield(screeningResult.dr, 'calibratedReferableProbability')
        calRisk = double(screeningResult.dr.calibratedReferableProbability);
    elseif isfield(screeningResult.dr, 'referableProbability')
        calRisk = double(screeningResult.dr.referableProbability);
    end
end

conf = NaN;
uncert = NaN;
safetyStat = "UNKNOWN";
if isfield(screeningResult, 'safety')
    if isfield(screeningResult.safety, 'confidenceScore')
        conf = double(screeningResult.safety.confidenceScore);
    end
    if isfield(screeningResult.safety, 'uncertaintyScore')
        uncert = double(screeningResult.safety.uncertaintyScore);
    elseif isfield(screeningResult.safety, 'normalizedEntropy')
        uncert = double(screeningResult.safety.normalizedEntropy);
    end
    if isfield(screeningResult.safety, 'safetyStatus')
        safetyStat = string(screeningResult.safety.safetyStatus);
    elseif isfield(screeningResult.safety, 'gateStatus')
        safetyStat = string(screeningResult.safety.gateStatus);
    end
end

revStat = "PENDING";
revID = "";
finalDec = "";
if isfield(screeningResult, 'review')
    if isfield(screeningResult.review, 'status')
        revStat = string(screeningResult.review.status);
    end
    if isfield(screeningResult.review, 'reviewerID')
        revID = string(screeningResult.review.reviewerID);
    end
    if isfield(screeningResult.review, 'finalDeterminedGrade')
        finalDec = string(screeningResult.review.finalDeterminedGrade);
    elseif isfield(screeningResult.review, 'finalGrade')
        finalDec = string(screeningResult.review.finalGrade);
    end
end

repPath = "";
if isfield(screeningResult, 'report')
    if isfield(screeningResult.report, 'reportPDFPath')
        repPath = string(screeningResult.report.reportPDFPath);
    elseif isfield(screeningResult.report, 'reportPdfPath')
        repPath = string(screeningResult.report.reportPdfPath);
    end
end

% 1. Save detailed case file
casesDir = fullfile(dataDir, 'cases');
if ~isfolder(casesDir)
    mkdir(casesDir);
end
caseFile = fullfile(casesDir, [char(caseID) '.mat']);
caseData = screeningResult;
save(caseFile, 'caseData');

% 2. Update index table
existingIdx = find(db.cases.caseID == caseID, 1);
newRow = {caseID, patientID, eye, timestamp, cameraID, ...
          qScore, qClass, drGrade, calRisk, ...
          conf, uncert, safetyStat, revStat, ...
          revID, finalDec, repPath};

if isempty(existingIdx)
    db.cases = [db.cases; newRow];
else
    db.cases(existingIdx, :) = newRow;
end
db.casesTable = db.cases;

save(dbFile, 'db');
saveAudit('CASE_SAVED', caseID, sprintf('Saved screening case for patient %s (%s)', patientID, eye), dataDir);
end
