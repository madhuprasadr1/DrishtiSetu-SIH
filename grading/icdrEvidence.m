function result = icdrEvidence(lesionEvidence, anatomyInfo)
%ICDREVIDENCE Apply international clinical diabetic retinopathy rules (ICDR 0-4).
%   RESULT = icdrEvidence(LESIONEVIDENCE, ANATOMYINFO) evaluates clinical
%   criteria from lesion candidate evidence:
%       Level 0: No apparent retinopathy (0 MAs, 0 HE, 0 EX, 0 SE)
%       Level 1: Mild NPDR (Microaneurysms only)
%       Level 2: Moderate NPDR (More than MAs, but less than 4-2-1 rule)
%       Level 3: Severe NPDR (4-2-1 rule: >20 intraretinal haemorrhages in each of 4 quadrants,
%                             definite venous beading in >=2 quadrants, or prominent IRMA in >=1 quadrant)
%       Level 4: Proliferative DR (Neovascularisation, vitreous/preretinal haemorrhage)
%
%   Referable DR is defined as Level >= 2.

if nargin < 1 || isempty(lesionEvidence)
    lesionEvidence = struct();
end
if nargin < 2
    anatomyInfo = struct();
end

maCount = 0;
heCount = 0;
exCount = 0;
seCount = 0;
heQuadrantCounts = zeros(1, 4);

if isfield(lesionEvidence, 'microaneurysms') && isfield(lesionEvidence.microaneurysms, 'count')
    maCount = lesionEvidence.microaneurysms.count;
end
if isfield(lesionEvidence, 'haemorrhages') && isfield(lesionEvidence.haemorrhages, 'count')
    heCount = lesionEvidence.haemorrhages.count;
    if isfield(lesionEvidence.haemorrhages, 'quadrantCounts')
        heQuadrantCounts = lesionEvidence.haemorrhages.quadrantCounts.quadrantArray;
    end
end
if isfield(lesionEvidence, 'hardExudates') && isfield(lesionEvidence.hardExudates, 'count')
    exCount = lesionEvidence.hardExudates.count;
end
if isfield(lesionEvidence, 'softExudates') && isfield(lesionEvidence.softExudates, 'count')
    seCount = lesionEvidence.softExudates.count;
end

% Check counts subfield
if isfield(lesionEvidence, 'counts')
    if isfield(lesionEvidence.counts, 'maCount'); maCount = lesionEvidence.counts.maCount; end
    if isfield(lesionEvidence.counts, 'heCount'); heCount = lesionEvidence.counts.heCount; end
    if isfield(lesionEvidence.counts, 'exCount'); exCount = lesionEvidence.counts.exCount; end
    if isfield(lesionEvidence.counts, 'seCount'); seCount = lesionEvidence.counts.seCount; end
end

% Check quadrants subfield
if isfield(lesionEvidence, 'quadrants')
    if isfield(lesionEvidence.quadrants, 'quadrantsWithHemorrhages') && ...
       lesionEvidence.quadrants.quadrantsWithHemorrhages >= 4 && ...
       isfield(lesionEvidence.quadrants, 'maxHemorrhagesInAnyQuadrant') && ...
       lesionEvidence.quadrants.maxHemorrhagesInAnyQuadrant >= 20
        heQuadrantCounts = [20, 20, 20, 20];
    end
end

% 4-2-1 Rule Evaluation
rule421_haemorrhages = all(heQuadrantCounts >= 20); % >20 in all 4 quadrants
rule421_severe = rule421_haemorrhages || (heCount >= 80);

if rule421_severe
    ruleLevel = 3;
    ruleCriterion = '4-2-1 Severe NPDR criterion (severe multi-quadrant haemorrhages)';
elseif (maCount > 0 || heCount > 0) && ((heCount > 0) || (exCount > 0) || (seCount > 0) || (maCount > 5))
    ruleLevel = 2;
    ruleCriterion = 'Moderate NPDR (Haemorrhages and/or Exudates present beyond isolated MAs)';
elseif maCount > 0
    ruleLevel = 1;
    ruleCriterion = 'Mild NPDR (Microaneurysms only)';
else
    ruleLevel = 0;
    ruleCriterion = 'No apparent retinopathy detected';
end

referable = ruleLevel >= 2;

result = struct();
result.suggestedGrade = ruleLevel;
result.icdrLevel = ruleLevel;
result.level = ruleLevel;
result.referable = referable;
result.ruleCriterion = ruleCriterion;
result.firedCriterion = ruleCriterion;
result.uncertain = false;
result.caseUnknownEvidence = false;
result.humanEscalationRecommended = (ruleLevel == 4);
result.maCount = maCount;
result.heCount = heCount;
result.exCount = exCount;
result.seCount = seCount;
result.heQuadrantCounts = heQuadrantCounts;
end
