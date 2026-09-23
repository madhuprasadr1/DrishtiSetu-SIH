function result = decisionPolicy(input, varargin)
%DECISIONPOLICY Conservative 3-way DR screening triage policy for rural PHCs.
%   RESULT = decisionPolicy(INPUT, CONFIG) or
%   RESULT = decisionPolicy(pReferable, uncertainty, ruleGrade, isOOD, config)

if nargin < 1 || isempty(input)
    input = struct();
end

if ~isstruct(input)
    % Positional call: decisionPolicy(pReferable, uncertainty, ruleGrade, isOOD, config)
    pReferable = double(input);
    uncertainty = 0.0;
    if numel(varargin) >= 1 && ~isempty(varargin{1}); uncertainty = double(varargin{1}); end
    ruleGrade = 0;
    if numel(varargin) >= 2 && ~isempty(varargin{2}); ruleGrade = double(varargin{2}); end
    isOOD = false;
    if numel(varargin) >= 3 && ~isempty(varargin{3}); isOOD = logical(varargin{3}); end
    if numel(varargin) >= 4 && ~isempty(varargin{4})
        config = varargin{4};
    else
        config = projectConfig();
    end

    inputStruct = struct();
    inputStruct.calibratedReferableProbability = pReferable;
    inputStruct.predictedLevel = ruleGrade;
    inputStruct.uncertaintyScore = uncertainty;
    inputStruct.isOOD = isOOD;
    inputStruct.quality = struct('qualityClass', 'GOOD');
    input = inputStruct;
else
    if numel(varargin) >= 1 && ~isempty(varargin{1})
        config = varargin{1};
    else
        config = projectConfig();
    end
end
policy = config.decision_policy;

reasonCodes = {};
warnings = {};
decision = 'escalate'; % Default conservative stance
decisionReason = '';

% 1. Quality Check
qualityClass = 'GOOD';
if isfield(input, 'quality') && isfield(input.quality, 'qualityClass')
    qualityClass = upper(char(input.quality.qualityClass));
elseif isfield(input, 'quality') && isfield(input.quality, 'class')
    qualityClass = upper(char(input.quality.class));
end

if strcmp(qualityClass, 'BAD') || strcmp(qualityClass, 'UNGRADABLE')
    reasonCodes{end + 1} = 'quality-ungradable';
    decision = 'escalate';
    decisionReason = 'Image quality is ungradable; patient must be recaptured.';
    result = localBuildResult(decision, decisionReason, reasonCodes, warnings, 'quality gate stopped');
    return;
elseif strcmp(qualityClass, 'BORDERLINE')
    isEnhanced = false;
    if isfield(input.quality, 'isEnhanced'); isEnhanced = input.quality.isEnhanced; end
    if ~isEnhanced
        reasonCodes{end + 1} = 'borderline-quality-unresolved';
    end
end

% 2. Extraction of AI Model Prediction & Uncertainty
calibratedProb = 0.0;
predictedLevel = 0;
uncertaintyScore = 0.0;

if isfield(input, 'calibratedReferableProbability')
    calibratedProb = input.calibratedReferableProbability;
end
if isfield(input, 'predictedLevel')
    predictedLevel = input.predictedLevel;
end
if isfield(input, 'uncertaintyScore')
    uncertaintyScore = input.uncertaintyScore;
end

if isfield(input, 'dr')
    if isfield(input.dr, 'calibratedReferableProbability')
        calibratedProb = input.dr.calibratedReferableProbability;
    end
    if isfield(input.dr, 'drGrade')
        predictedLevel = input.dr.drGrade;
    end
elseif isfield(input, 'cnn')
    if isfield(input.cnn, 'calibratedReferableProbability')
        calibratedProb = input.cnn.calibratedReferableProbability;
    end
    if isfield(input.cnn, 'predictedLevel')
        predictedLevel = input.cnn.predictedLevel;
    end
end

if isfield(input, 'safety') && isfield(input.safety, 'uncertaintyScore')
    uncertaintyScore = input.safety.uncertaintyScore;
end

