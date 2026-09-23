function img = generateSampleFundus(condition, imgSize)
%GENERATESAMPLEFUNDUS Procedural fundus image generator for unit tests.
%   IMG = generateSampleFundus(CONDITION, IMGSIZE) generates a controlled
%   fundus image matrix for automated verification and test fixtures.
%   CONDITION: 'normal', 'mild', 'moderate', 'severe', 'borderline', 'blurred', 'dark', 'bright'
%   IMGSIZE: scalar image dimension (default 384)

if nargin < 1 || isempty(condition)
    condition = 'normal';
end
if nargin < 2 || isempty(imgSize)
    imgSize = 384;
end

w = imgSize;
h = imgSize;

% Determine DR severity grade and quality degradation
grade = 0;
qualityLevel = 'GOOD';

condStr = lower(char(condition));
switch condStr
    case 'normal'
        grade = 0;
    case 'mild'
        grade = 1;
    case 'moderate'
        grade = 2;
    case 'severe'
        grade = 3;
    case 'borderline'
        grade = 0;
        qualityLevel = 'BORDERLINE';
    case {'bad', 'blurred', 'ungradable'}
        grade = 0;
        qualityLevel = 'BAD';
    case 'dark'
        grade = 0;
        qualityLevel = 'BORDERLINE';
    otherwise
        grade = 0;
end

[X, Y] = meshgrid(1:w, 1:h);
centerX = w / 2;
centerY = h / 2;
radius = min(h, w) * 0.44;

distFromCenter = sqrt((X - centerX).^2 + (Y - centerY).^2);
fovMask = distFromCenter <= radius;

% 1. Retinal Base Color & Shading (warm orange-red with limb darkening)
radialGrad = max(0, 1.0 - 0.4 * (distFromCenter / radius).^1.8);

redBase = (0.75 + 0.10 * sin(X / 50) .* cos(Y / 50)) .* radialGrad;
greenBase = (0.35 + 0.05 * cos(X / 40) .* sin(Y / 40)) .* radialGrad;
blueBase = (0.08 + 0.02 * sin(X / 60)) .* radialGrad;

% 2. Optic Disc (Nasal side, e.g. x ~ 0.28 * w)
odX = round(centerX - 0.28 * w);
odY = round(centerY - 0.04 * h);
odRadius = round(radius * 0.16);

distOD = sqrt((X - odX).^2 + (Y - odY).^2);
odMask = distOD <= odRadius;
odGrad = max(0, 1.0 - (distOD / odRadius).^2);

% Disc color: bright yellowish-pink
redBase(odMask) = max(redBase(odMask), 0.95 * odGrad(odMask));
greenBase(odMask) = max(greenBase(odMask), 0.82 * odGrad(odMask));
blueBase(odMask) = max(blueBase(odMask), 0.40 * odGrad(odMask));

% 3. Fovea / Macula (Temporal side, e.g. x ~ 0.62 * w)
foveaX = round(centerX + 0.20 * w);
foveaY = round(centerY + 0.02 * h);
foveaRadius = round(radius * 0.14);

distFovea = sqrt((X - foveaX).^2 + (Y - foveaY).^2);
foveaMask = distFovea <= foveaRadius;
foveaDarkening = 1.0 - 0.35 * exp(-0.5 * (distFovea / (foveaRadius * 0.6)).^2);

redBase = redBase .* foveaDarkening;
greenBase = greenBase .* foveaDarkening;
blueBase = blueBase .* foveaDarkening;

% 4. Vascular Arcade (Superior & Inferior arcades emerging from optic disc)
vesselTree = false(h, w);

% Superior arcade
tX = odX + linspace(0, 0.45 * w, 200);
tY_sup = odY - 0.32 * h * (sin(linspace(0, pi * 0.75, 200)).^0.8);
for k = 1:numel(tX)
    xK = max(1, min(w, round(tX(k))));
    yK = max(1, min(h, round(tY_sup(k))));
    thick = max(1, round(4.0 * (1 - k/200)));
    vesselTree(max(1, yK-thick):min(h, yK+thick), max(1, xK-thick):min(w, xK+thick)) = true;
end

% Inferior arcade
tY_inf = odY + 0.32 * h * (sin(linspace(0, pi * 0.75, 200)).^0.8);
for k = 1:numel(tX)
    xK = max(1, min(w, round(tX(k))));
    yK = max(1, min(h, round(tY_inf(k))));
    thick = max(1, round(4.0 * (1 - k/200)));
    vesselTree(max(1, yK-thick):min(h, yK+thick), max(1, xK-thick):min(w, xK+thick)) = true;
end

vesselTree = vesselTree & fovMask;
vesselDarkening = 0.55;
redBase(vesselTree) = redBase(vesselTree) * (1 - vesselDarkening * 0.4);
greenBase(vesselTree) = greenBase(vesselTree) * (1 - vesselDarkening * 0.85);
blueBase(vesselTree) = blueBase(vesselTree) * (1 - vesselDarkening * 0.6);

% 5. Controllable DR Pathology Lesions
rng(100 + grade, 'twister');

numMAs = 0;
numHEs = 0;
numEXs = 0;
numSEs = 0;

