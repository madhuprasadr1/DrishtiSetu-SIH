function overlay = generateLesionMap(image, lesionResult, anatomyResult)
%GENERATELESIONMAP High-contrast color-coded lesion evidence map.
%   OVERLAY = generateLesionMap(IMAGE, LESIONRESULT, ANATOMYRESULT) renders
%   color-coded contours of microaneurysms, haemorrhages, hard exudates,
%   and soft exudates atop the retinal fundus background.

if nargin >= 3 && isfield(lesionResult, 'evidenceOverlay') && ~isempty(lesionResult.evidenceOverlay)
    overlay = lesionResult.evidenceOverlay;
    return;
end

if nargin < 3
    anatomyResult = struct();
end

ev = lesions.buildLesionEvidence(image, lesionResult, anatomyResult);
overlay = ev.evidenceOverlay;
end
