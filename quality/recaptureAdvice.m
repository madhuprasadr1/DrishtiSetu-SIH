function [advice, details] = recaptureAdvice(varargin)
%RECAPTUREADVICE Translate quality failures into clear guidance for PHC health worker.
%   [ADVICE, DETAILS] = recaptureAdvice(FEATURES)
%   [ADVICE, DETAILS] = recaptureAdvice(IMAGE, FEATURES, FOVINFO, CONFIG)
%   returns actionable guidance: adjust focus, ask patient to blink, adjust pupil
%   alignment, increase flash illumination, or wait for pharmacologic dilation.

[image, features, fovInfo, config] = localParseArgs(varargin{:});

advice = {};
details = struct('dominantFailure', '', 'boundaryBrightFraction', NaN, 'reasons', {{}});

if ~isstruct(features)
    error('quality:InvalidFeatures', 'Features must be a scalar feature struct.');
end

meanIntensity = localGet(features, 'meanIntensity', NaN);
focusScale = max(meanIntensity ^ 2, 0.01);
normalizedLaplacian = localGet(features, 'varianceOfLaplacian', Inf) / focusScale;
normalizedTenengrad = localGet(features, 'tenengrad', Inf) / focusScale;

% Focus advice
if isfinite(meanIntensity) && meanIntensity >= config.meanDarkBorderline && ...
        (normalizedLaplacian < config.laplacianBorderline || ...
        normalizedTenengrad < config.tenengradBorderline)
    advice{end + 1} = 'Image out of focus: Retract/advance lens to sharpen retinal vessel edges.';
    details.reasons{end + 1} = 'focus';
end

% Under-exposure
if localGet(features, 'meanIntensity', Inf) < config.meanDarkBorderline || ...
        localGet(features, 'darkPixelFraction', 0) >= config.darkFractionBorderline
    advice{end + 1} = 'Image too dark: Increase camera flash intensity or allow patient pupil to dilate.';
    details.reasons{end + 1} = 'dark exposure';
end

% Over-exposure
if localGet(features, 'saturatedPixelFraction', 0) >= config.saturatedFractionBorderline
    advice{end + 1} = 'Image over-exposed (flash glare): Decrease flash exposure or illumination intensity to avoid washing out macular detail.';
    details.reasons{end + 1} = 'saturated exposure';
end

% Illumination unevenness
if localGet(features, 'quadrantIlluminationVariation', 0) >= config.illuminationCvBorderline
    advice{end + 1} = 'Uneven lighting / Crescent shadow: Center the camera objective with the pupil axis.';
    details.reasons{end + 1} = 'quadrant illumination';
end

% Off-center FOV
offCentre = false;
if isfield(fovInfo, 'centerOffset') && isfinite(fovInfo.centerOffset)
    offCentre = fovInfo.centerOffset > config.centerOffsetLimit;
elseif localGet(features, 'fovAreaRatio', 0) < config.fovAreaBorderline
    offCentre = true;
end
if offCentre
    advice{end + 1} = 'Field of view not centred: Re-align fundus camera fixation target with macula/disc.';
    details.reasons{end + 1} = 'FOV position';
end

% Eyelash / lens artifact
if ~isempty(image) && isfield(fovInfo, 'mask') && any(fovInfo.mask(:))
    unitImage = localToUnit(image);
    gray = localGray(unitImage);
    ring = fovInfo.mask & ~imerode(fovInfo.mask, strel('disk', 1, 0));
    if any(ring(:))
        details.boundaryBrightFraction = mean(gray(ring) >= 0.92);
        if details.boundaryBrightFraction >= 0.25 && ...
                localGet(features, 'saturatedPixelFraction', 0) < 0.5
            advice{end + 1} = 'Lens flare or eyelash artifact: Ask patient to open eyes wide; clean lens surface.';
            details.reasons{end + 1} = 'bright boundary artifact';
        end
    end
end

if ~isempty(advice)
    details.dominantFailure = advice{1};
else
    details.dominantFailure = 'Image quality acceptable.';
end
end

function [image, features, fovInfo, config] = localParseArgs(varargin)
image = [];
features = [];
fovInfo = struct();
cfg = projectConfig();
config = cfg.quality;

if nargin == 1
    features = varargin{1};
elseif nargin >= 2
    image = varargin{1};
    features = varargin{2};
    if nargin >= 3 && ~isempty(varargin{3})
        fovInfo = varargin{3};
    end
    if nargin >= 4 && ~isempty(varargin{4})
        cIn = varargin{4};
        if isfield(cIn, 'quality') && isstruct(cIn.quality)
            config = cIn.quality;
        elseif isstruct(cIn)
            config = cIn;
        end
    end
else
    error('quality:InvalidAdviceArguments', 'Features are required.');
end
end

function val = localGet(features, field, defaultVal)
if isfield(features, field) && isscalar(features.(field))
    val = double(features.(field));
else
    val = defaultVal;
end
end

function img = localToUnit(inputImage)
if isfloat(inputImage)
    if max(inputImage(:)) > 1.0; img = double(inputImage) / 255; else; img = double(inputImage); end
else
    img = double(inputImage) / double(intmax(class(inputImage)));
end
img = max(0, min(1, img));
end

function gray = localGray(image)
if size(image, 3) == 1; gray = image(:, :, 1); else; gray = im2gray(image); end
end
