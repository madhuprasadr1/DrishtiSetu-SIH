function [mask, info] = fovMask(inputImage, config)
%FOVMASK Detect the illuminated retinal field and discard the black surround.
%   [MASK, INFO] = fovMask(IMAGE, CONFIG) thresholds the image,
%   keeps the largest filled component, and returns geometric diagnostics
%   for the detected field of view.

if nargin < 2 || isempty(config)
    config = struct('fovThreshold', 0.05, 'centerOffsetLimit', 0.35);
end
if isfield(config, 'quality') && isstruct(config.quality)
    config = config.quality;
end
if ~isfield(config, 'fovThreshold')
    config.fovThreshold = 0.05;
end
if ~isfield(config, 'centerOffsetLimit')
    config.centerOffsetLimit = 0.35;
end

unitImage = localToUnitDouble(inputImage);
gray = localGray(unitImage);

threshold = config.fovThreshold;
foreground = gray > threshold;

% Very dark capture fallback
if ~any(foreground(:)) && max(gray(:)) > 0
    threshold = min(threshold, 0.5 * max(gray(:)));
    foreground = gray > threshold;
end

mask = false(size(gray));
if any(foreground(:))
    foreground = imfill(foreground, 'holes');
    mask = bwareafilt(foreground, 1);
end
mask = logical(mask);

info = struct();
info.detected = any(mask(:));
info.threshold = threshold;
info.imageSize = size(gray);
info.area = nnz(mask);
info.areaRatio = info.area / numel(mask);
info.centroid = [NaN, NaN];
info.boundingBox = [NaN, NaN, NaN, NaN];
info.equivalentDiameter = NaN;
info.radius = NaN;
info.centerOffset = Inf;
info.centered = false;
info.boundaryBrightFraction = NaN;

if info.detected
    stats = regionprops(mask, 'Centroid', 'EquivDiameter', 'BoundingBox');
    info.centroid = stats.Centroid;
    info.boundingBox = stats.BoundingBox;
    info.equivalentDiameter = stats.EquivDiameter;
    info.radius = stats.EquivDiameter / 2;

    imageCenter = [(size(gray, 2) + 1) / 2, (size(gray, 1) + 1) / 2];
    info.centerOffset = norm(info.centroid - imageCenter) / norm(size(gray, [2, 1]));
    info.centered = info.centerOffset <= config.centerOffsetLimit;

    boundary = mask & ~imerode(mask, strel('disk', 1, 0));
    if any(boundary(:))
        info.boundaryBrightFraction = mean(gray(boundary) >= 0.92);
    else
        info.boundaryBrightFraction = 0;
    end
end
end

function img = localToUnitDouble(inputImage)
if isfloat(inputImage)
    if max(inputImage(:)) > 1.0
        img = double(inputImage) / 255;
    else
        img = double(inputImage);
    end
else
    img = double(inputImage) / double(intmax(class(inputImage)));
end
img = max(0, min(1, img));
end

function gray = localGray(image)
if size(image, 3) == 1
    gray = image(:, :, 1);
else
    gray = im2gray(image);
end
end
