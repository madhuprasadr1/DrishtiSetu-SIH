function uncert = estimateUncertainty(calibratedProbabilities)
%ESTIMATEUNCERTAINTY Shannon entropy-based uncertainty quantification.
%   UNCERT = estimateUncertainty(PROBABILITIES) computes:
%       entropy           - Raw Shannon entropy H = -sum(p * log2(p))
%       normalizedEntropy - Normalized to [0, 1] by dividing by log2(K)
%       uncertaintyScore  - Scalar in [0, 1], where 0 is certain and 1 is maximal uncertainty
%       binaryMarginUncertainty - Uncertainty across the referable decision boundary (Level >= 2)

if nargin < 1 || isempty(calibratedProbabilities)
    error('safety:MissingInput', 'Probabilities vector is required.');
end

p = double(calibratedProbabilities(:));
p = p / max(eps, sum(p));

K = numel(p);
maxEntropy = log2(max(2, K));

% Shannon entropy
posP = p(p > 0);
entropyVal = -sum(posP .* log2(posP));
normalizedEntropy = min(1.0, max(0.0, entropyVal / maxEntropy));

% Referable boundary uncertainty (distance of P(referable) from decision threshold 0.5)
if K >= 5
    pReferable = sum(p(3:5));
else
    pReferable = sum(p(min(2, K):end));
end
boundaryDist = abs(pReferable - 0.5);
boundaryUncertainty = 1.0 - 2.0 * boundaryDist; % 1 at 0.5, 0 at 0 or 1

% Overall uncertainty metric
uncertaintyScore = min(1.0, max(0.0, 0.7 * normalizedEntropy + 0.3 * boundaryUncertainty));

uncert = struct();
uncert.entropy = entropyVal;
uncert.normalizedEntropy = normalizedEntropy;
uncert.boundaryUncertainty = boundaryUncertainty;
uncert.uncertaintyScore = uncertaintyScore;
end
