function [maskOut, resultStruct] = detectMicroaneurysmCandidates(inputImage, varargin)
%DETECTMICROANEURYSMCANDIDATES Detect classical dark-dot microaneurysm candidates.
%   MASK = detectMicroaneurysmCandidates(IMAGE, VESSELS, ODMASK, CONFIG)
%   [MASK, RESULT] = detectMicroaneurysmCandidates(...)
%   operates on the green channel using multi-scale disk and oriented linear
%   top-hat morphology. Discriminating compact dark dots from elongated vessels.

vesselMask = [];
odMask = [];
suppliedFovMask = [];
config = projectConfig();

for k = 1:numel(varargin)
    arg = varargin{k};
    if islogical(arg)
        if isempty(vesselMask)
            vesselMask = arg;
        elseif isempty(odMask)
            odMask = arg;
        elseif isempty(suppliedFovMask)
            suppliedFovMask = arg;
        end
    elseif isstruct(arg)
        config = arg;
    end
end

[h, w, c] = size(inputImage);
if isfloat(inputImage)
    imgD = double(inputImage);
    if max(imgD(:)) > 1.0; imgD = imgD / 255.0; end
else
    imgD = double(inputImage) / 255.0;
end

if isempty(suppliedFovMask)
    fMask = fovMask(inputImage);
else
    fMask = logical(suppliedFovMask);
end

green = imgD(:, :, min(2, c));
invertedGreen = 1.0 - green;
invertedGreen(~fMask) = 0;

topHatRadii = [2, 3, 4, 5];
linearLengths = [7, 9, 11];
linearAngles = 0:30:150;
responseThreshold = 0.035;
minArea = 3;

% Multi-scale isotropic disk top-hat (picks up bright-on-inverted = dark dots)
diskResponse = zeros(h, w, 'double');
for r = topHatRadii
    opened = imopen(invertedGreen, strel('disk', r, 0));
    th = invertedGreen - opened;
    diskResponse = max(diskResponse, th);
end

% Directional linear opening to suppress elongated vascular structures
linearMax = zeros(h, w, 'double');
for len = linearLengths
    for ang = linearAngles
        se = strel('line', len, ang);
        openedLin = imopen(invertedGreen, se);
        linearMax = max(linearMax, openedLin);
    end
end

% Subtractive response: isolate round dots that do NOT match linear vessel shapes
response = max(0, diskResponse - 0.75 * (invertedGreen - linearMax));
response(~fMask) = 0;

candidateMask = response >= responseThreshold;

% Suppress candidates overlapping known retinal vasculature
if ~isempty(vesselMask)
    vesselDilated = imdilate(vesselMask, strel('disk', 2, 0));
    candidateMask = candidateMask & ~vesselDilated;
end

% Suppress candidates overlapping the optic disc
if ~isempty(odMask)
    odDilated = imdilate(odMask, strel('disk', 2, 0));
    candidateMask = candidateMask & ~odDilated;
end

% Clean up by morphological area filtering
candCC = bwconncomp(candidateMask);
keepMask = false(h, w);
for i = 1:candCC.NumObjects
    pixelIdx = candCC.PixelIdxList{i};
    area = numel(pixelIdx);
    if area >= minArea && area <= 60 % Microaneurysms are small (typically <60 pixels)
        keepMask(pixelIdx) = true;
    end
end

candProps = regionprops(keepMask, response, 'Centroid', 'Area', 'MeanIntensity', 'Eccentricity');
numCands = numel(candProps);

centroids = zeros(numCands, 2);
areas = zeros(numCands, 1);
scores = zeros(numCands, 1);

for k = 1:numCands
    centroids(k, :) = candProps(k).Centroid;
    areas(k) = candProps(k).Area;
    roundness = 1.0 - candProps(k).Eccentricity;
    scores(k) = min(0.95, max(0.20, candProps(k).MeanIntensity * 10.0 * (0.5 + 0.5 * roundness)));
end

result = struct();
result.candidateMask = keepMask;
result.candidateCount = numCands;
result.candidateCoordinates = centroids;
result.candidateAreas = areas;
result.candidateScores = scores;
result.response = response;

if nargout <= 1
    maskOut = keepMask;
else
    maskOut = keepMask;
    resultStruct = result;
end
end
