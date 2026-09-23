function reviewCase = createReviewCase(screeningResult)
%CREATEREVIEWCASE Package screening result for clinician audit and review.
%   REVIEWCASE = createReviewCase(SCREENINGRESULT) gathers images, model predictions,
%   calibrated uncertainty, and evidence maps for presentation in the review queue.

if nargin < 1 || isempty(screeningResult)
    error('review:MissingResult', 'A screening result structure is required.');
end

reviewCase = struct();
reviewCase.caseID = screeningResult.caseID;
reviewCase.patientPseudoID = screeningResult.patient.pseudoID;
reviewCase.eye = screeningResult.eye;
reviewCase.timestamp = screeningResult.acquisition.timestamp;
reviewCase.qualityClass = screeningResult.quality.qualityClass;
reviewCase.drGrade = screeningResult.dr.drGrade;
reviewCase.drLabel = screeningResult.dr.drLabel;
reviewCase.referable = screeningResult.dr.referable;
reviewCase.calibratedReferableRisk = screeningResult.dr.calibratedReferableProbability;
reviewCase.confidenceScore = screeningResult.safety.confidenceScore;
reviewCase.uncertaintyScore = screeningResult.safety.uncertaintyScore;
reviewCase.safetyStatus = screeningResult.safety.safetyStatus;
reviewCase.status = 'PENDING';

% Image attachments
reviewCase.originalImage = screeningResult.acquisition.originalImage;
reviewCase.processedImage = screeningResult.preprocessing.processedImage;
reviewCase.gradCAMOverlay = screeningResult.explainability.gradCAMOverlay;
reviewCase.lesionOverlay = screeningResult.explainability.lesionMapOverlay;
reviewCase.vesselOverlay = screeningResult.explainability.vesselMapOverlay;
end
