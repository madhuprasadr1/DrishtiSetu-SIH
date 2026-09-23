classdef test_smoke_e2e < matlab.unittest.TestCase
    % TEST_SMOKE_E2E End-to-end smoke test for DrishtiSetu screening pipeline.
    % Validates complete pipeline execution and 14-field canonical schema.

    properties (TestParameter)
        caseType = {'normal', 'borderline', 'ungradable'};
    end

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testCanonical14FieldSchema(testCase)
            % Test default factory schema initialization
            res = createScreeningResult();
            requiredFields = {'caseID', 'patient', 'eye', 'acquisition', ...
                'quality', 'preprocessing', 'anatomy', 'lesions', 'dr', ...
                'safety', 'explainability', 'review', 'report', 'audit'};
            
            for k = 1:numel(requiredFields)
                testCase.verifyTrue(isfield(res, requiredFields{k}), ...
                    sprintf('Missing canonical field: %s', requiredFields{k}));
            end
            testCase.verifyEqual(res.status, 'INITIALIZED');
        end

        function testEndToEndPipelineNormal(testCase)
            % Generate synthetic normal fundus
            cfg = projectConfig();
            img = generateSampleFundus('normal', 512);
            meta = struct('patientID', 'TEST-001', 'eye', 'OD', 'age', 55, 'gender', 'M');

            result = runScreeningCase(img, meta, cfg);

            % Verify status
            testCase.verifyEqual(result.status, 'COMPLETED');
            testCase.verifyTrue(result.quality.isGradable);
            testCase.verifyEqual(result.dr.predictedGrade, 0);
            testCase.verifyFalse(result.dr.isReferable);
            testCase.verifyNotEmpty(result.explainability.narrative);
            testCase.verifyTrue(isfile(result.report.reportPdfPath) || ...
                                isfile(result.report.reportPngPath) || ...
                                isfile(result.report.reportTxtPath));
        end

        function testEndToEndPipelineUngradableGating(testCase)
            % Pitch black ungradable image
            cfg = projectConfig();
            img = zeros(256, 256, 3, 'uint8');
            meta = struct('patientID', 'TEST-UNG', 'eye', 'OS');

            result = runScreeningCase(img, meta, cfg);

            testCase.verifyEqual(result.status, 'GATED_RECAPTURE');
            testCase.verifyFalse(result.quality.isGradable);
            testCase.verifyEqual(result.safety.gateStatus, 'RECAPTURE_REQUIRED');
            testCase.verifyNotEmpty(result.quality.operatorAdvice);
        end
    end
end
