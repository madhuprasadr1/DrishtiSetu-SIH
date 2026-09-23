function depthInfo = estimateDepth(image, anatomy, lesions, prior)
%ESTIMATEDEPTH Anatomically grounded retinal depth estimation from fundus imagery.
%   DEPTHINFO = estimateDepth(IMAGE, ANATOMY, LESIONS, PRIOR)
%   computes continuous 3D depth surfaces and vascular elevation profiles
%   derived from retinal anatomy geometry, optic cup excavation, foveal
%   depression, vessel caliber topology, and lesion structural relief.
%
%   Part of Module M13: Advanced Estimated 3D Retinal Visualization.
%   Strictly decoupled from primary DR screening; runs offline.

if nargin < 2 || isempty(anatomy)
    anatomy = struct();
end
if nargin < 3 || isempty(lesions)
    lesions = struct();
end
if nargin < 4 || isempty(prior)
    prior = struct();
end

if isempty(image) || ~isnumeric(image) || size(image, 1) < 16 || size(image, 2) < 16
    depthInfo = struct('zSurface', [], 'zNorm', [], 'zGlobe', [], 'zCup', [], ...
        'zFovea', [], 'zVessels', [], 'zLesions', [], 'retinalMask', [], 'vesselMask', [], ...
        'opticDiscCenter', [NaN, NaN], 'foveaLocation', [NaN, NaN], ...
        'bScanProfile', struct('lineCoordinates', [], 'depthCurve', [], 'arcLength', []), ...
        'unit', 'microns (estimated)', 'minElevation', 0, 'maxElevation', 0, 'elevationSpan', 0);
    return;
end

[H, W, ~] = size(image);

% Default prior parameters (calibrated in microns um relative to RPE base)
if ~isfield(prior, 'globeCurvature');  prior.globeCurvature = 45.0;  end % Base retinal dome concavity (um)
if ~isfield(prior, 'opticCupDepth');   prior.opticCupDepth = 280.0;   end % Optic nerve cup excavation (um)
if ~isfield(prior, 'foveaPitDepth');   prior.foveaPitDepth = 135.0;   end % Foveal avascular depression (um)
if ~isfield(prior, 'vesselMaxHeight'); prior.vesselMaxHeight = 85.0;  end % Major vascular relief above NFL (um)
if ~isfield(prior, 'exudateElevation');prior.exudateElevation = 45.0; end % OPL lipid thickening relief (um)
if ~isfield(prior, 'hemElevation');    prior.hemElevation = 35.0;     end % Intraretinal hemorrhage swelling (um)

% 1. Retinal Mask Extraction
retinalMask = true(H, W);
if isfield(anatomy, 'retinalMask') && ~isempty(anatomy.retinalMask)
    retinalMask = logical(anatomy.retinalMask);
    if size(retinalMask, 1) ~= H || size(retinalMask, 2) ~= W
        retinalMask = imresize(retinalMask, [H, W], 'nearest');
    end
else
    % Fallback: compute circular retinal FOV
    gray = rgb2gray(image);
    retinalMask = gray > 12;
    retinalMask = imfill(retinalMask, 'holes');
end

% 2. Posterior Globe Curvature (Spherical concave shell)
[X, Y] = meshgrid(1:W, 1:H);
props = regionprops(retinalMask, 'Centroid', 'MajorAxisLength');
if ~isempty(props)
    cx = props(1).Centroid(1);
    cy = props(1).Centroid(2);
    radius = max(props(1).MajorAxisLength / 2, 50);
else
    cx = W / 2;
    cy = H / 2;
    radius = min(H, W) / 2;
end

distFromCenter = sqrt((X - cx).^2 + (Y - cy).^2);
normDist = min(distFromCenter / radius, 1.0);
% Parabolic concavity approximating spherical posterior segment
zGlobe = -prior.globeCurvature * (normDist .^ 1.8);

% 3. Optic Disc Cup Excavation
zCup = zeros(H, W, 'single');
odCenter = [NaN, NaN];
if isfield(anatomy, 'opticDiscCenter') && ~isempty(anatomy.opticDiscCenter) && ~any(isnan(anatomy.opticDiscCenter))
    odCenter = anatomy.opticDiscCenter;
    if max(odCenter) <= 1.0
        odCenter = [odCenter(1) * W, odCenter(2) * H];
    end
end