% Check OOD
isOOD = false;
if isfield(input, 'isOOD'); isOOD = input.isOOD; end
if isfield(input, 'ood') && isfield(input.ood, 'isOOD'); isOOD = input.ood.isOOD; end
if isfield(input, 'safety') && isfield(input.safety, 'oodFlag'); isOOD = input.safety.oodFlag; end
if isOOD
    reasonCodes{end + 1} = 'out-of-distribution';
    warnings{end + 1} = 'Out-of-distribution anomaly detected.';
end

% 3. Extraction of Clinical Rule Evidence
ruleLevel = 0;
if isfield(input, 'ruleGrade')
    ruleLevel = input.ruleGrade;
elseif isfield(input, 'predictedLevel')
    ruleLevel = input.predictedLevel;
end
if isfield(input, 'ruleEngine')
    if isfield(input.ruleEngine, 'level'); ruleLevel = input.ruleEngine.level; end
    if isfield(input.ruleEngine, 'referable'); ruleReferable = input.ruleEngine.referable; end
elseif isfield(input, 'icdrRuleResult')
    if isfield(input.icdrRuleResult, 'level'); ruleLevel = input.icdrRuleResult.level; end
    if isfield(input.icdrRuleResult, 'referable'); ruleReferable = input.icdrRuleResult.referable; end
end
ruleReferable = ruleLevel >= 2;

% 4. Escalation Flags
if policy.alwaysEscalateLevel4 && (predictedLevel == 4 || ruleLevel == 4)
    reasonCodes{end + 1} = 'proliferative-dr-requires-human-review';
end

if uncertaintyScore > policy.uncertaintyThreshold
    reasonCodes{end + 1} = 'high-predictive-uncertainty';
end

% Spatial or Evidence Agreement
agreementStatus = 'concordant';
if (calibratedProb >= policy.referableThreshold) && (ruleLevel == 0)
    agreementStatus = 'CNN referable but evidence unsupported';
    reasonCodes{end + 1} = 'cnn-referable-evidence-unsupported';
elseif (calibratedProb <= policy.autoClearThreshold) && ruleReferable
    agreementStatus = 'evidence referable but CNN non-referable';
    reasonCodes{end + 1} = 'evidence-referable-cnn-nonreferable';
end

% 5. Decision Resolution
if ~isempty(reasonCodes)
    decision = 'escalate';
    decisionReason = sprintf('Human review required: %s.', strjoin(reasonCodes, ', '));
elseif calibratedProb >= policy.referableThreshold
    decision = 'refer';
    decisionReason = sprintf('Referable DR detected (calibrated risk: %.1f%%). Prompt ophthalmic referral advised.', ...
        calibratedProb * 100);
elseif calibratedProb <= policy.autoClearThreshold
    if policy.requireEvidenceForAutoClear && ruleReferable
        decision = 'escalate';
        decisionReason = 'Model suggested non-referable but lesion evidence detected referable pathology.';
        reasonCodes{end + 1} = 'conflicting-lesion-evidence';
    else
        decision = 'auto-clear';
        decisionReason = sprintf('Non-referable DR confirmed (calibrated risk: %.1f%%). Routine annual follow-up.', ...
            calibratedProb * 100);
    end
else
    decision = 'escalate';
    decisionReason = sprintf('Borderline calibrated risk (%.1f%%) in intermediate zone [%.1f%%, %.1f%%].', ...
        calibratedProb * 100, policy.autoClearThreshold * 100, policy.referableThreshold * 100);
    reasonCodes{end + 1} = 'intermediate-risk-uncertainty';
end

result = localBuildResult(decision, decisionReason, reasonCodes, warnings, agreementStatus);
end

function res = localBuildResult(decision, reason, codes, warnings, agreement)
res = struct();
switch lower(decision)
    case 'auto-clear'
        normDec = 'AUTO_CLEAR';
    case 'refer'
        normDec = 'REFER';
    case {'escalate', 'escalate_human_review'}
        normDec = 'ESCALATE_HUMAN_REVIEW';
    otherwise
        normDec = upper(strrep(decision, '-', '_'));
end
res.decision = normDec;
res.action = normDec;
res.rawDecision = decision;
res.decisionReason = reason;
res.reasonCodes = codes;
res.warnings = warnings;
res.agreementStatus = agreement;
res.explanation = reason;
end
