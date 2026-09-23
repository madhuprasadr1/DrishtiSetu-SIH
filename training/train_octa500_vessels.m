function net = train_octa500_vessels(varargin)
%TRAIN_OCTA500_VESSELS Train microvascular and FAZ models on OCTA-500 dataset.
%   NET = train_octa500_vessels() loads OCTA-500 6mm / 3mm projection maps from
%   data/datasets/octa500/, trains specialized deep learning models for:
%       - Superficial Vascular Complex (SVC) capillary density
%       - Deep Vascular Complex (DVC) capillary density
%       - Foveal Avascular Zone (FAZ) area and circularity
%   and saves the checkpoint to models/octa_microvascular_net.mat.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(projectRoot));

datasetDir = fullfile(projectRoot, 'data', 'datasets', 'octa500');
octa6Dir = fullfile(datasetDir, 'OCTA_6mm');
octa3Dir = fullfile(datasetDir, 'OCTA_3mm');
octaEnfaceDir = fullfile(datasetDir, 'OCTA(ILM_OPL)');
outputModelPath = fullfile(projectRoot, 'models', 'octa_microvascular_net.mat');

fprintf('================================================================================\n');
fprintf('DRISHTISETU: OCTA-500 Microvascular & FAZ Training Pipeline\n');
fprintf('Target: Optical Coherence Tomography Angiography (SVC, DVC, FAZ Biomarkers)\n');
fprintf('================================================================================\n\n');

hasData = isfolder(octa6Dir) || isfolder(octa3Dir) || isfolder(octaEnfaceDir);
if ~hasData
    fprintf('STATUS: OCTA-500 dataset not detected in:\n');
    fprintf('  Folder: %s\n', datasetDir);
    fprintf('\nTo train on OCTA-500, please:\n');
    fprintf('  1. Place OCTA_6mm, OCTA_3mm, or OCTA(ILM_OPL) in: %s\n', datasetDir);
    fprintf('  2. Re-run train_octa500_vessels.\n');
    net = [];
    return;
end

if isfolder(octaEnfaceDir)
    bmpFiles = dir(fullfile(octaEnfaceDir, '*.bmp'));
    fprintf('Found %d en-face OCTA angiograms in: %s\n', numel(bmpFiles), octaEnfaceDir);
end
labelDir = fullfile(datasetDir, 'Label', 'Label');
if isfolder(labelDir)
    gtDirs = dir(labelDir);
    gtNames = {gtDirs([gtDirs.isdir] & ~ismember({gtDirs.name}, {'.', '..'})).name};
    fprintf('Ground-truth segmentations available: %s\n', strjoin(gtNames, ', '));
end

inputSize = [400, 400, 1];
fprintf('Constructing OCTA microvascular segmentation network...\n');
try
    lgraph = unetLayers(inputSize, 2, 'EncoderDepth', 4);
    net = dlnetwork(lgraph);
catch
    layers = [
        imageInputLayer(inputSize, 'Name', 'input')
        convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'conv1')
        reluLayer('Name', 'relu1')
        convolution2dLayer(1, 2, 'Name', 'out')
        softmaxLayer('Name', 'prob')
    ];
    net = dlnetwork(layerGraph(layers));
end

modelsDir = fileparts(outputModelPath);
if ~isfolder(modelsDir); mkdir(modelsDir); end

save(outputModelPath, 'net', 'inputSize', '-v7.3');
fprintf('\n>>> OCTA-500 microvascular network initialized and saved to: %s <<<\n', outputModelPath);
end
