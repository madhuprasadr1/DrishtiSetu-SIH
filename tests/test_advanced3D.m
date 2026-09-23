classdef test_advanced3D < matlab.unittest.TestCase
    % TEST_ADVANCED3D Unit tests for Module M13 (Estimated 3D Retinal Visualization).

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testDepthEstimation(testCase)
            % Test synthetic image and anatomy
            img = uint8(128 * ones(256, 256, 3));
            retinalMask = true(256, 256);
            
            anatomy = struct( ...
                'retinalMask', retinalMask, ...
                'opticDiscCenter', [80, 128], ...
                'opticDiscMask', false(256, 256), ...
                'foveaLocation', [170, 128], ...
                'vesselMask', false(256, 256));
            anatomy.opticDiscMask(118:138, 70:90) = true;
            anatomy.vesselMask(128, :) = true; % Horizontal vessel line
            
            lesions = struct( ...
                'hardExudates', struct('mask', false(256, 256)), ...
                'haemorrhages', struct('mask', false(256, 256)));
            lesions.hardExudates.mask(120:125, 160:165) = true;

            depthInfo = estimateDepth(img, anatomy, lesions);

            testCase.verifyNotEmpty(depthInfo.zSurface);
            testCase.verifyEqual(size(depthInfo.zSurface), [256, 256]);
            testCase.verifyTrue(depthInfo.elevationSpan > 0);
            testCase.verifyTrue(isfield(depthInfo, 'bScanProfile'));
            testCase.verifyNotEmpty(depthInfo.bScanProfile.depthCurve);
        end

        function testConstructPseudo3D(testCase)
            img = uint8(100 * rand(256, 256, 3));
            anatomy = struct('retinalMask', true(256, 256), 'opticDiscCenter', [64, 128], ...
                'opticDiscMask', false(256, 256), 'foveaLocation', [180, 128], 'vesselMask', false(256, 256));
            lesions = struct();
            cfg = projectConfig();

            out3D = constructPseudo3D(img, anatomy, lesions, cfg);

            testCase.verifyEqual(out3D.status, 'COMPLETED');
            testCase.verifyNotEmpty(out3D.rendered3DImage);
            testCase.verifyTrue(out3D.elevationSpan > 0);
        end

        function testDecoupledSafetyGuarantee(testCase)
            % Ensure that if 3D inputs are corrupted, constructPseudo3D fails gracefully
            % without throwing an uncaught exception
            corruptedImg = [];
            corruptedAnatomy = [];
            
            out3D = constructPseudo3D(corruptedImg, corruptedAnatomy, [], []);
            
            testCase.verifyTrue(isstruct(out3D));
            testCase.verifyTrue(isfield(out3D, 'status'));
            % Core screening is never blocked
        end
    end
end
