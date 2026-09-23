function outputImage = enhanceBorderline(inputImage, mask, config)
%ENHANCEBORDERLINE Safe illumination normalization and CLAHE for borderline captures.
%   OUTPUTIMAGE = enhanceBorderline(IMAGE, MASK, CONFIG) normalizes background
%   illumination on the green channel and applies conservative contrast-limited
%   adaptive histogram equalization without creating artificial lesions.
%   The original image is never overwritten.

if nargin < 3 || isempty(config)
    config = struct('illuminationSigma', 16, 'claheEnabled', true, ...
        'denoiseDegree', 0.05);
end
if isfield(config, 'quality') && isstruct(config.quality)
    config = config.quality;
end
if ~isfield(config, 'illuminationSigma'); config.illuminationSigma = 16; end
if ~isfield(config, 'claheEnabled'); config.claheEnabled = true; end
if ~isfield(config, 'denoiseDegree'); config.denoiseDegree = 0.05; end

if nargin < 2 || isempty(mask)
    [mask, ~] = fovMask(inputImage, config);
end

[unitImage, originalClass] = localToUnitDouble(inputImage);
mask = logical(mask);

if ~isequal(size(mask), [size(unitImage, 1), size(unitImage, 2)])
    error('quality:InvalidMask', 'The FOV mask must match image height and width.');
end

output = unitImage;
if ~any(mask(:))
    outputImage = localFromUnitDouble(output, originalClass);
    return;
end

green = localGreen(output);
background = imgaussfilt(green, config.illuminationSigma);
backgroundMean = mean(background(mask));
normalizedGreen = green - background + backgroundMean;
normalizedGreen = min(max(normalizedGreen, 0), 1);

% CLAHE is contrast-limited to avoid turning sensor noise into lesions
if config.claheEnabled && min(size(normalizedGreen)) >= 8
    enhancedGreen = adapthisteq(normalizedGreen, ...
        'NumTiles', [8, 8], 'ClipLimit', 0.01, 'Distribution', 'rayleigh');
else
    enhancedGreen = normalizedGreen;
end

if size(output, 3) == 1
    output(:, :, 1) = enhancedGreen;
else
    output(:, :, 2) = enhancedGreen;
end

% Denoise safely
if min(size(output, [1, 2])) >= 10 && exist('imnlmfilt', 'file') == 2
    if size(output, 3) == 1
        output = imnlmfilt(output, 'DegreeOfSmoothing', config.denoiseDegree);
    else
        for ch = 1:size(output, 3)
            output(:, :, ch) = imnlmfilt(output(:, :, ch), 'DegreeOfSmoothing', config.denoiseDegree);
        end
    end
else
    for ch = 1:size(output, 3)
        output(:, :, ch) = imgaussfilt(output(:, :, ch), 0.35);
    end
end

% Preserve exact outside-mask background pixels
outsideMask = ~mask;
for ch = 1:size(output, 3)
    origCh = unitImage(:, :, ch);
    enhCh = output(:, :, ch);
    enhCh(outsideMask) = origCh(outsideMask);
    output(:, :, ch) = min(max(enhCh, 0), 1);
end

outputImage = localFromUnitDouble(output, originalClass);
end

function [img, originalClass] = localToUnitDouble(inputImage)
originalClass = class(inputImage);
if isfloat(inputImage)
    if max(inputImage(:)) > 1.0
        img = double(inputImage) / 255;
    else
        img = double(inputImage);
    end
else
    img = double(inputImage) / double(intmax(originalClass));
end
img = max(0, min(1, img));
end

function img = localFromUnitDouble(unitImage, targetClass)
switch targetClass
    case 'uint8'
        img = uint8(round(unitImage * 255));
    case 'uint16'
        img = uint16(round(unitImage * 65535));
    case 'single'
        img = single(unitImage);
    otherwise
        img = double(unitImage);
end
end

function green = localGreen(image)
if size(image, 3) == 1
    green = image(:, :, 1);
else
    green = image(:, :, 2);
end
end
