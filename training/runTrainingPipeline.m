function status = runTrainingPipeline(datasetName)
%RUNTRAININGPIPELINE Master launcher for DrishtiSetu deep learning training.
%   status = runTrainingPipeline() inspects data/datasets/ for the 5 datasets:
%       1. APTOS 2019   (5-Level DR Severity Grading)
%       2. IDRiD        (Multi-Head Lesion Segmentation: MA, HE, EX, SE)
%       3. DRIVE        (Retinal Vessel Segmentation)
%       4. Messidor-2   (Clinical DR Severity & Macular Edema)
%       5. OCTA-500     (Microvascular Density & FAZ Segmentation)
%
%   status = runTrainingPipeline('aptos') trains on APTOS 2019.
%   status = runTrainingPipeline('idrid') trains on IDRiD.
%   status = runTrainingPipeline('drive') trains on DRIVE.
%   status = runTrainingPipeline('messidor') trains on Messidor-2.
%   status = runTrainingPipeline('octa') trains on OCTA-500.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));

baseDataDir = fullfile(projectRoot, 'data', 'datasets');

datasets = { ...
    'APTOS 2019', 'aptos2019', '5-Level DR Classification', 'models/dr_grading_resnet50.mat', @train_aptos_grading; ...
    'IDRiD', 'idrid', 'Multi-Head Lesion Segmentation', 'models/lesion_unet_multihead.mat', @train_idrid_lesions; ...
    'DRIVE', 'drive', 'Retinal Vessel U-Net', 'models/vessel_unet.mat', @train_drive_vessels; ...
    'Messidor-2', 'messidor2', 'DR & DME Risk Grading', 'models/dr_grading_messidor.mat', @train_messidor2_grading; ...
    'OCTA-500', 'octa500', 'Angiography Microvasculature', 'models/octa_microvascular_net.mat', @train_octa500_vessels ...
};

fprintf('================================================================================\n');
fprintf('DRISHTISETU: Master Deep Learning Training & Dataset Manager\n');
fprintf('Datasets Path: %s\n', baseDataDir);
fprintf('================================================================================\n\n');

status = struct();

fprintf('%-15s | %-12s | %-32s | %-12s\n', 'Dataset', 'Folder', 'Target Task', 'Status');
fprintf('%s\n', repmat('-', 1, 80));

for i = 1:size(datasets, 1)
    dName = datasets{i, 1};
    dFolder = datasets{i, 2};
    dTask = datasets{i, 3};
    targetModel = datasets{i, 4};
    
    fullPath = fullfile(baseDataDir, dFolder);
    isReady = false;
    
    switch dFolder
        case 'aptos2019'
            isReady = isfile(fullfile(fullPath, 'train.csv')) && isfolder(fullfile(fullPath, 'train_images'));
        case 'idrid'
            isReady = isfolder(fullfile(fullPath, '1. Original Images')) && isfolder(fullfile(fullPath, '2. Groundtruths'));
        case 'drive'
            isReady = isfolder(fullfile(fullPath, 'training', 'images')) && isfolder(fullfile(fullPath, 'training', '1st_manual'));
        case 'messidor2'
            isReady = isfolder(fullfile(fullPath, 'images')) && isfile(fullfile(fullPath, 'messidor_data.csv'));
        case 'octa500'
            isReady = isfolder(fullfile(fullPath, 'OCTA_6mm')) || isfolder(fullfile(fullPath, 'OCTA_3mm'));
    end
    
    statusStr = 'NOT LOADED';
    if isReady
        statusStr = 'READY';
    end
    
    fprintf('%-15s | %-12s | %-32s | %-12s\n', dName, dFolder, dTask, statusStr);
    status.(dFolder) = isReady;
end

fprintf('%s\n\n', repmat('-', 1, 80));

if nargin > 0 && ~isempty(datasetName)
    targetKey = lower(char(datasetName));
    matched = false;
    for i = 1:size(datasets, 1)
        if contains(datasets{i, 2}, targetKey) || contains(lower(datasets{i, 1}), targetKey)
            fprintf('Launching training for %s...\n', datasets{i, 1});
            trainFunc = datasets{i, 5};
            trainFunc();
            matched = true;
            break;
        end
    end
    if ~matched
        warning('training:UnknownDataset', 'Unknown dataset "%s". Choose from: aptos, idrid, drive, messidor, octa.', datasetName);
    end
else
    fprintf('Instructions:\n');
    fprintf('  1. Place your dataset files in their respective folders under: data/datasets/\n');
    fprintf('     (See docs/dataset_setup_and_training.md for detailed structure)\n');
    fprintf('  2. To start training on a specific dataset, run:\n');
    fprintf('       runTrainingPipeline(''aptos'')\n');
    fprintf('       runTrainingPipeline(''idrid'')\n');
    fprintf('       runTrainingPipeline(''drive'')\n');
    fprintf('       runTrainingPipeline(''messidor'')\n');
    fprintf('       runTrainingPipeline(''octa'')\n\n');
end
end
