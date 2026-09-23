function [quadrantLabels, counts, metadata] = assignLesionQuadrants(coordinates, frame, imageSize)
%ASSIGNLESIONQUADRANTS Map detected lesion coordinates to retinal quadrants.
%   [LABELS, COUNTS, METADATA] = assignLesionQuadrants(COORDINATES, FRAME, IMAGESIZE)
%   or COUNTS = assignLesionQuadrants(MASKS_STRUCT, ANATOMY_STRUCT)
%   partitions coordinates into ST (Superior-Temporal), IT (Inferior-Temporal),
%   SN (Superior-Nasal), and IN (Inferior-Nasal).

if isstruct(coordinates)
    masksStruct = coordinates;
    heMask = [];
    if isfield(masksStruct, 'he') && ~isempty(masksStruct.he); heMask = masksStruct.he;
    elseif isfield(masksStruct, 'HE') && ~isempty(masksStruct.HE); heMask = masksStruct.HE;
    elseif isfield(masksStruct, 'masks')
        if isfield(masksStruct.masks, 'he'); heMask = masksStruct.masks.he;
        elseif isfield(masksStruct.masks, 'HE'); heMask = masksStruct.masks.HE;
        end
    end
    
    if isempty(heMask)
        heCentroids = zeros(0, 2);
    else
        [~, heCentroids] = countLesions(heMask);
    end
    
    frameStruct = struct();
    if nargin >= 2 && isstruct(frame)
        if isfield(frame, 'foveaLocation'); frameStruct.foveaLocation = frame.foveaLocation;
        elseif isfield(frame, 'fovea') && isfield(frame.fovea, 'center'); frameStruct.foveaLocation = frame.fovea.center;
        end
        if isfield(frame, 'opticDiscCenter'); frameStruct.opticDiscCenter = frame.opticDiscCenter;
        elseif isfield(frame, 'opticDisc') && isfield(frame.opticDisc, 'center'); frameStruct.opticDiscCenter = frame.opticDisc.center;
        end
    end
    
    [~, qCounts, meta] = assignLesionQuadrants(heCentroids, frameStruct);
    qCounts.quadrantsWithHemorrhages = nnz(qCounts.quadrantArray > 0);
    qCounts.maxHemorrhagesInAnyQuadrant = max([qCounts.quadrantArray, 0]);
    quadrantLabels = qCounts;
    counts = qCounts;
    metadata = meta;
    return;
end

if nargin < 1 || isempty(coordinates)
    coordinates = zeros(0, 2);
end
if nargin < 2
    frame = struct();
end
if nargin < 3 || isempty(imageSize)
    imageSize = [1000, 1000];
end

if isfield(frame, 'fovea') && isfield(frame.fovea, 'center')
    frame.foveaLocation = frame.fovea.center;
end
if isfield(frame, 'opticDisc') && isfield(frame.opticDisc, 'center')
    frame.opticDiscCenter = frame.opticDisc.center;
end

% Origin and axes
if isfield(frame, 'foveaLocation') && all(isfinite(frame.foveaLocation))
    origin = frame.foveaLocation;
    method = 'fovea_centered';
    isApprox = false;
elseif isfield(frame, 'opticDiscCenter') && all(isfinite(frame.opticDiscCenter))
    origin = frame.opticDiscCenter;
    method = 'optic_disc_centered';
    isApprox = true;
else
    origin = [imageSize(2), imageSize(1)] / 2;
    method = 'image_center_fallback';
    isApprox = true;
end

% Temporal axis direction
temporalAxis = [1, 0]; % Default rightward
if isfield(frame, 'opticDiscCenter') && isfield(frame, 'foveaLocation') && ...
        all(isfinite(frame.opticDiscCenter)) && all(isfinite(frame.foveaLocation))
    diffVec = frame.foveaLocation - frame.opticDiscCenter;
    if norm(diffVec) > 0
        temporalAxis = diffVec / norm(diffVec);
    end
end
superiorAxis = [-temporalAxis(2), temporalAxis(1)]; % 90-degree counter-clockwise

numPoints = size(coordinates, 1);
quadrantLabels = cell(numPoints, 1);

if numPoints > 0
    centered = coordinates - origin;
    tempCoord = centered * temporalAxis.';
    supCoord = centered * superiorAxis.';

    for i = 1:numPoints
        if tempCoord(i) >= 0
            if supCoord(i) >= 0
                quadrantLabels{i} = 'ST';
            else
                quadrantLabels{i} = 'IT';
            end
        else
            if supCoord(i) >= 0
                quadrantLabels{i} = 'SN';
            else
                quadrantLabels{i} = 'IN';
            end
        end
    end
end

counts = struct( ...
    'ST', sum(strcmp(quadrantLabels, 'ST')), ...
    'IT', sum(strcmp(quadrantLabels, 'IT')), ...
    'SN', sum(strcmp(quadrantLabels, 'SN')), ...
    'IN', sum(strcmp(quadrantLabels, 'IN')));
counts.quadrantArray = [counts.ST, counts.IT, counts.SN, counts.IN];
counts.quadrantsWithHemorrhages = nnz(counts.quadrantArray > 0);
counts.maxHemorrhagesInAnyQuadrant = max([counts.quadrantArray, 0]);

metadata = struct();
metadata.origin = origin;
metadata.method = method;
metadata.isApproximate = isApprox;
end
