classdef test_anatomy < matlab.unittest.TestCase
    % TEST_ANATOMY Tests the DrishtiSetu anatomical landmark and vessel analysis engine.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testOpticDiscLocalization(testCase)
            img = generateSampleFundus('normal', 384);
            mask = fovMask(img);
            cfg = projectConfig();

            od = opticDisc(img, mask, cfg);
            testCase.verifyTrue(isfield(od, 'center'));
            testCase.verifyTrue(isfield(od, 'radius'));
            testCase.verifyTrue(isfield(od, 'mask'));
            testCase.verifyEqual(numel(od.center), 2);
            testCase.verifyGreaterThan(od.radius, 5);
            testCase.verifyEqual(size(od.mask), [384, 384]);
        end

        function testFoveaLocalizationLaterality(testCase)
            img = generateSampleFundus('normal', 384);
            mask = fovMask(img);
            cfg = projectConfig();
            od = opticDisc(img, mask, cfg);

            % OD (Right Eye): Fovea should be to the temporal side (left in standard image)
            foveaOD = fovea(img, mask, od, 'OD', cfg);
            testCase.verifyTrue(isfield(foveaOD, 'center'));
            testCase.verifyTrue(isfield(foveaOD, 'confidence'));
            testCase.verifyEqual(numel(foveaOD.center), 2);

            % OS (Left Eye): Fovea should be temporal to the right in standard image
            foveaOS = fovea(img, mask, od, 'OS', cfg);
            testCase.verifyNotEqual(foveaOD.center(1), foveaOS.center(1));
        end

        function testVesselSegmentationAndFeatures(testCase)
            img = generateSampleFundus('normal', 384);
            mask = fovMask(img);
            cfg = projectConfig();

            vMask = vessels(img, mask, cfg);
            testCase.verifyTrue(islogical(vMask));
            testCase.verifyEqual(size(vMask), [384, 384]);
            testCase.verifyGreaterThan(nnz(vMask), 50);

            od = opticDisc(img, mask, cfg);
            fov = fovea(img, mask, od, 'OD', cfg);
            feats = vesselFeatures(vMask, od, fov, mask);

            testCase.verifyTrue(isfield(feats, 'density'));
            testCase.verifyTrue(isfield(feats, 'branchPoints'));
            testCase.verifyTrue(isfield(feats, 'quadrantDensity'));
            testCase.verifyGreaterThan(feats.density, 0);
        end

        function testFullAnatomyPipeline(testCase)
            img = generateSampleFundus('normal', 384);
            mask = fovMask(img);
            cfg = projectConfig();

            anatomy = analyzeAnatomy(img, mask, 'OD', cfg);
            testCase.verifyTrue(isfield(anatomy, 'opticDisc'));
            testCase.verifyTrue(isfield(anatomy, 'fovea'));
            testCase.verifyTrue(isfield(anatomy, 'vessels'));
            testCase.verifyTrue(isfield(anatomy, 'quadrants'));
        end
    end
end
