classdef test_measurements < matlab.unittest.TestCase
    % TEST_MEASUREMENTS Unit tests for Module M06 (Quantitative Measurement Engine).

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testCalculateAreaAndDiameter(testCase)
            % Circular mask of radius 10 -> Area approx pi * 100 ~ 314
            [X, Y] = meshgrid(1:50, 1:50);
            circleMask = (X - 25).^2 + (Y - 25).^2 <= 100;
            
            [pArea, cArea, unitA] = calculateArea(circleMask);
            testCase.verifyTrue(pArea > 300 && pArea < 330);
            testCase.verifyEqual(unitA, 'pixels');

            [eqDiam, unitD] = calculateDiameter(pArea, unitA);
            % Diam should be ~ 20 pixels
            testCase.verifyTrue(abs(eqDiam - 20) < 1.0);
            testCase.verifyEqual(unitD, 'pixels');
        end

        function testShapeMetrics(testCase)
            % Perfect circle
            [X, Y] = meshgrid(1:50, 1:50);
            circleMask = (X - 25).^2 + (Y - 25).^2 <= 100;
            props = regionprops(circleMask, 'Area', 'Perimeter', 'Eccentricity', 'MajorAxisLength', 'MinorAxisLength');
            
            sMetrics = calculateShape(props(1));
            testCase.verifyTrue(sMetrics.circularity > 0.85); % Circularity near 1.0
            testCase.verifyTrue(sMetrics.eccentricity < 0.3); % Eccentricity near 0.0
        end

        function testAnatomicalDistances(testCase)
            centroid = [100, 100];
            foveaLoc = [160, 100]; % 60 px away
            odCenter = [40, 100];  % 60 px away
            discDiam = 60;
            
            loc = calculateAnatomicalDistance(centroid, foveaLoc, odCenter, discDiam, 'OD');
            testCase.verifyEqual(loc.distToFoveaPixels, 60);
            testCase.verifyEqual(loc.distToFoveaDD, 1.0);
            testCase.verifyEqual(loc.distToDiscPixels, 60);
            testCase.verifyEqual(loc.distToDiscDD, 1.0);
        end

        function testMeasureLesionsPipeline(testCase)
            img = uint8(128 * ones(256, 256, 3));
            anatomy = struct('foveaLocation', [128, 128], 'opticDiscCenter', [60, 128], ...
                'opticDiscMask', false(256, 256));
            anatomy.opticDiscMask(118:138, 50:70) = true;

            lesions = struct();
            lesions.microaneurysms = struct('mask', false(256, 256));
            lesions.microaneurysms.mask(128, 132) = true; % 4px from fovea -> macular threat!
            lesions.hardExudates = struct('mask', false(256, 256));
            lesions.hardExudates.mask(100:104, 100:104) = true;

            meas = measureLesions(img, lesions, anatomy);

            testCase.verifyEqual(meas.totalLesionCount, 2);
            testCase.verifyTrue(meas.macularThreatCount >= 1);
            testCase.verifyTrue(meas.totalLesionArea > 0);
        end
    end
end
