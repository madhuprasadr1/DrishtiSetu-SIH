classdef test_reporting < matlab.unittest.TestCase
    % TEST_REPORTING Tests the clinical PDF, PNG, and TXT report generation engine.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testReportGeneration(testCase)
            % Run a lightweight screening case
            cfg = projectConfig();
            img = generateSampleFundus('normal', 256);
            meta = struct('patientID', 'REP-TEST-001', 'eye', 'OD', 'age', 48, 'gender', 'F');
            result = runScreeningCase(img, meta, cfg);

            tempOutDir = fullfile(tempdir, ['ds_rep_' num2str(randi(100000))]);
            mkdir(tempOutDir);
            cleaner = onCleanup(@() rmdir(tempOutDir, 's'));

            [pdfPath, pngPath, txtPath] = generateReport(result, tempOutDir);

            % Verify text report
            testCase.verifyTrue(isfile(txtPath));
            txtContent = fileread(txtPath);
            testCase.verifyTrue(contains(txtContent, 'DRISHTISETU CLINICAL RETINAL SCREENING REPORT'));
            testCase.verifyTrue(contains(txtContent, 'REP-TEST-001'));
            testCase.verifyTrue(contains(txtContent, 'DISCLAIMER'));

            % Verify image/pdf report
            testCase.verifyTrue(isfile(pngPath) || isfile(pdfPath));
        end
    end
end
