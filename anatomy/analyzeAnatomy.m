function anatomyResult = analyzeAnatomy(image, varargin)
%ANALYZEANATOMY Comprehensive retinal anatomy analysis engine for DrishtiSetu.
%   ANATOMYRESULT = analyzeAnatomy(IMAGE, CONFIG, EYELATERALITY) or
%   ANATOMYRESULT = analyzeAnatomy(IMAGE, MASK, EYELATERALITY, CONFIG)
%   locates and quantifies:
%       - Retinal field of view and boundaries (retinalMask)
%       - Optic nerve head (opticDiscMask, opticDiscCenter, radius, confidence)
%       - Macula and Fovea centralis (foveaLocation, foveaMask, confidence)
%       - Retinal vasculature (vesselMask, vesselSkeleton, vesselDensity)
%       - Quantitative biomarkers (branch points, quadrant vessel density)

retMask = [];
config = projectConfig();
eyeLaterality = 'OD';

for k = 1:numel(varargin)
    arg = varargin{k};
    if islogical(arg) && (ismatrix(arg) || ndims(arg) == 2)
        retMask = arg;
    elseif (ischar(arg) || isstring(arg)) && ismember(upper(char(arg)), {'OD', 'OS'})
        eyeLaterality = char(arg);
    elseif isstruct(arg)
        config = arg;
    end
end

% 1. Retinal FOV Mask
if isempty(retMask)
    [retMask, fovInfo] = retinalMask(image, config);
else
    fovInfo = struct('mask', retMask);
end

% 2. Optic Disc Localization
[odMask, odCenter, odRadius, odConf] = opticDisc(image, retMask);

% 3. Fovea Localization
[fovLocation, fovMask, fovConf] = fovea(image, retMask, odCenter, odRadius, eyeLaterality);

% 4. Vessel Segmentation
[vesMask, probMap] = vessels(image, config, retMask);

% 5. Vascular Biomarkers
vFeatures = vesselFeatures(vesMask, retMask);

anatomyResult = struct();
anatomyResult.retinalMask = retMask;
anatomyResult.fovInfo = fovInfo;
anatomyResult.opticDiscMask = odMask;
anatomyResult.opticDiscCenter = odCenter;
anatomyResult.opticDiscRadius = odRadius;
anatomyResult.opticDiscConfidence = odConf;
anatomyResult.foveaLocation = fovLocation;
anatomyResult.foveaMask = fovMask;
anatomyResult.foveaConfidence = fovConf;
anatomyResult.vesselMask = vesMask;
anatomyResult.vesselProbabilityMap = probMap;
anatomyResult.vesselSkeleton = vFeatures.skeleton;
anatomyResult.vesselDensity = vFeatures.vesselDensity;
anatomyResult.quadrantVesselDensity = vFeatures.quadrantVesselDensity;
anatomyResult.vesselFeatures = vFeatures;

% Convenience aliases for tests and modular subsystems
anatomyResult.opticDisc = struct('center', odCenter, 'radius', odRadius, 'mask', odMask, 'confidence', odConf);
anatomyResult.fovea = struct('center', fovLocation, 'mask', fovMask, 'confidence', fovConf);
anatomyResult.vessels = struct('mask', vesMask, 'skeleton', vFeatures.skeleton, 'density', vFeatures.vesselDensity);
anatomyResult.quadrants = vFeatures.quadrantVesselDensity;
end