switch grade
    case 1 % Mild NPDR: isolated microaneurysms only
        numMAs = 8;
    case 2 % Moderate NPDR: MAs, HEs, and Hard Exudates
        numMAs = 24;
        numHEs = 10;
        numEXs = 18;
    case 3 % Severe NPDR: extensive multi-quadrant HEs, MAs, EXs, SEs
        numMAs = 50;
        numHEs = 40;
        numEXs = 35;
        numSEs = 5;
end

% Draw Microaneurysms (small red dots, radius 2-3 px)
for m = 1:numMAs
    rDist = rand() * radius * 0.75;
    rAng = rand() * 2 * pi;
    mX = max(5, min(w-5, round(centerX + rDist * cos(rAng))));
    mY = max(5, min(h-5, round(centerY + rDist * sin(rAng))));
    if fovMask(mY, mX) && ~odMask(mY, mX)
        yR = max(1, mY-2):min(h, mY+2);
        xR = max(1, mX-2):min(w, mX+2);
        greenBase(yR, xR) = greenBase(yR, xR) * 0.25;
        blueBase(yR, xR) = blueBase(yR, xR) * 0.20;
    end
end

% Draw Haemorrhages (dark reddish blotches, radius 5-10 px)
for hIdx = 1:numHEs
    rDist = (0.2 + 0.6 * rand()) * radius;
    rAng = rand() * 2 * pi;
    hX = max(10, min(w-10, round(centerX + rDist * cos(rAng))));
    hY = max(10, min(h-10, round(centerY + rDist * sin(rAng))));
    if fovMask(hY, hX) && ~odMask(hY, hX)
        hRad = randi([5, 10]);
        [subX, subY] = meshgrid(max(1, hX-hRad):min(w, hX+hRad), max(1, hY-hRad):min(h, hY+hRad));
        blobMask = sqrt((subX - hX).^2 + (subY - hY).^2) <= hRad;
        yR = max(1, hY-hRad):min(h, hY+hRad);
        xR = max(1, hX-hRad):min(w, hX+hRad);
        subG = greenBase(yR, xR); subG(blobMask) = subG(blobMask) * 0.35; greenBase(yR, xR) = subG;
        subR = redBase(yR, xR); subR(blobMask) = subR(blobMask) * 0.70; redBase(yR, xR) = subR;
    end
end

% Draw Hard Exudates (bright yellowish lipid deposits, radius 3-7 px)
for eIdx = 1:numEXs
    rDist = (0.1 + 0.45 * rand()) * radius;
    rAng = (rand() - 0.5) * pi * 0.8;
    eX = max(10, min(w-10, round(foveaX + rDist * cos(rAng))));
    eY = max(10, min(h-10, round(foveaY + rDist * sin(rAng))));
    if fovMask(eY, eX) && ~odMask(eY, eX)
        eRad = randi([3, 7]);
        [subX, subY] = meshgrid(max(1, eX-eRad):min(w, eX+eRad), max(1, eY-eRad):min(h, eY+eRad));
        blobMask = sqrt((subX - eX).^2 + (subY - eY).^2) <= eRad;
        yR = max(1, eY-eRad):min(h, eY+eRad);
        xR = max(1, eX-eRad):min(w, eX+eRad);
        subR = redBase(yR, xR); subR(blobMask) = min(1.0, subR(blobMask) * 1.5 + 0.3); redBase(yR, xR) = subR;
        subG = greenBase(yR, xR); subG(blobMask) = min(1.0, subG(blobMask) * 1.6 + 0.3); greenBase(yR, xR) = subG;
        subB = blueBase(yR, xR); subB(blobMask) = min(1.0, subB(blobMask) * 1.2 + 0.1); blueBase(yR, xR) = subB;
    end
end

% Draw Soft Exudates (Cotton Wool Spots: fluffy pale gray patches, radius 8-15 px)
for sIdx = 1:numSEs
    rDist = (0.2 + 0.5 * rand()) * radius;
    rAng = rand() * 2 * pi;
    sX = max(15, min(w-15, round(centerX + rDist * cos(rAng))));
    sY = max(15, min(h-15, round(centerY + rDist * sin(rAng))));
    if fovMask(sY, sX) && ~odMask(sY, sX)
        sRad = randi([8, 14]);
        [subX, subY] = meshgrid(max(1, sX-sRad):min(w, sX+sRad), max(1, sY-sRad):min(h, sY+sRad));
        fluff = exp(-0.5 * ((subX - sX).^2 + (subY - sY).^2) / (sRad * 0.6)^2);
        yR = max(1, sY-sRad):min(h, sY+sRad);
        xR = max(1, sX-sRad):min(w, sX+sRad);
        redBase(yR, xR) = min(1.0, redBase(yR, xR) + 0.25 * fluff);
        greenBase(yR, xR) = min(1.0, greenBase(yR, xR) + 0.30 * fluff);
        blueBase(yR, xR) = min(1.0, blueBase(yR, xR) + 0.25 * fluff);
    end
end

% Outside FOV is pitch black
redBase(~fovMask) = 0;
greenBase(~fovMask) = 0;
blueBase(~fovMask) = 0;

rgb = cat(3, redBase, greenBase, blueBase);
rgb = max(0, min(1, rgb));

% Apply Quality Degradations if specified
switch upper(qualityLevel)
    case 'BORDERLINE'
        rgb = rgb * 0.70;
        rgb = imgaussfilt(rgb, 1.2);
    case 'BAD'
        rgb = rgb * 0.25;
        rgb = imgaussfilt(rgb, 5.0);
end

img = uint8(round(rgb * 255));
end
