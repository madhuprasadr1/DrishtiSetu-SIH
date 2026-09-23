function [vesselMask, probabilityMap] = vessels(image, config, fovMask)
%VESSELS Segment retinal vasculature with deep learning or classical matched filtering.
%   [VESSELMASK, PROBABILITYMAP] = vessels(IMAGE, CONFIG, FOVMASK)
%   segments the retinal vessel tree. If a trained vessel checkpoint exists,
%   it performs inference; otherwise, it executes robust multi-scale CLAHE
%   matched filtering and top-hat morphology.

if nargin >= 2 && (islogical(config) || (isnumeric(config) && ~isstruct(config)))
    actualMask = config;
    if nargin >= 3 && isstruct(fovMask)
        actualConfig = fovMask;
    else
        actualConfig = projectConfig();
    end
    config = actualConfig;
    fovMask = actualMask;
else
    if nargin < 2 || isempty(config)
        config = projectConfig();
    end
    if nargin < 3 || isempty(fovMask)
        fovMask = fovMask(image);
    end
end

[h, w, ~] = size(image);
vesselMask = false(h, w);
probabilityMap = zeros(h, w, 'single');

if ~any(fovMask(:))
    return;
end

% Check if trained deep learning checkpoint is available
hasDLModel = false;
modelPath = '';
if isfield(config, 'vessel_segmentation') && isfield(config.vessel_segmentation, 'checkpoint')
    modelPath = config.vessel_segmentation.checkpoint;
    if isfile(modelPath)
        hasDLModel = true;
    end
end

if hasDLModel
    try
        dlResult = segment.segmentVessels(image, modelPath, 'FieldOfView', fovMask);
        vesselMask = dlResult.vesselMask;
        probabilityMap = dlResult.probabilityMap;
        return;
    catch
        % Fall through to classical segmentation
    end
end

% Robust Classical Matched-Filter Vessel Segmentation
if isfloat(image)
    green = double(image(:, :, min(2, size(image, 3))));
    if max(green(:)) > 1.0; green = green / 255.0; end
else
    green = double(image(:, :, min(2, size(image, 3)))) / 255.0;
end

% Contrast inversion: vessels are dark in green channel
invertedGreen = 1.0 - green;
invertedGreen(~fovMask) = 0;

% Local CLAHE
if min(size(invertedGreen)) >= 16
    enhanced = adapthisteq(invertedGreen, 'NumTiles', [8, 8], 'ClipLimit', 0.02);
else
    enhanced = invertedGreen;
end

% Multi-angle linear structuring elements to capture elongated vessel tracts
orientations = 0:15:165;
linearResponses = zeros(h, w, numel(orientations), 'double');
lineLength = max(9, round(min(h, w) * 0.025));

for idx = 1:numel(orientations)
    se = strel('line', lineLength, orientations(idx));
    linearResponses(:, :, idx) = imtophat(enhanced, se);
end
maxLinear = max(linearResponses, [], 3);

% Multi-scale disk opening to remove non-linear bright blobs
diskOpen = imopen(maxLinear, strel('disk', 1, 0));
vesselEnhanced = diskOpen .* double(fovMask);

% Erode border to avoid rim detection
erodedFov = imerode(fovMask, strel('disk', 3, 0));
vesselEnhanced(~erodedFov) = 0;

% Normalise probability map
vals = vesselEnhanced(erodedFov);
if ~isempty(vals) && max(vals) > min(vals)
    normMap = (vesselEnhanced - min(vals)) / (max(vals) - min(vals));
    probabilityMap = single(normMap .* double(fovMask));
    threshold = prctile(vals, 82); % Top ~18% vessel pixel density
    rawMask = (vesselEnhanced >= threshold) & erodedFov;
    % Clean up small spurious noise
    vesselMask = bwareaopen(rawMask, max(15, round(min(h, w) * 0.05)));
else
    vesselMask = false(h, w);
    probabilityMap = zeros(h, w, 'single');
end
end
