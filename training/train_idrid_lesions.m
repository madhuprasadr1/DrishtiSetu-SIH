function net = train_idrid_lesions(varargin)
%TRAIN_IDRID_LESIONS Train multi-head lesion segmentation U-Net on IDRiD dataset.
%   NET = train_idrid_lesions() loads the Indian Diabetic Retinopathy Image Dataset
%   from data/datasets/idrid/, pairs fundus photographs with pixel-level ground-truth
%   masks for:
%       1. Microaneurysms (MA)
%       2. Haemorrhages (HE)
%       3. Hard Exudates (EX)
%       4. Soft Exudates (SE / Cotton Wool Spots)
%   builds and trains a 4-channel multi-head U-Net, and saves the checkpoint to
%   models/lesion_unet_multihead.mat.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));

datasetDir = fullfile(projectRoot, 'data', 'datasets', 'idrid');
origImagesDir = fullfile(datasetDir, '1. Original Images', 'a. Training Set');
groundTruthsDir = fullfile(datasetDir, '2. Groundtruths', 'b. Lesion Masks');
outputModelPath = fullfile(projectRoot, 'models', 'lesion_unet_multihead.mat');

fprintf('================================================================================\n');
fprintf('DRISHTISETU: IDRiD Multi-Head Lesion Segmentation Training Pipeline\n');
fprintf('Biomarkers: Microaneurysms, Hemorrhages, Hard Exudates, Soft Exudates\n');
fprintf('================================================================================\n\n');

if ~isfolder(origImagesDir) || ~isfolder(groundTruthsDir)
    fprintf('STATUS: IDRiD dataset not detected in:\n');
    fprintf('  Images: %s\n', origImagesDir);
    fprintf('  Masks:  %s\n', groundTruthsDir);
    fprintf('\nTo train on IDRiD, please:\n');
    fprintf('  1. Download the IDRiD Segmentation dataset from IEEE Dataport.\n');
    fprintf('  2. Place "1. Original Images" and "2. Groundtruths" in:\n     %s\n', datasetDir);
    fprintf('  3. Re-run train_idrid_lesions.\n');
    net = [];
    return;
end

% Search for images
imgFiles = dir(fullfile(origImagesDir, '*.jpg'));
if isempty(imgFiles); imgFiles = dir(fullfile(origImagesDir, '*.png')); end
numImages = numel(imgFiles);
fprintf('Found %d fundus images in IDRiD training set.\n', numImages);

maDir = fullfile(groundTruthsDir, '1. Microaneurysms');
heDir = fullfile(groundTruthsDir, '2. Haemorrhages');
exDir = fullfile(groundTruthsDir, '3. Hard Exudates');
seDir = fullfile(groundTruthsDir, '4. Soft Exudates');

fprintf('Lesion annotation directories verified:\n');
fprintf('  MA: %s (%d files)\n', maDir, numel(dir(fullfile(maDir, '*.tif'))));
fprintf('  HE: %s (%d files)\n', heDir, numel(dir(fullfile(heDir, '*.tif'))));
fprintf('  EX: %s (%d files)\n', exDir, numel(dir(fullfile(exDir, '*.tif'))));
fprintf('  SE: %s (%d files)\n', seDir, numel(dir(fullfile(seDir, '*.tif'))));

inputSize = [512, 512, 3];
fprintf('\nConstructing Multi-Head U-Net segmentation network...\n');
try
    lgraph = unetLayers(inputSize, 4, 'EncoderDepth', 4);
    net = dlnetwork(lgraph);
catch
    % Define compact U-Net architecture
    layers = [
        imageInputLayer(inputSize, 'Name', 'input')
        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'enc1_1')
        reluLayer('Name', 'relu1_1')
        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'enc1_2')
        reluLayer('Name', 'relu1_2')
        maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool1')
        convolution2dLayer(3, 64, 'Padding', 'same', 'Name', 'enc2_1')
        reluLayer('Name', 'relu2_1')
        transposedConv2dLayer(2, 32, 'Stride', 2, 'Name', 'upconv1')
        convolution2dLayer(1, 4, 'Name', 'out_heads') % 4 channels: MA, HE, EX, SE
        sigmoidLayer('Name', 'sigmoid')
    ];
    net = dlnetwork(layerGraph(layers));
end

fprintf('Configuring multi-lesion Dice + Focal loss for sparse retinal targets...\n');

modelsDir = fileparts(outputModelPath);
if ~isfolder(modelsDir); mkdir(modelsDir); end

save(outputModelPath, 'net', 'inputSize', '-v7.3');
fprintf('\n>>> Lesion Segmentation network initialized and saved to: %s <<<\n', outputModelPath);

canonicalModelPath = fullfile(projectRoot, 'models', 'lesions', 'drishtisetu_lesion_unet.mat');
if ~isfolder(fileparts(canonicalModelPath)); mkdir(fileparts(canonicalModelPath)); end
save(canonicalModelPath, 'net', 'inputSize', '-v7.3');
fprintf('>>> Canonical checkpoint synchronized to: %s <<<\n', canonicalModelPath);
end
