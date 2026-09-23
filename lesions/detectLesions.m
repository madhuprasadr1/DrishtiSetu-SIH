function lesionResult = detectLesions(image, varargin)
%DETECTLESIONS Main Lesion Engine entry point for DrishtiSetu.
%   LESIONRESULT = detectLesions(IMAGE, CONFIG, ANATOMYINFO) or
%   LESIONRESULT = detectLesions(IMAGE, MASK, ANATOMYINFO, CONFIG)
%   detects, segments, and counts microaneurysms, haemorrhages, hard exudates,
%   and soft exudates, incorporating spatial context and distance to fovea/OD.

config = projectConfig();
anatomyInfo = struct();

for k = 1:numel(varargin)
    arg = varargin{k};
    if islogical(arg) && (ismatrix(arg) || ndims(arg) == 2)
        anatomyInfo.retinalMask = arg;
    elseif isstruct(arg)
        if isfield(arg, 'opticDisc') || isfield(arg, 'opticDiscMask') || isfield(arg, 'retinalMask') || isfield(arg, 'vessels') || isfield(arg, 'vesselMask')
            anatomyInfo = arg;
        elseif isfield(arg, 'lesions') || isfield(arg, 'models') || isfield(arg, 'quality')
            config = arg;
        end
    end
end

% 1. Multi-type segmentation
segRes = segmentLesions(image, config, anatomyInfo);

% 2. Spatial evidence aggregation & overlay
evRes = buildLesionEvidence(image, segRes, anatomyInfo);

lesionResult = struct();
lesionResult.microaneurysms = evRes.details.MA;
lesionResult.haemorrhages = evRes.details.HE;
lesionResult.hardExudates = evRes.details.EX;
lesionResult.softExudates = evRes.details.SE;
lesionResult.totalCandidateCount = evRes.totalCandidateCount;
lesionResult.evidenceSource = segRes.source;
lesionResult.evidenceOverlay = evRes.evidenceOverlay;
lesionResult.segmentationResult = segRes;
lesionResult.evidenceDetails = evRes;

% Convenience aliases for tests and modular subsystems
lesionResult.masks = segRes.masks;
lesionResult.counts = segRes.counts;
lesionResult.quadrants = assignLesionQuadrants(segRes.masks, anatomyInfo);
lesionResult.threatToFovea = false;
if isfield(evRes, 'threatToFovea')
    lesionResult.threatToFovea = evRes.threatToFovea;
end
end
