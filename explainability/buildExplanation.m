function narrative = buildExplanation(drResult, lesionResult, anatomyResult, safetyResult)
%BUILDEXPLANATION Synthesize clinical findings into a dynamic narrative explanation.
%   NARRATIVE = buildExplanation(DRRESULT, LESIONRESULT, ANATOMYRESULT, SAFETYRESULT)
%   generates a coherent, non-hardcoded clinical decision-support explanation.
%   Adheres strictly to medical-safety screening terminology (no autonomous diagnosis).

grade = drResult.drGrade;
gradeLabel = drResult.drLabel;
calibratedRisk = drResult.calibratedReferableProbability * 100;
confidence = safetyResult.confidenceScore * 100;
uncertainty = safetyResult.uncertaintyScore * 100;

lines = {};
lines{end + 1} = sprintf('AI SCREENING EVALUATION: %s', upper(gradeLabel));
lines{end + 1} = sprintf('Calibrated Referable DR Risk: %.1f%%  |  Model Confidence: %.1f%%  |  Uncertainty: %.1f%%', ...
    calibratedRisk, confidence, uncertainty);
lines{end + 1} = '';

% Lesion Evidence Section
lines{end + 1} = 'Retinal Lesion Evidence:';
maCount = lesionResult.microaneurysms.count;
heCount = lesionResult.haemorrhages.count;
exCount = lesionResult.hardExudates.count;
seCount = lesionResult.softExudates.count;

if (maCount == 0) && (heCount == 0) && (exCount == 0) && (seCount == 0)
    lines{end + 1} = '  - No discrete microaneurysms, intraretinal haemorrhages, or exudates identified.';
else
    if maCount > 0
        lines{end + 1} = sprintf('  - Microaneurysm candidates: %d detected across retinal vasculature.', maCount);
    end
    if heCount > 0
        lines{end + 1} = sprintf('  - Intraretinal haemorrhages: %d detected.', heCount);
    end
    if exCount > 0
        lines{end + 1} = sprintf('  - Hard exudates: %d detected (lipid deposits indicating vascular leakage).', exCount);
    end
    if seCount > 0
        lines{end + 1} = sprintf('  - Soft exudates (cotton wool spots): %d detected (nerve fiber layer ischemia).', seCount);
    end
end

% Macular Proximity Risk
if isfield(lesionResult.hardExudates, 'distancesToFovea') && ~isempty(lesionResult.hardExudates.distancesToFovea)
    minDistFovea = min(lesionResult.hardExudates.distancesToFovea);
    if isfield(anatomyResult, 'opticDiscRadius') && isfinite(anatomyResult.opticDiscRadius)
        discDiam = 2 * anatomyResult.opticDiscRadius;
        fovealDiscDistance = minDistFovea / discDiam;
        if fovealDiscDistance <= 1.0
            lines{end + 1} = sprintf('  ! High Macular Risk: Hard exudates detected within 1.0 disc diameter of the fovea (%.1f DD).', fovealDiscDistance);
        elseif fovealDiscDistance <= 2.0
            lines{end + 1} = sprintf('  * Exudate proximity: Hard exudates within 2.0 disc diameters of the fovea (%.1f DD).', fovealDiscDistance);
        end
    end
end

% Vascular context
if isfield(anatomyResult, 'vesselDensity') && isfinite(anatomyResult.vesselDensity)
    lines{end + 1} = sprintf('  - Retinal vascular area density: %.1f%% across illuminated field of view.', ...
        anatomyResult.vesselDensity * 100);
end

lines{end + 1} = '';

% Safety and Clinical Action Recommendation
lines{end + 1} = 'Clinical Decision Support:';
switch safetyResult.safetyStatus
    case 'SAFE_FOR_AI_ASSISTED_RESULT'
        if drResult.referable
            lines{end + 1} = '  - ACTION: Refer patient to district ophthalmologist for dilated slit-lamp fundus biomicroscopy.';
        else
            lines{end + 1} = '  - ACTION: Low-risk screening result. Recommend routine annual diabetic eye review at PHC.';
        end
    case 'HUMAN_REVIEW_REQUIRED'
        lines{end + 1} = '  - ACTION: Human clinician review required before releasing results.';
        if ~isempty(safetyResult.reasonCodes)
            lines{end + 1} = sprintf('    Flagged reasons: %s.', strjoin(safetyResult.reasonCodes, ', '));
        end
    case 'RECAPTURE_REQUIRED'
        lines{end + 1} = '  - ACTION: Image quality ungradable. Please perform recapture following operator guidance.';
end

lines{end + 1} = '';
lines{end + 1} = 'DISCLAIMER: DrishtiSetu is an investigational screening aid, not an autonomous diagnostic device. All referable and ambiguous cases must be evaluated by a certified eye care practitioner.';

narrative = strjoin(lines, newline);
end
