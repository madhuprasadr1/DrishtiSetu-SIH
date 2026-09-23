function evidence = buildLesionEvidence(image, lesionResult, anatomyResult)
%BUILDLESIONEVIDENCE Combine lesion candidates with spatial anatomical context.
%   EVIDENCE = buildLesionEvidence(IMAGE, LESIONRESULT, ANATOMYRESULT)
%   computes distance of each lesion to the fovea (macula) and optic disc,
%   partitions lesions into quadrants (ST, IT, SN, IN), and creates a
%   color-coded visual evidence overlay.

if nargin < 3 || isempty(anatomyResult)
    anatomyResult = struct('foveaLocation', [NaN, NaN], ...
        'opticDiscCenter', [NaN, NaN], 'opticDiscRadius', 30, ...
        'retinalMask', fovMask(image));
end

foveaLoc = anatomyResult.foveaLocation;
odLoc = anatomyResult.opticDiscCenter;
imgSize = [size(image, 1), size(image, 2)];

frame = struct('foveaLocation', foveaLoc, 'opticDiscCenter', odLoc);

lesionTypes = {'MA', 'HE', 'EX', 'SE'};
typeNames = {'Microaneurysms', 'Haemorrhages', 'Hard Exudates', 'Soft Exudates'};
colors = struct('MA', [1, 0, 0], 'HE', [0.8, 0, 0.4], 'EX', [1, 1, 0], 'SE', [0.2, 0.8, 1]);

evidence = struct();
evidence.types = lesionTypes;
evidence.details = struct();
totalCandidates = 0;

for t = 1:numel(lesionTypes)
    tCode = lesionTypes{t};
    cCount = lesionResult.counts.(tCode);
    cCentroids = lesionResult.centroids.(tCode);
    cMask = lesionResult.masks.(tCode);
    
    totalCandidates = totalCandidates + cCount;
    
    % Quadrants
    [quadLabels, quadCounts] = assignLesionQuadrants(cCentroids, frame, imgSize);
    
    % Distances to fovea and optic disc (in pixels)
    distToFovea = [];
    distToOD = [];
    if cCount > 0 && all(isfinite(foveaLoc))
        diffFov = cCentroids - foveaLoc;
        distToFovea = sqrt(sum(diffFov.^2, 2));
    end
    if cCount > 0 && all(isfinite(odLoc))
        diffOD = cCentroids - odLoc;
        distToOD = sqrt(sum(diffOD.^2, 2));
    end
    
    item = struct();
    item.name = typeNames{t};
    item.count = cCount;
    item.mask = cMask;
    item.centroids = cCentroids;
    item.quadrantCounts = quadCounts;
    item.quadrantLabels = quadLabels;
    item.distancesToFovea = distToFovea;
    item.distancesToOpticDisc = distToOD;
    
    evidence.details.(tCode) = item;
end

evidence.totalCandidateCount = totalCandidates;

% Build RGB overlay
if isfloat(image)
    baseImg = double(image);
    if max(baseImg(:)) > 1.0; baseImg = baseImg / 255.0; end
else
    baseImg = double(image) / 255.0;
end

overlayRGB = baseImg;
% Highlight each lesion type with its color outline
for t = 1:numel(lesionTypes)
    tCode = lesionTypes{t};
    m = lesionResult.masks.(tCode);
    if any(m(:))
        boundary = imdilate(m, strel('disk', 1, 0)) & ~imerode(m, strel('disk', 1, 0));
        col = colors.(tCode);
        for ch = 1:3
            channel = overlayRGB(:, :, ch);
            channel(boundary) = col(ch);
            overlayRGB(:, :, ch) = channel;
        end
    end
end

% Draw anatomy markers on overlay if available
if all(isfinite(foveaLoc))
    fX = max(1, min(imgSize(2), round(foveaLoc(1))));
    fY = max(1, min(imgSize(1), round(foveaLoc(2))));
    % Cyan crosshair on fovea
    rF = 5;
    yR = max(1, fY-rF):min(imgSize(1), fY+rF);
    xR = max(1, fX-rF):min(imgSize(2), fX+rF);
    overlayRGB(yR, fX, 1) = 0; overlayRGB(yR, fX, 2) = 1; overlayRGB(yR, fX, 3) = 1;
    overlayRGB(fY, xR, 1) = 0; overlayRGB(fY, xR, 2) = 1; overlayRGB(fY, xR, 3) = 1;
end

if all(isfinite(odLoc))
    oX = max(1, min(imgSize(2), round(odLoc(1))));
    oY = max(1, min(imgSize(1), round(odLoc(2))));
    % Orange circle on OD
    rOD = max(5, round(anatomyResult.opticDiscRadius));
    [X, Y] = meshgrid(1:imgSize(2), 1:imgSize(1));
    odRing = abs(sqrt((X - oX).^2 + (Y - oY).^2) - rOD) <= 1.5;
    overlayRGB(odRing & ~isempty(odRing)) = 1.0; % Bright highlight
end

evidence.evidenceOverlay = overlayRGB;
end
