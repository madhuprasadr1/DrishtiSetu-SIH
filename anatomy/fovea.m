function [foveaLocation, foveaMask, confidence] = fovea(image, retinalMask, opticDiscCenter, opticDiscRadius, eyeLaterality)
%FOVEA Localize the fovea / macula centralis in fundus photography.
%   [LOCATION, MASK, CONFIDENCE] = fovea(IMAGE, RETINALMASK, ODCENTER, ODRADIUS, EYELATERALITY)
%   uses anatomical priors and local reflectance:
%   The fovea is located approximately 2.5 optic disc diameters (~5x radius)
%   temporal to the optic disc in an avascular, low-reflectance zone.
%   Returns LOCATION as [x, y].

if nargin < 2 || isempty(retinalMask)
    retinalMask = fovMask(image);
end
if nargin >= 3 && isstruct(opticDiscCenter)
    odStruct = opticDiscCenter;
    if nargin >= 4 && (ischar(opticDiscRadius) || isstring(opticDiscRadius))
        eyeLaterality = char(opticDiscRadius);
    end
    if isfield(odStruct, 'center'); opticDiscCenter = odStruct.center; end
    if isfield(odStruct, 'radius'); opticDiscRadius = odStruct.radius; end
end

if nargin < 3 || isempty(opticDiscCenter) || any(isnan(opticDiscCenter))
    [~, opticDiscCenter, opticDiscRadius] = opticDisc(image, retinalMask);
end
if nargin < 4 || isempty(opticDiscRadius) || isnan(opticDiscRadius)
    opticDiscRadius = 30;
end
if nargin < 5 && isempty(eyeLaterality)
    eyeLaterality = '';
end

[h, w, c] = size(image);
foveaLocation = [NaN, NaN];
foveaMask = false(h, w);
confidence = 0.0;

if ~any(retinalMask(:))
    return;
end

% Retinal centroid
fovProps = regionprops(retinalMask, 'Centroid');
if isempty(fovProps)
    return;
end
fovCenter = fovProps(1).Centroid;

% Infer temporal direction from OD position and laterality
% Disc is nasal, Fovea is temporal.
if strcmpi(eyeLaterality, 'OD')
    % Right Eye: Disc is nasal (left), Fovea is temporal (right)
    temporalSign = 1;
elseif strcmpi(eyeLaterality, 'OS')
    % Left Eye: Disc is nasal (right), Fovea is temporal (left)
    temporalSign = -1;
else
    % Infer from disc position relative to retinal center
    if opticDiscCenter(1) < fovCenter(1)
        temporalSign = 1; % Disc on left -> Fovea on right
    else
        temporalSign = -1; % Disc on right -> Fovea on left
    end
end

% Expected foveal distance from disc: ~4.5 to 5.5 * disc radius
expectedDistance = 5.0 * opticDiscRadius;
expectedX = round(opticDiscCenter(1) + temporalSign * expectedDistance);
expectedY = round(opticDiscCenter(2) + 0.1 * expectedDistance); % Fovea is slightly lower or level

% Clamp to image bounds
expectedX = max(round(w * 0.1), min(round(w * 0.9), expectedX));
expectedY = max(round(h * 0.1), min(round(h * 0.9), expectedY));

% Search window of radius ~1.5 * disc radius around expected location
searchRadius = round(1.5 * opticDiscRadius);
[X, Y] = meshgrid(1:w, 1:h);
searchMask = sqrt((X - expectedX).^2 + (Y - expectedY).^2) <= searchRadius;
searchMask = searchMask & retinalMask;

if ~any(searchMask(:))
    foveaLocation = [expectedX, expectedY];
    confidence = 0.40;
else
    % Green channel represents macular pigment absorption best (darkest)
    if isfloat(image)
        green = double(image(:, :, min(2, c)));
        if max(green(:)) > 1.0; green = green / 255.0; end
    else
        green = double(image(:, :, min(2, c))) / 255.0;
    end
    
    % Smooth slightly to reduce vessel noise
    smoothedGreen = imgaussfilt(green, max(1.5, opticDiscRadius * 0.1));
    
    % Mask search area
    maskedSearch = smoothedGreen;
    maskedSearch(~searchMask) = Inf;
    
    [minVal, minIdx] = min(maskedSearch(:));
    if isfinite(minVal)
        [foveaY, foveaX] = ind2sub([h, w], minIdx);
        foveaLocation = [foveaX, foveaY];
        confidence = 0.85;
    else
        foveaLocation = [expectedX, expectedY];
        confidence = 0.50;
    end
end

% Circular fovea mask (Foveal Avascular Zone ~ 0.5 * disc radius)
fazRadius = max(5, round(opticDiscRadius * 0.5));
foveaDist = sqrt((X - foveaLocation(1)).^2 + (Y - foveaLocation(2)).^2);
foveaMask = (foveaDist <= fazRadius) & retinalMask;

if nargout <= 1
    fovStruct = struct();
    fovStruct.center = foveaLocation;
    fovStruct.location = foveaLocation;
    fovStruct.mask = foveaMask;
    fovStruct.confidence = confidence;
    foveaLocation = fovStruct;
end
end
