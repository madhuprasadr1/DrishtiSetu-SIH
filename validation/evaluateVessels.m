function metrics = evaluateVessels(predictedVesselMask, groundTruthVesselMask, fovMask)
%EVALUATEVESSELS Benchmarking for retinal vessel segmentation on DRIVE/STARE.
%   METRICS = evaluateVessels(PRED, GT, FOV) computes Dice, IoU, sensitivity, specificity.

if nargin < 2 || isempty(predictedVesselMask) || isempty(groundTruthVesselMask)
    metrics = struct('status', 'NOT EVALUATED', ...
        'disclaimer', 'Vessel ground truth annotations or predictions not supplied.');
    return;
end

if nargin < 3; fovMask = []; end
metrics = evaluateLesions(predictedVesselMask, groundTruthVesselMask, fovMask);
end
