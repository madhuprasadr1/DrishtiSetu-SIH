function saveAudit(eventType, caseID, details, dataDir)
%SAVEAUDIT Append an immutable, timestamped audit log entry.
%   saveAudit(EVENTTYPE, CASEID, DETAILS, DATADIR) writes to <dataDir>/drishtisetu_audit.log.

if nargin < 1; eventType = 'GENERAL_EVENT'; end
if nargin < 2 || isempty(caseID); caseID = 'N/A'; end
if nargin < 3; details = ''; end
if nargin < 4 || isempty(dataDir); dataDir = 'data'; end

auditFile = fullfile(dataDir, 'drishtisetu_audit.log');
[auditDir, ~, ~] = fileparts(auditFile);
if ~isempty(auditDir) && ~isfolder(auditDir)
    mkdir(auditDir);
end

timeStr = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
logLine = sprintf('[%s] [%s] [Case: %s] %s\n', timeStr, upper(char(eventType)), char(caseID), char(details));

fid = fopen(auditFile, 'a');
if fid ~= -1
    cleanup = onCleanup(@() fclose(fid));
    fwrite(fid, logLine, 'char');
end
end