odMask = false(H, W);
if isfield(anatomy, 'opticDiscMask') && ~isempty(anatomy.opticDiscMask)
    odMask = logical(anatomy.opticDiscMask);
    if size(odMask, 1) ~= H || size(odMask, 2) ~= W
        odMask = imresize(odMask, [H, W], 'nearest');
    end
    if any(isnan(odCenter))
        odProps = regionprops(odMask, 'Centroid');
        if ~isempty(odProps)
            odCenter = odProps(1).Centroid;
        end
    end
end

if ~any(isnan(odCenter)) && odCenter(1) >= 1 && odCenter(1) <= W && odCenter(2) >= 1 && odCenter(2) <= H
    odDist = sqrt((X - odCenter(1)).^2 + (Y - odCenter(2)).^2);
    cupSigma = max(radius * 0.06, 12);
    zCup = -prior.opticCupDepth * exp(-(odDist.^2) / (2 * (cupSigma^2)));
    if any(odMask(:))
        % Confine deeper excavation to optic disc region
        zCup = zCup .* (single(odMask) * 0.75 + 0.25 * single(imdilate(odMask, strel('disk', round(cupSigma/2)))));
    end
end

% 4. Foveal Avascular Depression (Clivus / Fovea centralis)
zFovea = zeros(H, W, 'single');
fovLoc = [NaN, NaN];
if isfield(anatomy, 'foveaLocation') && ~isempty(anatomy.foveaLocation) && ~any(isnan(anatomy.foveaLocation))
    fovLoc = anatomy.foveaLocation;
    if max(fovLoc) <= 1.0
        fovLoc = [fovLoc(1) * W, fovLoc(2) * H];
    end
elseif ~any(isnan(odCenter))
    % Physiological default: fovea is temporal (~2.5 disc diameters) from optic disc
    if odCenter(1) > W / 2
        fovLoc = [max(1, odCenter(1) - radius * 0.45), odCenter(2) + radius * 0.05];
    else
        fovLoc = [min(W, odCenter(1) + radius * 0.45), odCenter(2) + radius * 0.05];
    end
else
    fovLoc = [cx, cy];
end

if ~any(isnan(fovLoc)) && fovLoc(1) >= 1 && fovLoc(1) <= W && fovLoc(2) >= 1 && fovLoc(2) <= H
    fovDist = sqrt((X - fovLoc(1)).^2 + (Y - fovLoc(2)).^2);
    fovSigma = max(radius * 0.045, 10);
    zFovea = -prior.foveaPitDepth * exp(-(fovDist.^2) / (2 * (fovSigma^2)));
end

% 5. Retinal Vascular Tree Elevation
zVessels = zeros(H, W, 'single');
vesselMask = false(H, W);
if isfield(anatomy, 'vesselMask') && ~isempty(anatomy.vesselMask)
    vesselMask = logical(anatomy.vesselMask);
    if size(vesselMask, 1) ~= H || size(vesselMask, 2) ~= W
        vesselMask = imresize(vesselMask, [H, W], 'nearest');
    end
end

if any(vesselMask(:))
    % Caliber derived from Euclidean distance transform
    distMap = bwdist(~vesselMask);
    maxDist = max(distMap(:));
    if maxDist > 0
        normCaliber = single(distMap) / single(maxDist);
        % Non-linear vascular profile: arcade vessels ridge higher above NFL
        vesselProfile = (normCaliber .^ 0.65);
        
        % Smooth vascular ridge slightly for natural 3D contours
        vesselProfile = imfilter(vesselProfile, fspecial('gaussian', [7, 7], 1.2));
        zVessels = prior.vesselMaxHeight * vesselProfile;
    end
end

% 6. Pathological Lesion Elevation (Structural relief from edema / exudates / microaneurysms)
zLesions = zeros(H, W, 'single');

% Exudates (hard/soft)
exMask = false(H, W);
if isfield(lesions, 'hardExudates') && isfield(lesions.hardExudates, 'mask') && ~isempty(lesions.hardExudates.mask)
    exMask = exMask | logical(lesions.hardExudates.mask);
end
if isfield(lesions, 'softExudates') && isfield(lesions.softExudates, 'mask') && ~isempty(lesions.softExudates.mask)
    exMask = exMask | logical(lesions.softExudates.mask);
