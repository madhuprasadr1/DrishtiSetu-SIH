function cfg = projectConfig()
%PROJECTCONFIG Operational and clinical screening configuration for DrishtiSetu.
%   CFG = projectConfig() returns calibrated default settings for quality gating,
%   decision policy, clinical screening thresholds, and reporting.

cfg = struct();

% Project positioning and metadata
cfg.projectName = 'DrishtiSetu';
cfg.tagline = 'Explainable AI for Diabetic Retinopathy Screening in Rural India';
cfg.version = '1.0.0-MVP';
cfg.offlineMode = true;

% Quality Engine Thresholds (Calibrated for unit [0, 1] double images)
cfg.quality = struct();
cfg.quality.fovThreshold = 0.05;
cfg.quality.minimumFovAreaRatio = 0.15;
cfg.quality.fovAreaBorderline = 0.30;
cfg.quality.centerOffsetLimit = 0.35;
cfg.quality.darkPixelThreshold = 0.05;
cfg.quality.saturationThreshold = 0.98;
cfg.quality.illuminationSigma = 15;
cfg.quality.laplacianUngradable = 3.5e-4;
cfg.quality.laplacianBorderline = 2.0e-3;
cfg.quality.tenengradUngradable = 5.0e-4;
cfg.quality.tenengradBorderline = 2.0e-3;
cfg.quality.meanDarkUngradable = 0.06;
cfg.quality.meanDarkBorderline = 0.14;
cfg.quality.darkFractionUngradable = 0.90;
cfg.quality.darkFractionBorderline = 0.55;
cfg.quality.saturatedFractionUngradable = 0.25;
cfg.quality.saturatedFractionBorderline = 0.05;
cfg.quality.rmsContrastUngradable = 0.01;
cfg.quality.rmsContrastBorderline = 0.025;
cfg.quality.entropyUngradable = 1.5;
cfg.quality.entropyBorderline = 2.5;
cfg.quality.illuminationCvUngradable = 0.45;
cfg.quality.illuminationCvBorderline = 0.25;
cfg.quality.denoiseDegree = 0.005;
cfg.quality.enhancementEnabled = true;
cfg.quality.claheEnabled = true;
cfg.quality.preserveOriginalQuality = true;

% Preprocessing Settings
cfg.preprocessing = struct();
cfg.preprocessing.targetSize = [448, 448];
cfg.preprocessing.channel_mean = [0, 0, 0];
cfg.preprocessing.channel_std = [1/255, 1/255, 1/255];
cfg.preprocessing.claheClip = 0.01;
cfg.preprocessing.claheGrid = [8, 8];

% Decision Policy & Referral Thresholds
cfg.decision_policy = struct();
cfg.decision_policy.autoClearThreshold = 0.40;   % Calibrated P(referable) <= 0.40 -> potential auto-clear
cfg.decision_policy.referableThreshold = 0.70;   % Calibrated P(referable) >= 0.70 -> urgent referral
cfg.decision_policy.uncertaintyThreshold = 0.50; % Normalized entropy > 0.50 -> human review
cfg.decision_policy.requireEvidenceForAutoClear = true;
cfg.decision_policy.alwaysEscalateLevel4 = true;
cfg.decision_policy.escalateOnUnknownEvidence = true;
cfg.decision_policy.escalateOnExplanationDisagreement = true;
cfg.decision_policy.escalateOnCapabilityGap = false;
cfg.decision_policy.spatialAttentionCut = 0.35;
cfg.decision_policy.spatialAgreementFraction = 0.25;

% Target Clinical Acceptance Criteria
cfg.clinical_targets = struct();
cfg.clinical_targets.referableSensitivityTarget = 0.90;
cfg.clinical_targets.specificityTarget = 0.85;
cfg.clinical_targets.disclaimer = 'Clinical prototype for research and decision support only; not certified for autonomous diagnosis.';

% Storage & Database Settings
cfg.database = struct();
cfg.database.fileName = 'drishtisetu_screenings.db';
cfg.database.fallbackFileName = 'drishtisetu_db.mat';
cfg.database.auditLogFileName = 'drishtisetu_audit.log';

% Operating Point Reference
cfg.operating_point = struct();
cfg.operating_point.temperature = 2.1414;
cfg.operating_point.frozen_date = '2026-08-23';
cfg.operating_point.referable_threshold = 0.40;
end
