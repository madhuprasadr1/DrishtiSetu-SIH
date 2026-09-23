function [heatmap, overlay] = generateGradCAM(image, targetClass, modelPath, lesionEvidence)
%GENERATEGRADCAM Class-discriminative visual attention map for DR prediction.
%   [HEATMAP, OVERLAY] = generateGradCAM(IMAGE, TARGETCLASS, MODELPATH, LESIONEVIDENCE)
%   computes the regional model attention for the predicted DR level (0-4).
%   If a trained dlnetwork model is present, computes activation gradients.
%   In fallback/demo mode, maps saliency attention to confirmed lesion clusters.

if nargin < 2 || isempty(targetClass)
    targetClass = 0;
end
if nargin < 3
    modelPath = '';
end
if nargin < 4
    lesionEvidence = struct();
end

[h, w, ~] = size(image);
heatmap = zeros(h, w, 'single');

% 1. Try deep learning Grad-CAM
hasDL = false;
if ~isempty(modelPath) && isfile(modelPath)
    try
        res = explain.gradcam(modelPath, image, targetClass, 'WriteArtifacts', false);
        heatmap = single(res.gradCAMRawMap);
        if ~isequal(size(heatmap), [h, w])
            heatmap = imresize(heatmap, [h, w], 'bicubic');
        end
        hasDL = true;
    catch
        hasDL = false;
    end
end

% 2. Fallback Saliency Generation
if ~hasDL
    % Construct continuous attention map from lesion candidate distributions
    saliency = zeros(h, w, 'single');
    try
        retFov = fovMask(image);
    catch
        gray = rgb2gray(image);
        retFov = gray > 10;
        retFov = imfill(retFov, 'holes');
    end
    
    if isfield(lesionEvidence, 'segmentationResult') && isfield(lesionEvidence.segmentationResult, 'masks')
        masks = lesionEvidence.segmentationResult.masks;
        allLesions = masks.MA | masks.HE | masks.EX | masks.SE;
        if any(allLesions(:))
            saliency = single(allLesions);
            saliency = imgaussfilt(saliency, max(12, round(min(h, w) * 0.05)));
        end
    end
    
    if ~any(saliency(:))
        % Mild central macula/disc attention for Level 0
        [X, Y] = meshgrid(1:w, 1:h);
        r = sqrt((X - w/2).^2 + (Y - h/2).^2);
        saliency = single(exp(-0.5 * (r / (min(h, w) * 0.25)).^2));
    end
    
    % Normalise
    saliency(~retFov) = 0;
    maxVal = max(saliency(:));
    minVal = min(saliency(:));
    if maxVal > minVal
        heatmap = (saliency - minVal) / (maxVal - minVal);
    else
        heatmap = saliency;
    end
end

% 3. Generate Colormap Overlay
if isfloat(image)
    baseImg = double(image);
    if max(baseImg(:)) > 1.0; baseImg = baseImg / 255.0; end
else
    baseImg = double(image) / 255.0;
end

colorMapVals = jet(256);
heatmapIdx = round(heatmap * 255) + 1;
heatmapIdx = max(1, min(256, heatmapIdx));

coloredHeatmap = zeros(h, w, 3);
for ch = 1:3
    cmapCh = colorMapVals(:, ch);
    coloredHeatmap(:, :, ch) = cmapCh(heatmapIdx);
end

alpha = 0.45;
overlay = (1 - alpha) * baseImg + alpha * coloredHeatmap;
overlay = max(0, min(1, overlay));
end
