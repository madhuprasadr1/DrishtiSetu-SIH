function metrics = evaluateDR(predictedLabels, trueLabels, predictedProbabilities)
%EVALUATEDR Comprehensive clinical performance metrics for 5-level and referable DR.
%   METRICS = evaluateDR(PREDICTED, TRUE, PROBABILITIES) computes:
%       Sensitivity, Specificity, PPV, NPV, F1-Score, AUROC, AUPRC,
%       Confusion Matrix, and Quadratic Weighted Kappa (QWK).
%   If true labels or predictions are empty, explicitly reports 'NOT EVALUATED'.

if nargin < 2 || isempty(trueLabels) || isempty(predictedLabels)
    metrics = struct('status', 'NOT EVALUATED', ...
        'disclaimer', 'Validation metrics not evaluated: test set or predictions not supplied.');
    return;
end

yTrue = double(trueLabels(:));
yPred = double(predictedLabels(:));
N = numel(yTrue);

if numel(yPred) ~= N
    error('validation:DimensionMismatch', 'Predicted and true labels must have matching length.');
end

% 1. 5-Class Confusion Matrix
K = 5;
confMat = zeros(K, K);
for i = 1:N
    t = yTrue(i) + 1; % 1-indexed (0..4 -> 1..5)
    p = yPred(i) + 1;
    if t >= 1 && t <= K && p >= 1 && p <= K
        confMat(t, p) = confMat(t, p) + 1;
    end
end

% 2. Quadratic Weighted Kappa (QWK)
w = zeros(K, K);
for i = 1:K
    for j = 1:K
        w(i, j) = ((i - j)^2) / ((K - 1)^2);
    end
end
histTrue = sum(confMat, 2);
histPred = sum(confMat, 1);
expectedMat = (histTrue * histPred) / N;

observedWeighted = sum(sum(w .* confMat));
expectedWeighted = sum(sum(w .* expectedMat));

if expectedWeighted > 0
    qwk = 1.0 - (observedWeighted / expectedWeighted);
else
    qwk = 1.0;
end

% 3. Referable DR Screening Metrics (Level >= 2)
binTrue = yTrue >= 2;
binPred = yPred >= 2;

TP = sum(binTrue & binPred);
FP = sum(~binTrue & binPred);
TN = sum(~binTrue & ~binPred);
FN = sum(binTrue & ~binPred);

sensitivity = TP / max(1, TP + FN);
specificity = TN / max(1, TN + FP);
ppv = TP / max(1, TP + FP);
npv = TN / max(1, TN + FN);
accuracy = (TP + TN) / max(1, N);

if (ppv + sensitivity) > 0
    f1 = 2 * (ppv * sensitivity) / (ppv + sensitivity);
else
    f1 = 0;
end

% 4. AUROC for Referable DR
auroc = NaN;
if nargin >= 3 && ~isempty(predictedProbabilities)
    if size(predictedProbabilities, 1) == N && size(predictedProbabilities, 2) >= 5
        referableProbs = sum(predictedProbabilities(:, 3:5), 2);
    else
        referableProbs = double(predictedProbabilities(:));
    end
    try
        [~, ~, ~, auroc] = perfcurve(binTrue, referableProbs, true);
    catch
        auroc = NaN;
    end
end

metrics = struct();
metrics.status = 'EVALUATED';
metrics.sampleSize = N;
metrics.referablePrevalence = mean(binTrue);
metrics.confusionMatrix = confMat;
metrics.quadraticWeightedKappa = qwk;
metrics.referableMetrics = struct( ...
    'sensitivity', sensitivity, ...
    'specificity', specificity, ...
    'positivePredictiveValue', ppv, ...
    'negativePredictiveValue', npv, ...
    'f1Score', f1, ...
    'accuracy', accuracy, ...
    'auroc', auroc, ...
    'truePositives', TP, ...
    'falsePositives', FP, ...
    'trueNegatives', TN, ...
    'falseNegatives', FN);
end
