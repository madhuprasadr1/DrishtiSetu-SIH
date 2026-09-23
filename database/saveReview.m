function db = saveReview(caseID, reviewStatus, varargin)
%SAVEREVIEW Update the human review determination in the database index.
%   DB = saveReview(CASEID, REVIEWSTRUCT, DBPATH) or
%   DB = saveReview(CASEID, REVIEWSTATUS, REVIEWERID, FINALDECISION, NOTES, DBPATH)

if nargin < 1 || isempty(caseID)
    error('database:MissingCaseID', 'Case ID is required.');
end

if nargin >= 2 && isstruct(reviewStatus)
    % Struct syntax: saveReview(caseID, reviewStruct, dbPath)
    revStruct = reviewStatus;
    if nargin >= 3 && ~isempty(varargin{1})
        dbPath = varargin{1};
    else
        dbPath = fullfile('data', 'drishtisetu_db.mat');
    end

    statusStr = 'ACCEPTED';
    if isfield(revStruct, 'status'); statusStr = revStruct.status; end
    
    reviewerID = 'Clinician';
    if isfield(revStruct, 'reviewerID'); reviewerID = revStruct.reviewerID; end

    finalDecision = 'Confirmed';
    if isfield(revStruct, 'finalDeterminedGrade'); finalDecision = string(revStruct.finalDeterminedGrade);
    elseif isfield(revStruct, 'finalGrade'); finalDecision = string(revStruct.finalGrade);
    elseif isfield(revStruct, 'actionTaken'); finalDecision = string(revStruct.actionTaken);
    end

    notes = '';
    if isfield(revStruct, 'notes'); notes = revStruct.notes;
    elseif isfield(revStruct, 'clinicianNotes'); notes = revStruct.clinicianNotes;
    end
else
    % Positional syntax
    if nargin < 2 || isempty(reviewStatus); statusStr = 'ACCEPTED'; else; statusStr = reviewStatus; end
    reviewerID = 'Clinician';
    finalDecision = 'Confirmed';
    notes = '';
    dbPath = fullfile('data', 'drishtisetu_db.mat');

    if numel(varargin) >= 1 && ~isempty(varargin{1}); reviewerID = varargin{1}; end
    if numel(varargin) >= 2 && ~isempty(varargin{2}); finalDecision = varargin{2}; end
    if numel(varargin) >= 3 && ~isempty(varargin{3}); notes = varargin{3}; end
    if numel(varargin) >= 4 && ~isempty(varargin{4}); dbPath = varargin{4}; end
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

cStr = string(caseID);
idx = find(db.cases.caseID == cStr, 1);

if isempty(idx)
    warning('database:CaseNotFound', 'Case %s not found in database index.', caseID);
    return;
end

db.cases.reviewStatus(idx) = string(statusStr);
db.cases.reviewerID(idx) = string(reviewerID);
db.cases.finalDecision(idx) = string(finalDecision);
db.casesTable = db.cases;

save(dbFile, 'db');

% Update case file if present
[cData, found] = loadCase(caseID, dbFile);
if found
    cData.review.status = char(statusStr);
    cData.review.reviewerID = char(reviewerID);
    cData.review.clinicianNotes = char(notes);
    cData.review.reviewTimestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    caseFile = fullfile(dataDir, 'cases', [char(caseID) '.mat']);
    caseData = cData;
    save(caseFile, 'caseData');
end

saveAudit('REVIEW_SAVED', caseID, sprintf('Review updated: %s by %s', statusStr, reviewerID), dataDir);
end
