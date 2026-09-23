classdef test_database < matlab.unittest.TestCase
    % TEST_DATABASE Tests offline structured MAT-file database, case retrieval, review updates, and audit logging.

    properties
        tempDataDir
    end

    methods (TestMethodSetup)
        function createTempDir(testCase)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));

            testCase.tempDataDir = fullfile(tempdir, ['ds_db_test_' num2str(randi(1000000))]);
            mkdir(testCase.tempDataDir);
        end
    end

    methods (TestMethodTeardown)
        function removeTempDir(testCase)
            if isfolder(testCase.tempDataDir)
                rmdir(testCase.tempDataDir, 's');
            end
        end
    end

    methods (Test)
        function testDatabaseInitAndSaveCase(testCase)
            db = initializeDatabase(testCase.tempDataDir);
            testCase.verifyTrue(isfield(db, 'casesTable'));
            testCase.verifyTrue(isfile(fullfile(testCase.tempDataDir, 'drishtisetu_db.mat')));
            testCase.verifyTrue(isfile(fullfile(testCase.tempDataDir, 'drishtisetu_audit.log')));

            % Create a mock case result
            mockRes = createScreeningResult();
            mockRes.caseID = 'DS-TEST-DB-001';
            mockRes.patient.patientID = 'PAT-DB-123';
            mockRes.patient.age = 52;
            mockRes.dr.predictedGrade = 2;
            mockRes.dr.isReferable = true;
            mockRes.dr.decisionPolicy.decision = 'REFER';
            mockRes.safety.gateStatus = 'SAFE_FOR_AI_ASSISTED_RESULT';
            mockRes.quality.overallStatus = 'GOOD';
            mockRes.quality.overallScore = 0.88;

            db = saveCase(mockRes, testCase.tempDataDir);
            testCase.verifyEqual(height(db.casesTable), 1);
            testCase.verifyEqual(char(db.casesTable.caseID(1)), 'DS-TEST-DB-001');

            % Load back
            [loadedRes, found] = loadCase('DS-TEST-DB-001', testCase.tempDataDir);
            testCase.verifyTrue(found);
            testCase.verifyEqual(loadedRes.caseID, 'DS-TEST-DB-001');
            testCase.verifyEqual(loadedRes.dr.predictedGrade, 2);
        end

        function testSaveReviewAndUpdate(testCase)
            initializeDatabase(testCase.tempDataDir);

            mockRes = createScreeningResult();
            mockRes.caseID = 'DS-REV-001';
            mockRes.patient.patientID = 'PAT-REV-01';
            mockRes.dr.predictedGrade = 1;
            mockRes.dr.isReferable = false;
            mockRes.dr.decisionPolicy.decision = 'AUTO_CLEAR';
            mockRes.safety.gateStatus = 'SAFE_FOR_AI_ASSISTED_RESULT';
            mockRes.quality.overallStatus = 'GOOD';
            mockRes.quality.overallScore = 0.85;

            saveCase(mockRes, testCase.tempDataDir);

            % Review the case
            revStruct = struct('status', 'ACCEPTED', ...
                               'reviewerID', 'OPHTHAL-07', ...
                               'finalGrade', 1, ...
                               'actionTaken', 'Routine 12m follow-up confirmed', ...
                               'notes', 'Confirmed mild MAs, agree with AI suggestion.');
            
            db = saveReview('DS-REV-001', revStruct, testCase.tempDataDir);
            testCase.verifyEqual(char(db.casesTable.reviewStatus(1)), 'ACCEPTED');

            % Check audit log
            auditPath = fullfile(testCase.tempDataDir, 'drishtisetu_audit.log');
            logContent = fileread(auditPath);
            testCase.verifyTrue(contains(logContent, 'REVIEW_SAVED'));
            testCase.verifyTrue(contains(logContent, 'OPHTHAL-07'));
        end
    end
end
