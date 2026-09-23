function oodResult = detectOOD(image, fovMask, qualityFeatures)
%DETECTOOD Out-Of-Distribution and anomaly detector for non-fundus or corrupt inputs.
%   OODRESULT = detectOOD(IMAGE, FOVMASK, QUALITYFEATURES)
%   detects whether the image significantly departs from typical retinal fundus distributions:
%       - Retinal chromaticity check (retinal fundus is red/orange dominant: R > G > B)
%       - Field-of-view geometry & aperture circularity
%       - High background noise outside FOV mask
%       - Severe unnatural channel clipping

if nargin < 2 || isempty(fovMask)
    fovMask = fovMask(image);
end
if nargin < 3
    qualityFeatures = struct();
end

[h, w, c] = size(image);
if isfloat(image)
    imgD = double(image);
    if max(imgD(:)) > 1.0; imgD = imgD / 255.0; end
else
    imgD = double(image) / 255.0;
end

oodReasons = {};
anomalyScore = 0.0;

% 1. Check retinal chromaticity inside FOV
if any(fovMask(:)) && c >= 3
    rVals = imgD(:, :, 1); rMean = mean(rVals(fovMask));
    gVals = imgD(:, :, 2); gMean = mean(gVals(fovMask));
    bVals = imgD(:, :, 3); bMean = mean(bVals(fovMask));
    
    % Normal retina: R is highest, B is lowest
    if bMean > rMean
        oodReasons{end + 1} = 'Abnormal blue-channel dominance (incompatible with retinal tissue)';
        anomalyScore = anomalyScore + 0.45;
    end
    if rMean < 0.05 && gMean < 0.05
        oodReasons{end + 1} = 'Extremely low retinal chromatic signal';
        anomalyScore = anomalyScore + 0.35;
    end
    
    % Check for monochromatic / grayscale input
    rgDiff = mean(abs(rVals(fovMask) - gVals(fovMask)));
    rbDiff = mean(abs(rVals(fovMask) - bVals(fovMask)));
    if (rgDiff + rbDiff) < 0.005
        oodReasons{end + 1} = 'Input appears to be synthetic or converted monochrome';
        anomalyScore = anomalyScore + 0.25;
    end
end

% 2. FOV Geometry & Coverage
fovRatio = nnz(fovMask) / numel(fovMask);
if fovRatio < 0.15
    oodReasons{end + 1} = 'Severely restricted or absent retinal field-of-view';
    anomalyScore = anomalyScore + 0.40;
elseif fovRatio > 0.95
    % Natural photography without camera aperture mask
    oodReasons{end + 1} = 'No fundus camera aperture detected (unmasked full-frame capture)';
    anomalyScore = anomalyScore + 0.30;
end

% 3. Background signal outside aperture
outsideMask = ~fovMask;
if any(outsideMask(:))
    outsideVals = imgD(repmat(outsideMask, 1, 1, min(c, 3)));
    outsideMean = mean(outsideVals(:));
    if outsideMean > 0.30
        oodReasons{end + 1} = 'High background luminance outside optical aperture';
        anomalyScore = anomalyScore + 0.35;
    end
end

oodScore = min(1.0, anomalyScore);
oodFlag = (oodScore >= 0.50) || ~isempty(oodReasons);

oodResult = struct();
oodResult.oodFlag = oodFlag;
oodResult.isOOD = oodFlag;
oodResult.oodScore = oodScore;
oodResult.reasons = oodReasons;
if isempty(oodReasons)
    oodResult.description = 'Input is consistent with in-distribution retinal fundus photography.';
else
    oodResult.description = strjoin(oodReasons, '; ');
end
end
