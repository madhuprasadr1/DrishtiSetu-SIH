function metrics = evaluateLesions(predictedMask, groundTruthMask, fovMask)
%EVALUATELESIONS Segmentation benchmarks: Dice, IoU, Sensitivity, Specificity, Precision.
%   METRICS = evaluateLesions(PREDICTEDMASK, GROUNDTRUTHMASK, FOVMASK)
%   computes pixel-level overlap inside the retinal field of view.

if nargin < 2 || isempty(predictedMask) || isempty(groundTruthMask)
    metrics = struct('status', 'NOT EVALUATED', ...
        'disclaimer', 'Lesion ground truth masks or predictions not supplied.');
    return;
end

pred = logical(predictedMask);
gt = logical(groundTruthMask);

if nargin >= 3 && ~isempty(fovMask)
    fov = logical(fovMask);
    pred = pred & fov;
    gt = gt & fov;
    totalPixels = max(1, nnz(fov));
else
    totalPixels = numel(gt);
end

TP = nnz(pred & gt);
FP = nnz(pred & ~gt);
FN = nnz(~pred & gt);
TN = totalPixels - (TP + FP + FN);

intersectionArea = TP;
unionArea = TP + FP + FN;

if unionArea > 0
    iou = intersectionArea / unionArea;
    dice = 2 * intersectionArea / (2 * TP + FP + FN);
else
    iou = 1.0;
    dice = 1.0;
end

sens = TP / max(1, TP + FN);
spec = TN / max(1, TN + FP);
prec = TP / max(1, TP + FP);

metrics = struct();
metrics.status = 'EVALUATED';
metrics.dice = dice;
metrics.iou = iou;
metrics.sensitivity = sens;
metrics.specificity = spec;
metrics.precision = prec;
metrics.truePositivePixels = TP;
metrics.falsePositivePixels = FP;
metrics.falseNegativePixels = FN;
end
