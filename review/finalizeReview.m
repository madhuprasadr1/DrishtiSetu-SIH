function updatedResult = finalizeReview(screeningResult, reviewerDecision, reviewerID, clinicianNotes, modifiedGrade)
%FINALIZEREVIEW Record human ophthalmologist review decision and update central result.
%   UPDATEDRESULT = finalizeReview(SCREENINGRESULT, DECISION, REVIEWERID, NOTES, MODIFIEDGRADE)
%   enforces human-in-the-loop validation:
%       DECISION       - 'ACCEPT', 'MODIFY', or 'REJECT'
%       REVIEWERID     - Identifier of certifying ophthalmologist
%       NOTES          - Clinical notes or rationale
%       MODIFIEDGRADE  - (Optional) Overridden DR grade [0..4] if DECISION is 'MODIFY'

if nargin < 2 || isempty(reviewerDecision)
    error('review:MissingDecision', 'Review decision (ACCEPT, MODIFY, REJECT) is required.');
end
if nargin < 3 || isempty(reviewerID)
    reviewerID = 'Ophthalmologist-Reviewer-1';
end
if nargin < 4
    clinicianNotes = '';
end
if nargin < 5
    modifiedGrade = NaN;
end

validDecisions = {'ACCEPT', 'MODIFY', 'REJECT'};
decisionUpper = upper(char(reviewerDecision));
if ~ismember(decisionUpper, validDecisions)
    error('review:InvalidDecision', 'Decision must be one of: ACCEPT, MODIFY, REJECT.');
end

updatedResult = screeningResult;

updatedResult.review.status = decisionUpper;
updatedResult.review.reviewerID = char(reviewerID);
updatedResult.review.reviewTimestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
updatedResult.review.clinicianNotes = char(clinicianNotes);
updatedResult.review.originalAIGrade = screeningResult.dr.drGrade;

switch decisionUpper
    case 'ACCEPT'
        updatedResult.review.finalDeterminedGrade = screeningResult.dr.drGrade;
        updatedResult.review.modificationReason = 'Accepted AI recommendation.';
    case 'MODIFY'
        if isnan(modifiedGrade) || modifiedGrade < 0 || modifiedGrade > 4
            error('review:InvalidModifiedGrade', 'A valid DR Grade [0..4] is required when modifying.');
        end
        updatedResult.review.finalDeterminedGrade = double(modifiedGrade);
        updatedResult.review.modificationReason = char(clinicianNotes);
    case 'REJECT'
        updatedResult.review.finalDeterminedGrade = NaN;
        updatedResult.review.modificationReason = char(clinicianNotes);
end

% Save to local audit
saveAudit('REVIEW_FINALIZED', updatedResult.caseID, ...
    sprintf('Decision: %s by %s', decisionUpper, reviewerID));
end
