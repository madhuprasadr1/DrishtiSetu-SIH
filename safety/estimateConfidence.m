function conf = estimateConfidence(calibratedProbabilities)
%ESTIMATECONFIDENCE Calculate calibrated prediction confidence and margin.
%   CONF = estimateConfidence(PROBABILITIES) computes:
%       top1Confidence - Maximum calibrated class probability
%       top2Confidence - Second highest probability
%       margin         - Difference between top-1 and top-2
%       confidenceScore- Overall confidence metric in [0, 1]

if nargin < 1 || isempty(calibratedProbabilities)
    error('safety:MissingInput', 'Probabilities vector is required.');
end

p = double(calibratedProbabilities(:));
p = p / max(eps, sum(p)); % Ensure normalization

sortedP = sort(p, 'descend');
top1 = sortedP(1);
top2 = 0;
if numel(sortedP) >= 2
    top2 = sortedP(2);
end

margin = top1 - top2;

% Combined confidence score balancing peak probability and margin
confidenceScore = min(1.0, max(0.0, 0.6 * top1 + 0.4 * margin));

conf = struct();
conf.top1Confidence = top1;
conf.top1Probability = top1;
conf.top2Confidence = top2;
conf.margin = margin;
conf.confidenceScore = confidenceScore;
end
