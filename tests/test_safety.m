classdef test_safety < matlab.unittest.TestCase
    % TEST_SAFETY Tests confidence, uncertainty estimation, OOD anomaly detection, and safety gating.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testConfidenceAndMargin(testCase)
            pClear = [0.90, 0.05, 0.03, 0.01, 0.01];
            conf = estimateConfidence(pClear);
            testCase.verifyEqual(conf.top1Probability, 0.90, 'AbsTol', 1e-4);
            testCase.verifyEqual(conf.margin, 0.85, 'AbsTol', 1e-4);
        end

        function testUncertaintyEntropy(testCase)
            pCertain = [1.0, 0.0, 0.0, 0.0, 0.0];
            uncMin = estimateUncertainty(pCertain);
            testCase.verifyEqual(uncMin.entropy, 0.0, 'AbsTol', 1e-4);
            testCase.verifyEqual(uncMin.normalizedEntropy, 0.0, 'AbsTol', 1e-4);

            pUniform = [0.2, 0.2, 0.2, 0.2, 0.2];
            uncMax = estimateUncertainty(pUniform);
            testCase.verifyEqual(uncMax.normalizedEntropy, 1.0, 'AbsTol', 1e-4);
        end

        function testOODDetection(testCase)
            img = generateSampleFundus('normal', 256);
            mask = fovMask(img);
            cfg = projectConfig();

            oodNormal = detectOOD(img, mask, cfg);
            testCase.verifyFalse(oodNormal.isOOD);

            % Noise image with abnormal color distribution (pure cyan / random)
            noiseImg = uint8(randi([0, 255], [256, 256, 3]));
            noiseImg(:, :, 1) = 0; % No red channel in a fundus image is completely abnormal
            noiseMask = true(256, 256);
            oodNoise = detectOOD(noiseImg, noiseMask, cfg);
            testCase.verifyTrue(oodNoise.isOOD);
        end

        function testSafetyGatingLogic(testCase)
            cfg = projectConfig();

            % 1. Ungradable -> RECAPTURE_REQUIRED
            qBad = struct('isGradable', false, 'overallStatus', 'BAD', 'reasons', {{'Severely underexposed'}});
            dr = struct('drGrade', 0, 'calibratedProbabilities', [0.90, 0.05, 0.03, 0.01, 0.01]);
            ood = struct('isOOD', false, 'oodFlag', false);
            gate1 = safetyGate(qBad, dr, [], ood, cfg);
            testCase.verifyEqual(gate1.gateStatus, 'RECAPTURE_REQUIRED');

            % 2. OOD -> HUMAN_REVIEW_REQUIRED
            qGood = struct('isGradable', true, 'overallStatus', 'GOOD', 'reasons', {{}});
            oodBad = struct('isOOD', true, 'oodFlag', true, 'reasons', {{'Non-retinal chromaticity spectrum'}});
            gate2 = safetyGate(qGood, dr, [], oodBad, cfg);
            testCase.verifyEqual(gate2.gateStatus, 'HUMAN_REVIEW_REQUIRED');

            % 3. High Uncertainty -> HUMAN_REVIEW_REQUIRED
            drUncertain = struct('drGrade', 1, 'calibratedProbabilities', [0.22, 0.21, 0.20, 0.19, 0.18]);
            gate3 = safetyGate(qGood, drUncertain, [], ood, cfg);
            testCase.verifyEqual(gate3.gateStatus, 'HUMAN_REVIEW_REQUIRED');
        end
    end
end
