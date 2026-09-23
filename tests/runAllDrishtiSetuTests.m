function testResults = runAllDrishtiSetuTests()
% RUNALLDRISHTISETUTESTS Executes the complete automated test suite for DrishtiSetu.
%
% Usage:
%   results = runAllDrishtiSetuTests();

fprintf('\n================================================================================\n');
fprintf('  DRISHTISETU MVP: AUTOMATED VERIFICATION SUITE\n');
fprintf('  MATLAB Unit Test Runner\n');
fprintf('================================================================================\n\n');

testDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(testDir);
addpath(genpath(rootDir));

testFiles = { ...
    'test_smoke_e2e', ...
    'test_quality', ...
    'test_anatomy', ...
    'test_lesions', ...
    'test_measurements', ...
    'test_grading', ...
    'test_safety', ...
    'test_advanced3D', ...
    'test_reporting', ...
    'test_database', ...
    'test_simulation' ...
};

suite = [];
for k = 1:numel(testFiles)
    filePath = fullfile(testDir, [testFiles{k}, '.m']);
    try
        s = matlab.unittest.TestSuite.fromFile(filePath);
        suite = [suite, s]; %#ok<AGROW>
    catch err
        warning('Could not load test suite from %s: %s', filePath, err.message);
    end
end

runner = matlab.unittest.TestRunner.withTextOutput;
testResults = runner.run(suite);

fprintf('\n================================================================================\n');
fprintf('  TEST SUITE EXECUTION SUMMARY\n');
fprintf('================================================================================\n');
numPassed = nnz([testResults.Passed]);
numFailed = nnz([testResults.Failed]);
numIncomplete = nnz([testResults.Incomplete]);
total = numel(testResults);

fprintf('Total Tests:      %d\n', total);
fprintf('Passed:           %d\n', numPassed);
fprintf('Failed:           %d\n', numFailed);
fprintf('Incomplete:       %d\n', numIncomplete);
totalDuration = sum([testResults.Duration]);
fprintf('Total Duration:   %.2f seconds\n', totalDuration);

if numFailed == 0
    fprintf('\n>>> ALL DRISHTISETU VERIFICATION TESTS PASSED SUCCESSFULLY! <<<\n\n');
else
    fprintf('\n>>> ATTENTION: %d TEST(S) FAILED. INVESTIGATE LOGS ABOVE. <<<\n\n', numFailed);
end

end
