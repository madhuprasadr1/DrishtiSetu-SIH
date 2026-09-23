function features = qualityFeatures(inputImage, mask, config)
%QUALITYFEATURES Compute clinical quality metrics inside the retinal FOV only.
%   FEATURES = qualityFeatures(IMAGE, MASK, CONFIG) measures focus (Laplacian,
%   Tenengrad), exposure (mean intensity, dark/saturated fractions),
%   contrast (RMS contrast, Shannon entropy), illumination uniformity across
%   quadrants, and retinal field-of-view area ratio.

if nargin < 3 || isempty(config)
    config = struct();
end
if isfield(config, 'quality') && isstruct(config.quality)
    config = config.quality;
end
if ~isfield(config, 'darkPixelThreshold'); config.darkPixelThreshold = 0.04; end
if ~isfield(config, 'saturationThreshold'); config.saturationThreshold = 0.96; end
if ~isfield(config, 'illuminationSigma'); config.illuminationSigma = 16; end

if nargin < 2 || isempty(mask)
    [mask, ~] = fovMask(inputImage, config);
end

unitImage = localToUnitDouble(inputImage);
gray = localGray(unitImage);
green = localGreen(unitImage);

if ~isequal(size(mask), size(gray))
    error('quality:InvalidMask', 'The FOV mask must match image dimensions.');
end
mask = logical(mask);

features = struct();
features.varianceOfLaplacian = NaN;
features.laplacianVariance = NaN;
features.tenengrad = NaN;
features.tenengradScore = NaN;
features.meanIntensity = NaN;
features.darkPixelFraction = NaN;
features.saturatedPixelFraction = NaN;
features.rmsContrast = NaN;
features.entropy = NaN;
features.quadrantIlluminationVariation = NaN;
features.fovAreaRatio = nnz(mask) / numel(mask);
features.quadrantMeans = [NaN, NaN, NaN, NaN];
features.pixelCount = nnz(mask);

if ~any(mask(:))
    return;
end

metricMask = mask;
erodedMask = imerode(mask, strel('disk', 2, 0));
if any(erodedMask(:))
    metricMask = erodedMask;
end

% Focus: Variance of Laplacian on green channel
laplacianKernel = [0, 1, 0; 1, -4, 1; 0, 1, 0];
laplacian = imfilter(green, laplacianKernel, 'replicate', 'conv');
laplacianValues = laplacian(metricMask);
features.varianceOfLaplacian = localVariance(laplacianValues);
features.laplacianVariance = features.varianceOfLaplacian;

% Focus: Tenengrad gradient energy (mean per pixel inside metric mask)
[gradientX, gradientY] = imgradientxy(green, 'sobel');
tenengradValues = gradientX(metricMask) .^ 2 + gradientY(metricMask) .^ 2;
features.tenengrad = mean(tenengradValues);
features.tenengradScore = features.tenengrad;
features.tenengradSum = sum(tenengradValues);

% Exposure & Contrast
values = green(mask);
features.meanIntensity = mean(values);
features.darkPixelFraction = mean(values <= config.darkPixelThreshold);

% Color saturation across channels (flash glare or over-exposure)
if size(unitImage, 3) >= 3
    isSat = (unitImage(:, :, 1) >= config.saturationThreshold) | ...
            (unitImage(:, :, 2) >= config.saturationThreshold) | ...
            (unitImage(:, :, 3) >= config.saturationThreshold);
else
    isSat = unitImage >= config.saturationThreshold;
end
features.saturatedPixelFraction = mean(isSat(mask));
features.rmsContrast = sqrt(mean((values - features.meanIntensity) .^ 2));
features.entropy = localEntropy(values);

% Illumination uniformity across 4 quadrants
background = imgaussfilt(green, config.illuminationSigma);
[height, width] = size(green);
rowMid = floor(height / 2);
colMid = floor(width / 2);
quadrantMasks = { ...
    mask & localRect(height, width, 1, rowMid, 1, colMid), ...
    mask & localRect(height, width, 1, rowMid, colMid + 1, width), ...
    mask & localRect(height, width, rowMid + 1, height, 1, colMid), ...
    mask & localRect(height, width, rowMid + 1, height, colMid + 1, width)};
for index = 1:4
    qVals = background(quadrantMasks{index});
    if ~isempty(qVals)
        features.quadrantMeans(index) = mean(qVals);
    end
end
validMeans = features.quadrantMeans(isfinite(features.quadrantMeans));
if ~isempty(validMeans)
    features.quadrantIlluminationVariation = std(validMeans, 1) / max(mean(validMeans), eps);
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

function green = localGreen(image)
if size(image, 3) == 1
    green = image(:, :, 1);
else
    green = image(:, :, 2);
end
end

function result = localVariance(values)
if isempty(values)
    result = NaN;
else
    meanValue = mean(values);
    result = mean((values - meanValue) .^ 2);
end
end

function value = localEntropy(values)
counts = histcounts(values, 256, 'BinLimits', [0, 1]);
probabilities = counts / max(sum(counts), 1);
probabilities = probabilities(probabilities > 0);
value = -sum(probabilities .* log2(probabilities));
end

function rect = localRect(h, w, r1, r2, c1, c2)
rect = false(h, w);
if r1 <= r2 && c1 <= c2
    rect(r1:r2, c1:c2) = true;
end
end
