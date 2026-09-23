function [result, found] = loadCase(caseID, dbPath)
%LOADCASE Retrieve a screening case by Case ID.
%   [RESULT, FOUND] = loadCase(CASEID, DBPATH) loads the case from <dataDir>/cases/<caseID>.mat.

if nargin < 2 || isempty(dbPath)
    dbPath = fullfile('data', 'drishtisetu_db.mat');
end

if isfolder(dbPath) || ~endsWith(char(dbPath), '.mat')
    dataDir = char(dbPath);
else
    dataDir = fileparts(dbPath);
    if isempty(dataDir); dataDir = '.'; end
end

found = false;
result = [];

caseFile = fullfile(dataDir, 'cases', [char(caseID) '.mat']);
if isfile(caseFile)
    loaded = load(caseFile);
    if isfield(loaded, 'caseData')
        result = loaded.caseData;
        found = true;
        saveAudit('CASE_LOADED', caseID, 'Retrieved case successfully.', dataDir);
        return;
    end
end
end
