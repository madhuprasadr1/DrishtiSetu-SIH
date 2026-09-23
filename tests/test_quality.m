classdef test_quality < matlab.unittest.TestCase
    % TEST_QUALITY Tests the DrishtiSetu deterministic image quality engine.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testFovMaskGeneration(testCase)
            % Synthetic circle fundus
            img = generateSampleFundus('normal', 256);
            mask = fovMask(img);

            testCase.verifyEqual(size(mask), [256, 256]);
            testCase.verifyTrue(islogical(mask));
            ratio = nnz(mask) / numel(mask);
            testCase.verifyGreaterThan(ratio, 0.40);
            testCase.verifyLessThan(ratio, 0.90);
        end

        function testGradableImageQuality(testCase)
            img = generateSampleFundus('normal', 256);
            cfg = projectConfig();
            [res, ~] = assessQuality(img, cfg);

            testCase.verifyTrue(res.isGradable);
            testCase.verifyEqual(res.overallStatus, 'GOOD');
            testCase.verifyGreaterThan(res.overallScore, 0.60);
        end

        function testBlurredImageRecaptureAdvice(testCase)
            img = generateSampleFundus('normal', 256);
            blurred = imgaussfilt(img, 6);
            cfg = projectConfig();
            [res, ~] = assessQuality(blurred, cfg);

            testCase.verifyTrue(ismember(res.overallStatus, {'BORDERLINE', 'BAD'}));
            testCase.verifyNotEmpty(res.operatorAdvice);
            foundFocusAdvice = any(contains(res.operatorAdvice, 'focus', 'IgnoreCase', true));
            testCase.verifyTrue(foundFocusAdvice);
        end

        function testUnderIlluminatedImage(testCase)
            img = generateSampleFundus('normal', 256);
            dark = img * 0.15;
            cfg = projectConfig();
            [res, ~] = assessQuality(dark, cfg);

            testCase.verifyTrue(ismember(res.overallStatus, {'BORDERLINE', 'BAD'}));
            foundDarkAdvice = any(contains(res.operatorAdvice, {'dark', 'illumination', 'light'}, 'IgnoreCase', true));
            testCase.verifyTrue(foundDarkAdvice);
        end

        function testOverExposedImage(testCase)
            img = generateSampleFundus('normal', 256);
            bright = min(1.0, double(img)/255.0 * 2.5);
            cfg = projectConfig();
            [res, ~] = assessQuality(bright, cfg);

            testCase.verifyTrue(ismember(res.overallStatus, {'BORDERLINE', 'BAD'}));
            foundBrightAdvice = any(contains(res.operatorAdvice, {'bright', 'exposure', 'flash'}, 'IgnoreCase', true));
            testCase.verifyTrue(foundBrightAdvice);
        end

        function testBorderlineEnhancement(testCase)
            img = generateSampleFundus('borderline', 256);
            cfg = projectConfig();
            [res, enhanced] = assessQuality(img, cfg);

            testCase.verifyTrue(res.wasEnhanced);
            testCase.verifyEqual(size(enhanced), size(img));
        end
    end
end
