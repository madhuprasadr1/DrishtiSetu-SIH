function metrics = evaluateExplainability(gradCAMHeatmap, lesionMask, attentionThreshold)
%EVALUATEEXPLAINABILITY Quantify alignment between Grad-CAM attention and retinal lesions.
%   METRICS = evaluateExplainability(HEATMAP, LESIONMASK, ATTENTIONTHRESHOLD)
%   measures:
%       attentionLesionOverlap - Fraction of high-attention pixels that cover true lesions
%       lesionCoverageByAttention - Fraction of lesion pixels covered by top attention
%       pointingGameAccuracy - True if peak attention coordinate falls on a lesion

if nargin < 2 || isempty(gradCAMHeatmap) || isempty(lesionMask)
    metrics = struct('status', 'NOT EVALUATED', ...
        'disclaimer', 'Grad-CAM or lesion annotations not supplied.');
    return;
end
if nargin < 3 || isempty(attentionThreshold)
    attentionThreshold = 0.35;
end

cam = single(gradCAMHeatmap);
mask = logical(lesionMask);

if ~isequal(size(cam), size(mask))
    cam = imresize(cam, size(mask), 'bicubic');
end

% Peak attention point
[~, maxIdx] = max(cam(:));
[peakY, peakX] = ind2sub(size(cam), maxIdx);
pointingHit = mask(peakY, peakX);

% Binarized top attention mask
highAttention = cam >= attentionThreshold;

totalAttentionPixels = max(1, nnz(highAttention));
totalLesionPixels = max(1, nnz(mask));

overlapPixels = nnz(highAttention & mask);

precisionOverlap = overlapPixels / totalAttentionPixels;
recallCoverage = overlapPixels / totalLesionPixels;

metrics = struct();
metrics.status = 'EVALUATED';
metrics.attentionThreshold = attentionThreshold;
metrics.pointingGameHit = pointingHit;
metrics.attentionLesionPrecision = precisionOverlap;
metrics.lesionAttentionRecall = recallCoverage;
metrics.overlapPixelCount = overlapPixels;
end
