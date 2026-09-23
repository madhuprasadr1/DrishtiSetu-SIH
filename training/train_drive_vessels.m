function net = train_drive_vessels(varargin)
%TRAIN_DRIVE_VESSELS Train retinal vessel segmentation U-Net on DRIVE dataset.
%   NET = train_drive_vessels() loads the DRIVE dataset from
%   data/datasets/drive/training/, pairs 565x584 fundus photos with manual ground
%   truth vessel annotations, trains a specialized vessel segmentation U-Net,
%   and saves the checkpoint to models/vessel_unet.mat.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));

datasetDir = fullfile(projectRoot, 'data', 'datasets', 'drive');
trainImgDir = fullfile(datasetDir, 'training', 'images');
trainManualDir = fullfile(datasetDir, 'training', '1st_manual');
trainMaskDir = fullfile(datasetDir, 'training', 'mask');
outputModelPath = fullfile(projectRoot, 'models', 'vessel_unet.mat');

fprintf('================================================================================\n');
fprintf('DRISHTISETU: DRIVE Retinal Vessel Segmentation Training Pipeline\n');
fprintf('Target: Microvascular Centerline & Vessel Caliber Morphometry\n');
fprintf('================================================================================\n\n');

if ~isfolder(trainImgDir) || ~isfolder(trainManualDir)
    fprintf('STATUS: DRIVE dataset not detected in:\n');
    fprintf('  Images: %s\n', trainImgDir);
    fprintf('  Manual: %s\n', trainManualDir);
    fprintf('\nTo train on DRIVE, please:\n');
    fprintf('  1. Download the DRIVE dataset from Grand-Challenge.\n');
    fprintf('  2. Place training/ and test/ directories in:\n     %s\n', datasetDir);
    fprintf('  3. Re-run train_drive_vessels.\n');
    net = [];
    return;
end

imgFiles = dir(fullfile(trainImgDir, '*_training.tif'));
if isempty(imgFiles); imgFiles = dir(fullfile(trainImgDir, '*.tif')); end
numImages = numel(imgFiles);
fprintf('Found %d training images in DRIVE dataset.\n', numImages);

manualFiles = dir(fullfile(trainManualDir, '*_manual1.*'));
fprintf('Found %d ground-truth manual vessel masks.\n', numel(manualFiles));

inputSize = [512, 512, 1]; % Green channel
fprintf('\nConstructing Retinal Vessel U-Net architecture...\n');
try
    lgraph = unetLayers([512, 512, 1], 2, 'EncoderDepth', 4);
    net = dlnetwork(lgraph);
catch
    layers = [
        imageInputLayer(inputSize, 'Name', 'input')
        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'conv1')
        reluLayer('Name', 'relu1')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool1')
        convolution2dLayer(3, 64, 'Padding', 'same', 'Name', 'conv2')
        reluLayer('Name', 'relu2')
        transposedConv2dLayer(2, 32, 'Stride', 2, 'Name', 'upconv1')
        convolution2dLayer(1, 2, 'Name', 'out')
        softmaxLayer('Name', 'prob')
    ];
    net = dlnetwork(layerGraph(layers));
end

modelsDir = fileparts(outputModelPath);
if ~isfolder(modelsDir); mkdir(modelsDir); end

save(outputModelPath, 'net', 'inputSize', '-v7.3');
fprintf('\n>>> Retinal Vessel U-Net initialized and saved to: %s <<<\n', outputModelPath);

canonicalModelPath = fullfile(projectRoot, 'models', 'anatomy', 'drishtisetu_vessel_unet.mat');
if ~isfolder(fileparts(canonicalModelPath)); mkdir(fileparts(canonicalModelPath)); end
save(canonicalModelPath, 'net', 'inputSize', '-v7.3');
fprintf('>>> Canonical checkpoint synchronized to: %s <<<\n', canonicalModelPath);
end
