function [opticDiscMask, center, radius, confidence] = opticDisc(image, retinalFovMask, varargin)
%OPTICDISC Detect optic disc mask, center coordinates, and confidence.
%   [MASK, CENTER, RADIUS, CONFIDENCE] = opticDisc(IMAGE, RETINALFOVMASK)
%   OD = opticDisc(IMAGE, RETINALFOVMASK, CONFIG)
%   detects the optic nerve head (optic disc) using intensity clustering,
%   morphological candidate filtering, and circular boundary estimation.
%   Center is returned as [x, y].

if nargin < 2 || isempty(retinalFovMask)
    retinalFovMask = fovMask(image);
end

[h, w, c] = size(image);
opticDiscMask = false(h, w);
center = [NaN, NaN];
radius = NaN;
confidence = 0.0;

if ~any(retinalFovMask(:))
    return;
end

% Convert image to double [0, 1]
if isfloat(image)
    imgD = double(image);
    if max(imgD(:)) > 1.0; imgD = imgD / 255.0; end
else
    imgD = double(image) / 255.0;
end

% Optic disc is brightest in Red channel and Luminance
red = imgD(:, :, 1);
gray = 0.2989 * imgD(:, :, 1) + 0.5870 * imgD(:, :, min(2, c)) + 0.1140 * imgD(:, :, min(3, c));

% Erode retinal mask to eliminate bright edge/rim artifacts
fovProps = regionprops(retinalFovMask, 'EquivDiameter', 'Centroid');
if isempty(fovProps)
    return;
end
fovDiameter = fovProps(1).EquivDiameter;
expectedDiscRadius = round(fovDiameter * 0.07); % OD is ~1/14 of retinal diameter
expectedDiscRadius = max(10, min(80, expectedDiscRadius));

safeFov = imerode(retinalFovMask, strel('disk', max(5, round(expectedDiscRadius * 0.8)), 0));
if ~any(safeFov(:))
    safeFov = retinalFovMask;
end

% Intensity combination: high red, high brightness, vessel variance
combinedIntensity = (0.7 * red + 0.3 * gray) .* safeFov;

% Candidate region extraction: Top 2% brightest pixels within safe FOV
validPix = combinedIntensity(safeFov);
if isempty(validPix)
    return;
end
brightCutoff = prctile(validPix, 98.0);
candMask = combinedIntensity >= brightCutoff & safeFov;

% Filter candidates by morphological area and circularity
candMask = imclose(candMask, strel('disk', max(3, round(expectedDiscRadius * 0.3)), 0));
candMask = imfill(candMask, 'holes');
candMask = bwareaopen(candMask, round(pi * (expectedDiscRadius * 0.3)^2));

props = regionprops(candMask, combinedIntensity, 'Centroid', 'Area', 'EquivDiameter', ...
    'Circularity', 'MeanIntensity');

if isempty(props)
    % Fallback: Peak intensity pixel
    [~, maxIdx] = max(combinedIntensity(:));
    [maxY, maxX] = ind2sub([h, w], maxIdx);
    center = [maxX, maxY];
    radius = expectedDiscRadius;
    confidence = 0.35;
else
    % Score candidate components by brightness, area similarity, and circularity
    scores = zeros(numel(props), 1);
    for k = 1:numel(props)
        areaRatio = props(k).EquivDiameter / (2 * expectedDiscRadius);
        areaScore = exp(-0.5 * ((areaRatio - 1.0) / 0.5)^2);
        circScore = min(1.0, props(k).Circularity);
        intScore = props(k).MeanIntensity;
        scores(k) = 0.4 * intScore + 0.3 * circScore + 0.3 * areaScore;
    end
    [bestScore, bestIdx] = max(scores);
    center = round(props(bestIdx).Centroid);
    radius = round(props(bestIdx).EquivDiameter / 2);
    radius = max(round(expectedDiscRadius * 0.6), min(round(expectedDiscRadius * 1.5), radius));
    confidence = min(0.95, max(0.40, bestScore));
end

% Generate circular mask around detected center
[X, Y] = meshgrid(1:w, 1:h);
distFromCenter = sqrt((X - center(1)).^2 + (Y - center(2)).^2);
opticDiscMask = (distFromCenter <= radius) & retinalFovMask;

if nargout <= 1
    odStruct = struct();
    odStruct.mask = opticDiscMask;
    odStruct.center = center;
    odStruct.radius = radius;
    odStruct.confidence = confidence;
    opticDiscMask = odStruct;
end
end
