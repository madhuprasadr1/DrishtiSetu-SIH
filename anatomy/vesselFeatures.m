function features = vesselFeatures(vesselMask, varargin)
%VESSELFEATURES Extract vascular biomarkers: skeleton, density, branch points.
%   FEATURES = vesselFeatures(VESSELMASK, RETINALMASK)
%   FEATURES = vesselFeatures(VESSELMASK, OD, FOVEA, RETINALMASK)
%   computes:
%       vesselDensity / density       - Ratio of vessel pixels to total retinal area
%       skeleton                      - 1-pixel wide vascular centerline
%       branchPoints                  - Count and coordinates of vascular bifurcations
%       endPoints                     - Count and coordinates of vascular terminations
%       quadrantVesselDensity/density - Density across the 4 retinal quadrants

retinalMask = [];
for k = 1:numel(varargin)
    arg = varargin{k};
    if islogical(arg) && isequal(size(arg), size(vesselMask))
        retinalMask = arg;
    elseif isstruct(arg) && isfield(arg, 'mask') && islogical(arg.mask) && isequal(size(arg.mask), size(vesselMask))
        retinalMask = arg.mask;
    end
end
if isempty(retinalMask)
    retinalMask = true(size(vesselMask));
end

[h, w] = size(vesselMask);
vesselMask = logical(vesselMask) & logical(retinalMask);

totalRetinalPixels = max(1, nnz(retinalMask));
totalVesselPixels = nnz(vesselMask);

% Skeletonization
skeleton = bwmorph(vesselMask, 'thin', Inf);
branchImg = bwmorph(skeleton, 'branchpoints');
endImg = bwmorph(skeleton, 'endpoints');

[bY, bX] = find(branchImg);
[eY, eX] = find(endImg);

% Quadrant densities
rowMid = floor(h / 2);
colMid = floor(w / 2);
quadrants = { ...
    retinalMask & localRect(h, w, 1, rowMid, 1, colMid), ...       % Superior-Temporal / Superior-Left
    retinalMask & localRect(h, w, 1, rowMid, colMid + 1, w), ...   % Superior-Nasal / Superior-Right
    retinalMask & localRect(h, w, rowMid + 1, h, 1, colMid), ...   % Inferior-Temporal / Inferior-Left
    retinalMask & localRect(h, w, rowMid + 1, h, colMid + 1, w)};  % Inferior-Nasal / Inferior-Right

quadrantDensities = zeros(1, 4);
for q = 1:4
    qRetina = nnz(quadrants{q});
    if qRetina > 0
        quadrantDensities(q) = nnz(vesselMask & quadrants{q}) / qRetina;
    end
end

features = struct();
features.vesselDensity = totalVesselPixels / totalRetinalPixels;
features.density = features.vesselDensity;
features.skeleton = skeleton;
features.branchPointCount = numel(bX);
features.branchPoints = features.branchPointCount;
features.branchPointCoordinates = [bX, bY];
features.endPointCount = numel(eX);
features.endPoints = features.endPointCount;
features.endPointCoordinates = [eX, eY];
features.quadrantVesselDensity = quadrantDensities;
features.quadrantDensity = quadrantDensities;
end

function rect = localRect(h, w, r1, r2, c1, c2)
rect = false(h, w);
if r1 <= r2 && c1 <= c2
    rect(r1:r2, c1:c2) = true;
end
end
