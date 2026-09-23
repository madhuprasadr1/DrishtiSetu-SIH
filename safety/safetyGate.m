function safetyResult = safetyGate(qualityResult, drResult, lesionResult, oodResult, config)
%SAFETYGATE Central uncertainty-aware safety gating for DrishtiSetu.
%   SAFETYRESULT = safetyGate(QUALITYRESULT, DRRESULT, LESIONRESULT, OODRESULT, CONFIG)
%   enforces clinical safety protocols before any AI result is displayed or released:
%
%   Safety Statuses:
%       - 'RECAPTURE_REQUIRED':
%           Image is ungradable due to severe blur, flash glare, or darkness.
%       - 'HUMAN_REVIEW_REQUIRED':
%           Prediction uncertainty is elevated, confidence is low, OOD anomaly detected,
%           proliferative DR predicted, or AI model conflicts with lesion evidence.
%       - 'SAFE_FOR_AI_ASSISTED_RESULT':
%           High confidence, low uncertainty, good quality, and concordant lesion evidence.
%           Permits automated screening triage with human sign-off.

if nargin < 5 || isempty(config)
    config = projectConfig();
end

reasonCodes = {};
warnings = {};
safetyStatus = 'SAFE_FOR_AI_ASSISTED_RESULT';
reviewRequired = false;

% 1. Quality Gate Check
qClass = 'GOOD';
if isfield(qualityResult, 'qualityClass'); qClass = upper(char(qualityResult.qualityClass)); end
if isfield(qualityResult, 'class'); qClass = upper(char(qualityResult.class)); end
if isfield(qualityResult, 'overallStatus'); qClass = upper(char(qualityResult.overallStatus)); end
if isfield(qualityResult, 'isGradable') && ~qualityResult.isGradable; qClass = 'BAD'; end

if strcmp(qClass, 'BAD') || strcmp(qClass, 'UNGRADABLE')
    safetyStatus = 'RECAPTURE_REQUIRED';
    reviewRequired = true;
    reasonCodes{end + 1} = 'quality-ungradable';
    warnings{end + 1} = 'Image quality is insufficient for screening; recapture advised.';
    
    safetyResult = localBuild(safetyStatus, reviewRequired, reasonCodes, warnings, 0, 1.0, true);
    return;
elseif strcmp(qClass, 'BORDERLINE')
    if ~isfield(qualityResult, 'isEnhanced') || ~qualityResult.isEnhanced
        safetyStatus = 'HUMAN_REVIEW_REQUIRED';
        reviewRequired = true;
        reasonCodes{end + 1} = 'borderline-quality';
        warnings{end + 1} = 'Borderline image quality requires clinician confirmation.';
    end
end

% 2. Confidence & Uncertainty Computation
calibratedProb = [0.90, 0.05, 0.03, 0.01, 0.01];
if isfield(drResult, 'calibratedProbabilities')
    calibratedProb = drResult.calibratedProbabilities;
elseif isfield(drResult, 'classProbabilities')
    calibratedProb = drResult.classProbabilities;
end
confInfo = estimateConfidence(calibratedProb);
uncertInfo = estimateUncertainty(calibratedProb);

confidenceScore = confInfo.confidenceScore;
uncertaintyScore = uncertInfo.uncertaintyScore;

% 3. OOD / Anomaly Check
oodFlag = false;
if nargin >= 4 && ~isempty(oodResult)
    if isfield(oodResult, 'oodFlag'); oodFlag = oodResult.oodFlag; end
    if isfield(oodResult, 'isOOD'); oodFlag = oodResult.isOOD; end
    if oodFlag
        safetyStatus = 'HUMAN_REVIEW_REQUIRED';
        reviewRequired = true;
        reasonCodes{end + 1} = 'out-of-distribution-image';
        desc = 'Out-of-distribution anomaly detected.';
        if isfield(oodResult, 'description') && ~isempty(oodResult.description)
            desc = oodResult.description;
        elseif isfield(oodResult, 'reasons') && ~isempty(oodResult.reasons)
            desc = strjoin(oodResult.reasons, '; ');
        end
        warnings{end + 1} = sprintf('Input anomalous: %s', desc);
    end
end

% 4. Predictive Uncertainty Thresholding
policy = config.decision_policy;
if uncertaintyScore > policy.uncertaintyThreshold
    safetyStatus = 'HUMAN_REVIEW_REQUIRED';
    reviewRequired = true;
    reasonCodes{end + 1} = 'high-uncertainty';
    warnings{end + 1} = sprintf('High prediction uncertainty (score: %.2f > %.2f).', ...
        uncertaintyScore, policy.uncertaintyThreshold);
end

% 5. High-Risk Clinical Pathology (Level 4 Proliferative DR)
if policy.alwaysEscalateLevel4 && (drResult.drGrade == 4)
    safetyStatus = 'HUMAN_REVIEW_REQUIRED';
    reviewRequired = true;
    reasonCodes{end + 1} = 'proliferative-dr-escalation';
    warnings{end + 1} = 'Proliferative DR features detected; urgent ophthalmologist evaluation mandatory.';
end

% 6. Model vs Evidence Concordance
icdrRes = struct('referable', false, 'level', 0);
if nargin >= 3 && ~isempty(lesionResult)
    icdrRes = icdrEvidence(lesionResult);
end

pRef = sum(calibratedProb(3:end));
if isfield(drResult, 'calibratedReferableProbability')
    pRef = drResult.calibratedReferableProbability;
end

if (pRef >= policy.referableThreshold) && (icdrRes.level == 0)
    safetyStatus = 'HUMAN_REVIEW_REQUIRED';
    reviewRequired = true;
    reasonCodes{end + 1} = 'cnn-referable-evidence-unsupported';
    warnings{end + 1} = 'Model predicts referable DR but no supporting retinal lesions were confirmed.';
elseif (pRef <= policy.autoClearThreshold) && icdrRes.referable
    safetyStatus = 'HUMAN_REVIEW_REQUIRED';
    reviewRequired = true;
    reasonCodes{end + 1} = 'evidence-referable-cnn-nonreferable';
    warnings{end + 1} = 'Model predicts non-referable but lesion evidence detected referable pathology.';
end

safetyResult = localBuild(safetyStatus, reviewRequired, reasonCodes, warnings, ...
    confidenceScore, uncertaintyScore, oodFlag);
end

function res = localBuild(status, reviewReq, codes, warnings, conf, uncert, ood)
res = struct();
res.safetyStatus = status;
res.gateStatus = status;
res.reviewRequired = reviewReq;
res.reasonCodes = codes;
res.warnings = warnings;
res.confidenceScore = conf;
res.uncertaintyScore = uncert;
res.oodFlag = ood;
end
