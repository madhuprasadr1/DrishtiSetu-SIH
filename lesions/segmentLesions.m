function result = segmentLesions(image, varargin)
%SEGMENTLESIONS Segment microaneurysms, haemorrhages, hard exudates, and soft exudates.
%   RESULT = segmentLesions(IMAGE, CONFIG, ANATOMYINFO) or
%   RESULT = segmentLesions(IMAGE, MASK, ANATOMYINFO, CONFIG)
%   detects the four classic diabetic retinopathy lesion types.

config = projectConfig();
anatomyInfo = struct();

for k = 1:numel(varargin)
    arg = varargin{k};
    if islogical(arg) && (ismatrix(arg) || ndims(arg) == 2)
        anatomyInfo.retinalMask = arg;
    elseif isstruct(arg)
        if isfield(arg, 'opticDisc') || isfield(arg, 'opticDiscMask') || isfield(arg, 'retinalMask') || isfield(arg, 'vessels') || isfield(arg, 'vesselMask')
            anatomyInfo = arg;
        elseif isfield(arg, 'lesions') || isfield(arg, 'models') || isfield(arg, 'quality') || isfield(arg, 'decision_policy')
            config = arg;
        end
    end
end

[h, w, c] = size(image);

fovMask = [];
if isfield(anatomyInfo, 'retinalMask'); fovMask = anatomyInfo.retinalMask; end
if isempty(fovMask); fovMask = fovMask(image); end

odMask = [];
if isfield(anatomyInfo, 'opticDiscMask'); odMask = anatomyInfo.opticDiscMask;
elseif isfield(anatomyInfo, 'opticDisc') && isfield(anatomyInfo.opticDisc, 'mask'); odMask = anatomyInfo.opticDisc.mask;
end
if isempty(odMask); odMask = false(h, w); end

vesMask = [];
if isfield(anatomyInfo, 'vesselMask'); vesMask = anatomyInfo.vesselMask;
elseif isfield(anatomyInfo, 'vessels') && isfield(anatomyInfo.vessels, 'mask'); vesMask = anatomyInfo.vessels.mask;
end
if isempty(vesMask); vesMask = false(h, w); end

% Check if deep learning model checkpoint is available
hasDL = false;
if isfield(config, 'lesions') && isfield(config.lesions, 'checkpoint')
    modelPath = config.lesions.checkpoint;
    if isfile(modelPath); hasDL = true; end
end

if hasDL
    try
        dlRes = segment.segmentLesions(image, modelPath);
        result = dlRes;
        result.source = 'learned_unet';
        return;
    catch
        % Fall back gracefully to classical candidate segmentation
    end
end

% Classical Multi-Lesion Candidate Engine
if isfloat(image)
    imgD = double(image);
    if max(imgD(:)) > 1.0; imgD = imgD / 255.0; end
else
    imgD = double(image) / 255.0;
end

red = imgD(:, :, 1);
green = imgD(:, :, min(2, c));
blue = imgD(:, :, min(3, c));

% Non-disc, non-boundary working mask
safeMask = imerode(fovMask, strel('disk', 4, 0)) & ~imdilate(odMask, strel('disk', 5, 0));

% --- 1. Microaneurysms (MA) ---
invertedGreen = (1.0 - green) .* safeMask;
maTopHat = invertedGreen - imopen(invertedGreen, strel('disk', 3, 0));
maCand = (maTopHat >= 0.038) & safeMask & ~vesMask;
maCand = bwareaopen(maCand, 3);
maCand = maCand & ~bwareaopen(maCand, 45); % Exclude larger blot hemorrhages
maMask = maCand;
maProb = single(maMask) * 0.85;

% --- 2. Retinal Haemorrhages (HE) ---
heTopHat = invertedGreen - imopen(invertedGreen, strel('disk', 9, 0));
heCand = (heTopHat >= 0.042) & safeMask & ~vesMask;
heCand = bwareaopen(heCand, 15);
heMask = heCand & ~maMask;
heProb = single(heMask) * 0.80;

% --- 3. Hard Exudates (EX) ---
% Yellow/bright waxy deposits: high in both red and green, low in blue
exIntensity = min(red, green);
exBackground = imopen(exIntensity, strel('disk', 15, 0));
exDiff = (exIntensity - exBackground) .* safeMask;
exCand = (exDiff >= 0.045) & (red >= 0.35) & safeMask;
exCand = bwareaopen(exCand, 5);
exMask = exCand;
exProb = single(exMask) * 0.85;

% --- 4. Soft Exudates / Cotton Wool Spots (SE) ---
% Fluffy, pale white-gray patches
seIntensity = (red + green + blue) / 3.0;
seBackground = imopen(seIntensity, strel('disk', 25, 0));
seDiff = (seIntensity - seBackground) .* safeMask;
seCand = (seDiff >= 0.035) & safeMask & ~exMask;
seCand = bwareaopen(seCand, 45); % Larger, fluffy patches
seMask = seCand;
seProb = single(seMask) * 0.65;

% Extract connected components
[maCount, maCentroids, maAreas] = countLesions(maProb, 0.5, 3);
[heCount, heCentroids, heAreas] = countLesions(heProb, 0.5, 20);
[exCount, exCentroids, exAreas] = countLesions(exProb, 0.5, 8);
[seCount, seCentroids, seAreas] = countLesions(seProb, 0.5, 40);

% Package Result
result = struct();
result.source = 'classical_multiscale_morphology';
result.lesionTypes = {'MA', 'HE', 'EX', 'SE'};
result.probabilityMaps = struct('MA', maProb, 'HE', heProb, 'EX', exProb, 'SE', seProb, ...
                                'ma', maProb, 'he', heProb, 'ex', exProb, 'se', seProb);
result.masks = struct('MA', maMask, 'HE', heMask, 'EX', exMask, 'SE', seMask, ...
                      'ma', maMask, 'he', heMask, 'ex', exMask, 'se', seMask);
result.ma = maMask;
result.he = heMask;
result.ex = exMask;
result.se = seMask;

result.counts = struct('MA', maCount, 'HE', heCount, 'EX', exCount, 'SE', seCount, ...
                       'maCount', maCount, 'heCount', heCount, 'exCount', exCount, 'seCount', seCount, ...
                       'totalCount', maCount + heCount + exCount + seCount);
result.centroids = struct('MA', maCentroids, 'HE', heCentroids, 'EX', exCentroids, 'SE', seCentroids);
result.areas = struct('MA', maAreas, 'HE', heAreas, 'EX', exAreas, 'SE', seAreas);
end
