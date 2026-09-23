classdef test_grading < matlab.unittest.TestCase
    % TEST_GRADING Tests calibration, ICDR evidence rules, 3-way triage policy, and DR inference.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testTemperatureScalingCalibration(testCase)
            rawLogits = [4.0, 1.0, 0.5, 0.2, 0.1];
            cal_unscaled = applyCalibration(rawLogits, 1.0);
            
            T = 1.5;
            cal = applyCalibration(rawLogits, T);

            testCase.verifyEqual(numel(cal), 5);
            testCase.verifyEqual(sum(cal), 1.0, 'AbsTol', 1e-6);
            % Higher temperature pulls max probability toward uniform
            testCase.verifyLessThan(cal(1), cal_unscaled(1));

            T_sharp = 0.5;
            cal_sharp = applyCalibration(rawLogits, T_sharp);
            testCase.verifyGreaterThan(cal_sharp(1), cal_unscaled(1));
        end

        function testICDREvidenceRules(testCase)
            % 1. Clean eye -> Level 0
            lesions0 = struct('counts', struct('maCount', 0, 'heCount', 0, 'exCount', 0, 'seCount', 0), ...
                              'quadrants', struct('quadrantsWithHemorrhages', 0, 'maxHemorrhagesInAnyQuadrant', 0));
            anatomy = struct('opticDisc', struct('center', [100, 100]), 'fovea', struct('center', [200, 200]));
            res0 = icdrEvidence(lesions0, anatomy);
            testCase.verifyEqual(res0.suggestedGrade, 0);

            % 2. Microaneurysms only -> Level 1
            lesions1 = struct('counts', struct('maCount', 3, 'heCount', 0, 'exCount', 0, 'seCount', 0), ...
                              'quadrants', struct('quadrantsWithHemorrhages', 1, 'maxHemorrhagesInAnyQuadrant', 0));
            res1 = icdrEvidence(lesions1, anatomy);
            testCase.verifyEqual(res1.suggestedGrade, 1);

            % 3. MAs and HEs present -> Level 2
            lesions2 = struct('counts', struct('maCount', 8, 'heCount', 5, 'exCount', 4, 'seCount', 0), ...
                              'quadrants', struct('quadrantsWithHemorrhages', 2, 'maxHemorrhagesInAnyQuadrant', 3));
            res2 = icdrEvidence(lesions2, anatomy);
            testCase.verifyEqual(res2.suggestedGrade, 2);

            % 4. 4-2-1 rule severe hemorrhages (>=20 in all 4 quadrants) -> Level 3
            lesions3 = struct('counts', struct('maCount', 30, 'heCount', 85, 'exCount', 10, 'seCount', 2), ...
                              'quadrants', struct('quadrantsWithHemorrhages', 4, 'maxHemorrhagesInAnyQuadrant', 25));
            res3 = icdrEvidence(lesions3, anatomy);
            testCase.verifyEqual(res3.suggestedGrade, 3);
        end

        function testThreeWayDecisionPolicy(testCase)
            cfg = projectConfig();

            % Low probability, low uncertainty -> AUTO_CLEAR
            polClear = decisionPolicy(0.15, 0.20, 0, false, cfg);
            testCase.verifyEqual(polClear.decision, 'AUTO_CLEAR');

            % High referable probability -> REFER
            polRefer = decisionPolicy(0.85, 0.30, 2, false, cfg);
            testCase.verifyEqual(polRefer.decision, 'REFER');

            % High uncertainty -> ESCALATE_HUMAN_REVIEW
            polUncertain = decisionPolicy(0.55, 0.85, 1, false, cfg);
            testCase.verifyEqual(polUncertain.decision, 'ESCALATE_HUMAN_REVIEW');

            % Out of distribution -> ESCALATE_HUMAN_REVIEW
            polOOD = decisionPolicy(0.10, 0.10, 0, true, cfg);
            testCase.verifyEqual(polOOD.decision, 'ESCALATE_HUMAN_REVIEW');
        end

        function testInferDRGrade(testCase)
            img = generateSampleFundus('normal', 384);
            mask = fovMask(img);
            cfg = projectConfig();
            anatomy = analyzeAnatomy(img, mask, 'OD', cfg);
            lesions = detectLesions(img, mask, anatomy, cfg);

            dr = inferDRGrade(img, lesions, anatomy, cfg);
            testCase.verifyTrue(isfield(dr, 'predictedGrade'));
            testCase.verifyTrue(isfield(dr, 'classProbabilities'));
            testCase.verifyTrue(isfield(dr, 'calibratedProbabilities'));
            testCase.verifyTrue(isfield(dr, 'referableProbability'));
            testCase.verifyTrue(isfield(dr, 'isReferable'));
            testCase.verifyTrue(isfield(dr, 'decisionPolicy'));
            testCase.verifyEqual(numel(dr.classProbabilities), 5);
        end
    end
end
