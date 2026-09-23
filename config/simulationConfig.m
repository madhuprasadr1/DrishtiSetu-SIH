function cfg = simulationConfig()
%SIMULATIONCONFIG Configuration parameters for PHC / District workflow simulation.
%   CFG = simulationConfig() loads the district simulation parameters,
%   clearly distinguishing measured from assumed parameters.

cfg = struct();
cfg.annualScreeningVolume = 100000;
cfg.simulationDurationDays = 365;
cfg.numberOfPHCs = 10;
cfg.arrivalMode = "smooth";
cfg.arrivalRate = cfg.annualScreeningVolume / (cfg.simulationDurationDays * 86400);
cfg.campBurstMultiplier = 5;
cfg.captureTimeSeconds = 90;
cfg.qualityGateTimeSeconds = 2;
cfg.qualityRejectionRate = 0.21;
cfg.maximumRecaptureAttempts = 2;
cfg.inferenceTimeSeconds = 0.715; % Measured on validation set
cfg.imageSizeMegabytes = 8;
cfg.bandwidthMegabitsPerSecond = 10;
cfg.connectivityAvailability = 0.70;
cfg.uploadRetryIntervalSeconds = 3600;
cfg.numberOfGraders = 2;
cfg.graderServiceTimeSeconds = 30;
cfg.modelSensitivity = 0.96;
cfg.modelSpecificity = 0.9167;
cfg.deferralRate = 0.10;
cfg.turnaroundTargetHours = 24;
cfg.randomSeed = 42;
cfg.referablePrevalence = 0.10;
cfg.connectivityCycleSeconds = 86400;
cfg.failedCaptureRouting = "escalate";
cfg.qualityGateEnabled = true;

% Parameter metadata (Assumed vs Measured)
cfg.parameterMetadata = struct();
cfg.parameterMetadata.annualScreeningVolume = struct('assumed', false, 'source', 'District health target');
cfg.parameterMetadata.simulationDurationDays = struct('assumed', false, 'source', 'Annual planning horizon');
cfg.parameterMetadata.numberOfPHCs = struct('assumed', true, 'source', 'District scenario assumption');
cfg.parameterMetadata.inferenceTimeSeconds = struct('assumed', false, 'source', 'Empirically measured benchmark');
cfg.parameterMetadata.modelSensitivity = struct('assumed', false, 'source', 'Empirical internal validation');
cfg.parameterMetadata.qualityRejectionRate = struct('assumed', true, 'source', 'Published field screening literature');
end
