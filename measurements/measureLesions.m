function measurements = measureLesions(image, lesions, anatomy, config)
%MEASURELESIONS Canonical Quantitative Measurement Engine for DrishtiSetu.
%   MEASUREMENTS = measureLesions(IMAGE, LESIONS, ANATOMY, CONFIG)
%   computes rigorous physical and normalized geometric measurements for
%   every candidate lesion detected across all 4 key pathologies:
%       - Microaneurysms (MA)
%       - Haemorrhages (HE)
%       - Hard Exudates (EX)
%       - Soft Exudates (SE / Cotton Wool Spots)
%
%   Computes for every candidate:
%       Count, Area (A), Equivalent Diameter (D = 2*sqrt(A/pi)),
%       Shape (Perimeter, Circularity, Eccentricity, Major/Minor Axis),
%       Location (X/Y, Quadrant, Dist to Fovea, Dist to Optic Disc in DD).
%
%   Part of Module M06: Quantitative Measurement Engine.

if nargin < 2 || isempty(lesions);  lesions = struct();  end
if nargin < 3 || isempty(anatomy);  anatomy = struct();  end
if nargin < 4 || isempty(config);   config = projectConfig(); end

[H, W, ~] = size(image);

% Determine scale calibration
scaleCalibration = struct('hasScale', false, 'umPerPixel', NaN);
if isfield(config, 'calibration') && isfield(config.calibration, 'umPerPixel')
    scaleCalibration.hasScale = true;
    scaleCalibration.umPerPixel = config.calibration.umPerPixel;
end

% Extract anatomical reference anchors
foveaLoc = [NaN, NaN];
if isfield(anatomy, 'foveaLocation') && ~isempty(anatomy.foveaLocation)
    foveaLoc = anatomy.foveaLocation;
    if max(foveaLoc) <= 1.0; foveaLoc = [foveaLoc(1)*W, foveaLoc(2)*H]; end
end

odCenter = [NaN, NaN];
discDiameter = 80; % Default
if isfield(anatomy, 'opticDiscCenter') && ~isempty(anatomy.opticDiscCenter)
    odCenter = anatomy.opticDiscCenter;
    if max(odCenter) <= 1.0; odCenter = [odCenter(1)*W, odCenter(2)*H]; end
end
if isfield(anatomy, 'opticDiscMask') && ~isempty(anatomy.opticDiscMask)
    odProps = regionprops(anatomy.opticDiscMask, 'EquivDiameter', 'Centroid');
    if ~isempty(odProps)
        discDiameter = odProps(1).EquivDiameter;
        if any(isnan(odCenter)); odCenter = odProps(1).Centroid; end
    end
end

eye = 'OD';
if isfield(config, 'eye'); eye = config.eye; end

measurements = struct( ...
    'version', 'DS-MEASUREMENT-1.0', ...
    'scaleCalibration', scaleCalibration, ...
    'unitArea', 'pixels', ...
    'unitDiameter', 'pixels', ...
    'totalLesionCount', 0, ...
    'totalLesionArea', 0, ...
    'macularThreatCount', 0, ...
    'quadrantCounts', struct('ST', 0, 'IT', 0, 'SN', 0, 'IN', 0), ...
    'microaneurysms', struct('count', 0, 'totalArea', 0, 'details', []), ...
    'haemorrhages', struct('count', 0, 'totalArea', 0, 'details', []), ...
    'hardExudates', struct('count', 0, 'totalArea', 0, 'details', []), ...
    'softExudates', struct('count', 0, 'totalArea', 0, 'details', []));

categories = { ...
    'microaneurysms', 'MA'; ...
    'haemorrhages',   'HE'; ...
    'hardExudates',   'EX'; ...
    'softExudates',   'SE' ...
};

for c = 1:size(categories, 1)
    fieldKey = categories{c, 1};
    tag = categories{c, 2};
    
    mask = false(H, W);
    if isfield(lesions, fieldKey) && isfield(lesions.(fieldKey), 'mask') && ~isempty(lesions.(fieldKey).mask)
        mask = logical(lesions.(fieldKey).mask);
        if size(mask, 1) ~= H || size(mask, 2) ~= W
            mask = imresize(mask, [H, W], 'nearest');
        end
    end
    
    if ~any(mask(:))
        continue;
    end
    
    cc = bwconncomp(mask);
    props = regionprops(cc, 'Area', 'Centroid', 'Perimeter', 'Eccentricity', 'MajorAxisLength', 'MinorAxisLength');
    nRegions = numel(props);
    
    details = repmat(struct( ...
        'id', 0, 'type', tag, 'centroid', [0, 0], 'pixelArea', 0, ...
        'calibratedArea', 0, 'equivDiameter', 0, 'shape', struct(), ...
        'location', struct()), nRegions, 1);
    
    catArea = 0;
    
    for r = 1:nRegions
        p = props(r);
        [pArea, cArea, unitA] = calculateArea(p, scaleCalibration);
        [eqDiam, unitD] = calculateDiameter(pArea, unitA);
        sMetrics = calculateShape(p);
        lMetrics = calculateAnatomicalDistance(p.Centroid, foveaLoc, odCenter, discDiameter, eye);
        
        details(r).id = r;
        details(r).type = tag;
        details(r).centroid = p.Centroid;
        details(r).pixelArea = pArea;
        details(r).calibratedArea = cArea;
        details(r).equivDiameter = eqDiam;
        details(r).shape = sMetrics;
        details(r).location = lMetrics;
        
        catArea = catArea + pArea;
        measurements.totalLesionCount = measurements.totalLesionCount + 1;
        measurements.totalLesionArea = measurements.totalLesionArea + pArea;
        
        % Check for Macular Threat (within 1 Disc Diameter of fovea)
        if ~isnan(lMetrics.distToFoveaDD) && lMetrics.distToFoveaDD <= 1.0
            measurements.macularThreatCount = measurements.macularThreatCount + 1;
        end
        
        % Quadrant counts
        if isfield(measurements.quadrantCounts, lMetrics.quadrant)
            measurements.quadrantCounts.(lMetrics.quadrant) = ...
                measurements.quadrantCounts.(lMetrics.quadrant) + 1;
        end
    end
    
    measurements.(fieldKey).count = nRegions;
    measurements.(fieldKey).totalArea = catArea;
    measurements.(fieldKey).details = details;
end

if scaleCalibration.hasScale
    measurements.unitArea = 'um^2';
    measurements.unitDiameter = 'um';
end
end
