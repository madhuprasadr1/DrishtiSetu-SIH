classdef test_lesions < matlab.unittest.TestCase
    % TEST_LESIONS Tests the DrishtiSetu multi-pathology lesion detection engine.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testMicroaneurysmCandidates(testCase)
            img = generateSampleFundus('mild', 384);
            mask = fovMask(img);
            cfg = projectConfig();
            anatomy = analyzeAnatomy(img, mask, 'OD', cfg);

            green = im2double(img(:, :, 2));
            maMask = detectMicroaneurysmCandidates(green, anatomy.vessels.mask, anatomy.opticDisc.mask, cfg);

            testCase.verifyTrue(islogical(maMask));
            testCase.verifyEqual(size(maMask), [384, 384]);
            % Ensure no MAs detected directly inside the optic disc mask
            overlap = maMask & anatomy.opticDisc.mask;
            testCase.verifyEqual(nnz(overlap), 0);
        end

        function testLesionSegmentationAndCounting(testCase)
            img = generateSampleFundus('moderate', 384);
            mask = fovMask(img);
            cfg = projectConfig();
            anatomy = analyzeAnatomy(img, mask, 'OD', cfg);

            masks = segmentLesions(img, mask, anatomy, cfg);
            testCase.verifyTrue(isfield(masks, 'ma'));
            testCase.verifyTrue(isfield(masks, 'he'));
            testCase.verifyTrue(isfield(masks, 'ex'));
            testCase.verifyTrue(isfield(masks, 'se'));

            counts = countLesions(masks);
            testCase.verifyTrue(isfield(counts, 'maCount'));
            testCase.verifyTrue(isfield(counts, 'heCount'));
            testCase.verifyTrue(isfield(counts, 'exCount'));
            testCase.verifyTrue(isfield(counts, 'seCount'));
            testCase.verifyGreaterThanOrEqual(counts.totalCount, 0);
        end

        function testQuadrantAssignment(testCase)
            img = generateSampleFundus('severe', 384);
            mask = fovMask(img);
            cfg = projectConfig();
            anatomy = analyzeAnatomy(img, mask, 'OD', cfg);
            masks = segmentLesions(img, mask, anatomy, cfg);

            quadCounts = assignLesionQuadrants(masks, anatomy);
            testCase.verifyTrue(isfield(quadCounts, 'ST'));
            testCase.verifyTrue(isfield(quadCounts, 'IT'));
            testCase.verifyTrue(isfield(quadCounts, 'SN'));
            testCase.verifyTrue(isfield(quadCounts, 'IN'));
            testCase.verifyTrue(isfield(quadCounts, 'quadrantsWithHemorrhages'));
        end

        function testCompleteLesionEngine(testCase)
            img = generateSampleFundus('moderate', 384);
            mask = fovMask(img);
            cfg = projectConfig();
            anatomy = analyzeAnatomy(img, mask, 'OD', cfg);

            lesions = detectLesions(img, mask, anatomy, cfg);
            testCase.verifyTrue(isfield(lesions, 'masks'));
            testCase.verifyTrue(isfield(lesions, 'counts'));
            testCase.verifyTrue(isfield(lesions, 'quadrants'));
            testCase.verifyTrue(isfield(lesions, 'threatToFovea'));
        end
    end
end
