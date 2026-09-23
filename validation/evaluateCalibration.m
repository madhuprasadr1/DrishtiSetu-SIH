function calMetrics = evaluateCalibration(probabilities, trueLabels, numBins)
%EVALUATECALIBRATION Assess confidence calibration (Brier score, ECE, reliability diagram).
%   CALMETRICS = evaluateCalibration(PROBABILITIES, TRUELABELS, NUMBINS)

if nargin < 2 || isempty(probabilities) || isempty(trueLabels)
    calMetrics = struct('status', 'NOT EVALUATED', ...
        'disclaimer', 'Calibration data not supplied.');
    return;
end
if nargin < 3 || isempty(numBins)
    numBins = 10;
end

probs = double(probabilities);
yTrue = double(trueLabels(:));
N = numel(yTrue);

% If multi-class matrix, evaluate top-1 predicted class
if size(probs, 1) == N && size(probs, 2) > 1
    [confidences, preds] = max(probs, [], 2);
    preds = preds - 1; % Convert 1..5 to 0..4
    correct = (preds == yTrue);
else
    confidences = probs(:);
    correct = logical(yTrue >= 1); % Binary
end

% 1. Brier Score
brierScore = mean((confidences - double(correct)).^2);

% 2. Expected Calibration Error (ECE)
binEdges = linspace(0, 1, numBins + 1);
ece = 0.0;
binAcc = zeros(numBins, 1);
binConf = zeros(numBins, 1);
binCounts = zeros(numBins, 1);

for b = 1:numBins
    inBin = (confidences > binEdges(b)) & (confidences <= binEdges(b + 1));
    count = nnz(inBin);
    binCounts(b) = count;
    if count > 0
        acc = mean(correct(inBin));
        conf = mean(confidences(inBin));
        binAcc(b) = acc;
        binConf(b) = conf;
        ece = ece + (count / N) * abs(acc - conf);
    end
end

calMetrics = struct();
calMetrics.status = 'EVALUATED';
calMetrics.sampleSize = N;
calMetrics.brierScore = brierScore;
calMetrics.expectedCalibrationError = ece;
calMetrics.numBins = numBins;
calMetrics.binAccuracies = binAcc;
calMetrics.binConfidences = binConf;
calMetrics.binCounts = binCounts;
end
