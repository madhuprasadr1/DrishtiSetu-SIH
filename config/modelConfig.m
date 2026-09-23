function cfg = modelConfig()
%MODELCONFIG Configuration of deep learning models, checkpoints, and inference parameters.
%   CFG = modelConfig() returns deep learning specifications for DR grading,
%   lesion segmentation, and vessel segmentation.

cfg = struct();

% DR 5-Level Grading Model
cfg.grading = struct();
cfg.grading.backbone = 'resnet50';
cfg.grading.inputSize = [448, 448, 3];
cfg.grading.numClasses = 5;
cfg.grading.classes = {'No DR (Level 0)', 'Mild NPDR (Level 1)', ...
    'Moderate NPDR (Level 2)', 'Severe NPDR (Level 3)', 'Proliferative DR (Level 4)'};
candGrad = fullfile('models', 'grading', 'drishtisetu_dr_resnet50.mat');
if ~isfile(candGrad) && isfile(fullfile('models', 'dr_grading_resnet50.mat'))
    candGrad = fullfile('models', 'dr_grading_resnet50.mat');
end
cfg.grading.checkpoint = candGrad;
cfg.grading.temperature = 2.1414;
cfg.grading.dropout = 0.5;

% Lesion Segmentation & Detection
cfg.lesions = struct();
cfg.lesions.lesionTypes = {'MA', 'HE', 'EX', 'SE'};
cfg.lesions.lesionNames = {'Microaneurysms', 'Haemorrhages', 'Hard Exudates', 'Soft Exudates'};
cfg.lesions.patchSize = 512;
candLesion = fullfile('models', 'lesions', 'drishtisetu_lesion_unet.mat');
if ~isfile(candLesion) && isfile(fullfile('models', 'lesion_unet_multihead.mat'))
    candLesion = fullfile('models', 'lesion_unet_multihead.mat');
end
cfg.lesions.checkpoint = candLesion;
cfg.lesions.evidenceThresholds = struct('MA', 0.05, 'HE', 0.99, 'EX', 0.99, 'SE', 0.99);
cfg.lesions.minimumArea = struct('MA', 4, 'HE', 20, 'EX', 10, 'SE', 50);

% Vessel Segmentation
cfg.vessels = struct();
cfg.vessels.patchSize = 128;
candVessel = fullfile('models', 'anatomy', 'drishtisetu_vessel_unet.mat');
if ~isfile(candVessel) && isfile(fullfile('models', 'vessel_unet.mat'))
    candVessel = fullfile('models', 'vessel_unet.mat');
end
cfg.vessels.checkpoint = candVessel;
cfg.vessels.operatingThreshold = 0.50;
cfg.vessels.tileOverlap = 32;

% Execution environment ("auto", "gpu", or "cpu")
cfg.environment = "auto";
end