end
if any(exMask(:))
    if size(exMask, 1) ~= H || size(exMask, 2) ~= W
        exMask = imresize(exMask, [H, W], 'nearest');
    end
    smoothEx = imfilter(single(exMask), fspecial('gaussian', [9, 9], 2.0));
    zLesions = zLesions + prior.exudateElevation * smoothEx;
end

% Hemorrhages & Microaneurysms
heMask = false(H, W);
if isfield(lesions, 'haemorrhages') && isfield(lesions.haemorrhages, 'mask') && ~isempty(lesions.haemorrhages.mask)
    heMask = heMask | logical(lesions.haemorrhages.mask);
end
if isfield(lesions, 'microaneurysms') && isfield(lesions.microaneurysms, 'mask') && ~isempty(lesions.microaneurysms.mask)
    heMask = heMask | logical(lesions.microaneurysms.mask);
end
if any(heMask(:))
    if size(heMask, 1) ~= H || size(heMask, 2) ~= W
        heMask = imresize(heMask, [H, W], 'nearest');
    end
    smoothHe = imfilter(single(heMask), fspecial('gaussian', [7, 7], 1.5));
    zLesions = zLesions + prior.hemElevation * smoothHe;
end

% 7. Combine Layers into Unified Retinal Elevation Surface (microns)
zTotal = single(zGlobe) + single(zCup) + single(zFovea) + single(zVessels) + single(zLesions);

% Zero out regions outside retinal FOV
zTotal(~retinalMask) = NaN;

% Shift baseline so minimum valid retinal depth begins at 0
minZ = min(zTotal(retinalMask));
if ~isempty(minZ) && ~isnan(minZ)
    zSurface = zTotal - minZ;
else
    zSurface = zTotal;
end

% Calculate normalized depth map [0, 1]
validZ = zSurface(retinalMask);
zNorm = zeros(H, W, 'single');
if ~isempty(validZ)
    rangeZ = max(validZ) - min(validZ);
    if rangeZ > 0
        zNorm(retinalMask) = (zSurface(retinalMask) - min(validZ)) / rangeZ;
    end
end

% 8. Extract Cross-Sectional Retinal B-Scan Profile through Fovea-Disc Axis
bScanProfile = struct('lineCoordinates', [], 'depthCurve', [], 'arcLength', []);
if ~any(isnan(odCenter)) && ~any(isnan(fovLoc))
    t = linspace(0, 1, 120);
    xLine = round(odCenter(1) + t * (fovLoc(1) - odCenter(1)));
    yLine = round(odCenter(2) + t * (fovLoc(2) - odCenter(2)));
    xLine = max(1, min(W, xLine));
    yLine = max(1, min(H, yLine));
    
    linearIdx = sub2ind([H, W], yLine, xLine);
    depthSamples = zSurface(linearIdx);
    
    bScanProfile.lineCoordinates = [xLine(:), yLine(:)];
    bScanProfile.depthCurve = depthSamples(:);
    bScanProfile.arcLength = sqrt((xLine - xLine(1)).^2 + (yLine - yLine(1)).^2);
end

% Assemble Output
depthInfo = struct();
depthInfo.zSurface = zSurface;             % Absolute elevation surface (um)
depthInfo.zNorm = zNorm;                   % Normalized depth [0, 1]
depthInfo.zGlobe = zGlobe;                 % Posterior dome component
depthInfo.zCup = zCup;                     % Optic cup excavation component
depthInfo.zFovea = zFovea;                 % Foveal pit depression component
depthInfo.zVessels = zVessels;             % Vascular tree ridge component
depthInfo.zLesions = zLesions;             % Lesion elevation component
depthInfo.retinalMask = retinalMask;       % FOV mask
depthInfo.vesselMask = vesselMask;         % Vessel mask
depthInfo.opticDiscCenter = odCenter;      % Optic disc coordinates
depthInfo.foveaLocation = fovLoc;          % Fovea coordinates
depthInfo.bScanProfile = bScanProfile;     % B-scan depth profile
depthInfo.unit = 'microns (estimated)';    % Measurement scale
if ~isempty(validZ)
    depthInfo.minElevation = min(validZ);
    depthInfo.maxElevation = max(validZ);
    depthInfo.elevationSpan = max(validZ) - min(validZ);
else
    depthInfo.minElevation = 0;
    depthInfo.maxElevation = 0;
    depthInfo.elevationSpan = 0;
end
end
