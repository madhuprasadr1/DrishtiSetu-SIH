classdef test_simulation < matlab.unittest.TestCase
    % TEST_SIMULATION Tests the PHC clinical workflow simulation and operational queue KPIs.

    methods (TestClassSetup)
        function addProjectPaths(~)
            testDir = fileparts(mfilename('fullpath'));
            rootDir = fileparts(testDir);
            addpath(genpath(rootDir));
        end
    end

    methods (Test)
        function testPHCDiscreteEventSimulation(testCase)
            cfg = simulationConfig();
            cfg.simDurationHours = 4; % 4-hour clinic shift
            cfg.arrivalRatePerHour = 10; % 10 patients/hr

            results = runPHCSimulation(cfg);

            testCase.verifyTrue(isfield(results, 'patientsArrived'));
            testCase.verifyTrue(isfield(results, 'patientsCompleted'));
            testCase.verifyTrue(isfield(results, 'throughputPerHour'));
            testCase.verifyTrue(isfield(results, 'avgWaitMinutes'));
            testCase.verifyTrue(isfield(results, 'operatorUtilization'));

            testCase.verifyGreaterThan(results.patientsArrived, 0);
            testCase.verifyGreaterThan(results.patientsCompleted, 0);
            testCase.verifyGreaterThanOrEqual(results.avgWaitMinutes, 0);
            testCase.verifyGreaterThanOrEqual(results.operatorUtilization, 0.0);
            testCase.verifyLessThanOrEqual(results.operatorUtilization, 1.0);
        end
    end
end
