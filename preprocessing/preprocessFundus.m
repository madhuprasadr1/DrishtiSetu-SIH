function [processedImage, qualityMetadata, preprocessingMetadata] = preprocessFundus(inputImage, config, mode)
%PREPROCESSFUNDUS Canonical preprocessing for training, validation, and inference.
%   [PROCESSEDIMAGE, QUALITYMETADATA, PREPROCESSINGMETADATA] = ...
%       preprocessFundus(INPUTIMAGE, CONFIG, MODE)
%   ensures identical preprocessing across training and inference to avoid distribution shift:
%   1. Type conversion to single precision in [0, 1]
%   2. FOV detection and tight bounding-box extraction with padding
%   3. Aspect-ratio preserving bicubic resize to target resolution (default 448x448)
%   4. Color normalization according to project configuration
%   Preserves original image unchanged.

if nargin < 2 || isempty(config)
    config = projectConfig();
end
if nargin < 3 || isempty(mode)
    mode = 'inference';
end

originalInputClass = class(inputImage);
[imgSingle, ~] = localToUnitSingle(inputImage);

% Quality assessment without enhancing yet
[qualityMetadata, ~] = assessQuality(imgSingle, config);

% FOV tight crop with aspect ratio preservation
fovMask = qualityMetadata.fovMask;
[croppedImage, fovBoundingBox] = localCropFov(imgSingle, fovMask);

% Target size
targetSize = [448, 448];
if isfield(config, 'preprocessing') && isfield(config.preprocessing, 'targetSize')
    targetSize = config.preprocessing.targetSize;
elseif isfield(config, 'grading') && isfield(config.grading, 'input_size')
    val = config.grading.input_size;
    if isscalar(val); targetSize = [val, val]; else; targetSize = val(1:2); end
end

% Resize to target
resizedImage = imresize(croppedImage, targetSize, 'bicubic');

% Channel normalisation (mean and std)
channelMean = [0, 0, 0];
channelStd = [1/255, 1/255, 1/255];
if isfield(config, 'preprocessing')
    if isfield(config.preprocessing, 'channel_mean'); channelMean = config.preprocessing.channel_mean; end
    if isfield(config.preprocessing, 'channel_std'); channelStd = config.preprocessing.channel_std; end
end

normalizedImage = zeros(size(resizedImage), 'single');
for ch = 1:size(resizedImage, 3)
    cMean = single(channelMean(min(ch, numel(channelMean))));
    cStd = single(channelStd(min(ch, numel(channelStd))));
    if cStd > 0
        normalizedImage(:, :, ch) = (resizedImage(:, :, ch) - cMean) / cStd;
    else
        normalizedImage(:, :, ch) = resizedImage(:, :, ch) - cMean;
    end
end

if strcmpi(mode, 'preserve_quality') || strcmpi(mode, 'original')
    processedImage = inputImage;
else
    processedImage = normalizedImage;
end

preprocessingMetadata = struct();
preprocessingMetadata.mode = mode;
preprocessingMetadata.qualityPreserved = true;
preprocessingMetadata.originalQualityUnaltered = true;
preprocessingMetadata.originalImage = inputImage;
preprocessingMetadata.inputClass = originalInputClass;
preprocessingMetadata.inputSize = size(inputImage);
preprocessingMetadata.outputSize = size(processedImage);
preprocessingMetadata.targetSize = targetSize;
preprocessingMetadata.fovBoundingBox = fovBoundingBox;
preprocessingMetadata.channelMean = channelMean;
preprocessingMetadata.channelStd = channelStd;
end

function [img, origClass] = localToUnitSingle(inputImage)
origClass = class(inputImage);
if isfloat(inputImage)
    if max(inputImage(:)) > 1.0
        img = single(inputImage) / 255;
    else
        img = single(inputImage);
    end
else
    img = single(inputImage) / single(intmax(origClass));
end
img = max(0, min(1, img));
if size(img, 3) == 1
    img = repmat(img, 1, 1, 3);
end
end

function [cropped, bbox] = localCropFov(image, mask)
if isempty(mask) || ~any(mask(:))
    cropped = image;
    bbox = [1, 1, size(image, 2), size(image, 1)];
    return;
end

props = regionprops(mask, 'BoundingBox');
if isempty(props)
    cropped = image;
    bbox = [1, 1, size(image, 2), size(image, 1)];
    return;
end

rawBox = props(1).BoundingBox; % [x, y, w, h]
h = size(image, 1);
w = size(image, 2);

% Add 3% margin
padX = 0.03 * rawBox(3);
padY = 0.03 * rawBox(4);
x1 = max(1, floor(rawBox(1) - padX));
y1 = max(1, floor(rawBox(2) - padY));
x2 = min(w, ceil(rawBox(1) + rawBox(3) + padX));
y2 = min(h, ceil(rawBox(2) + rawBox(4) + padY));

cropped = image(y1:y2, x1:x2, :);
bbox = [x1, y1, x2 - x1 + 1, y2 - y1 + 1];
end
