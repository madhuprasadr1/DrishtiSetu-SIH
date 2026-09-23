function db = initializeDatabase(dbPath)
%INITIALIZEDATABASE Initialize local offline persistence layer for DrishtiSetu.
%   DB = initializeDatabase(DBPATH) initializes or loads the local database
%   and ensures the schema tables and audit logs are ready.

if nargin < 1 || isempty(dbPath)
    dbPath = fullfile('data', 'drishtisetu_db.mat');
end

if isfolder(dbPath) || ~endsWith(char(dbPath), '.mat')
    dbDir = char(dbPath);
    dbPath = fullfile(dbDir, 'drishtisetu_db.mat');
else
    [dbDir, ~, ~] = fileparts(dbPath);
    if isempty(dbDir)
        dbDir = '.';
    end
end

if ~isfolder(dbDir)
    mkdir(dbDir);
end

casesDir = fullfile(dbDir, 'cases');
if ~isfolder(casesDir)
    mkdir(casesDir);
end

auditLogPath = fullfile(dbDir, 'drishtisetu_audit.log');
if ~isfile(auditLogPath)
    fid = fopen(auditLogPath, 'w');
    if fid ~= -1
        fclose(fid);
    end
end

if isfile(dbPath)
    loaded = load(dbPath);
    if isfield(loaded, 'db')
        db = loaded.db;
        db.casesTable = db.cases;
        return;
    end
end

% Create new database structure
db = struct();
db.version = '1.0.0';
db.createdTimestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
db.cases = table('Size', [0, 16], ...
    'VariableTypes', {'string', 'string', 'string', 'string', 'string', ...
                      'double', 'string', 'double', 'double', 'double', ...
                      'double', 'string', 'string', 'string', 'string', 'string'}, ...
    'VariableNames', {'caseID', 'patientPseudoID', 'eye', 'timestamp', 'cameraID', ...
                      'qualityScore', 'qualityClass', 'drGrade', 'calibratedRisk', ...
                      'confidence', 'uncertainty', 'safetyStatus', 'reviewStatus', ...
                      'reviewerID', 'finalDecision', 'reportPath'});
db.casesTable = db.cases;

save(dbPath, 'db');
saveAudit('DB_INITIALIZED', 'SYSTEM', 'Database initialized successfully.', dbDir);
end
