function [qualityClass, diagnostics] = classifyQuality(features, config, fovInfo)
%CLASSIFYQUALITY Rule-based quality gate classifying captures as GOOD, BORDERLINE, or BAD.
%   [QUALITYCLASS, DIAGNOSTICS] = classifyQuality(FEATURES, CONFIG, FOVINFO)
%   evaluates sharpness, illumination, exposure, field-of-view, and contrast.
%   Severe failures cause ungradable/BAD; lesser failures cause borderline.

if nargin < 2 || isempty(config)
    config = projectConfig();
end
if isfield(config, 'quality') && isstruct(config.quality)
    config = config.quality;
end
if nargin < 3
    fovInfo = struct();
end

hardFailures = {};
borderlineFailures = {};

% 1. Field of View coverage
if ~isfield(features, 'fovAreaRatio') || ~isfinite(features.fovAreaRatio)
    hardFailures{end + 1} = 'field of view not detected';
elseif features.fovAreaRatio < config.minimumFovAreaRatio
    hardFailures{end + 1} = 'field of view is severely small / cut off';
elseif features.fovAreaRatio < config.fovAreaBorderline
    borderlineFailures{end + 1} = 'field of view coverage is suboptimal';
end

% 2. Focus and Sharpness
laplacian = localGet(features, 'varianceOfLaplacian', NaN);
tenengrad = localGet(features, 'tenengrad', NaN);
meanIntensity = localGet(features, 'meanIntensity', NaN);
focusScale = max(meanIntensity ^ 2, 0.01);
normalizedLaplacian = laplacian / focusScale;
normalizedTenengrad = tenengrad / focusScale;

focusUsable = isfinite(meanIntensity) && meanIntensity >= config.meanDarkBorderline;
if ~isfinite(laplacian) || ~isfinite(tenengrad) || ~isfinite(meanIntensity)
    hardFailures{end + 1} = 'focus is severely low / ungradable';
elseif focusUsable && (normalizedLaplacian < config.laplacianUngradable || ...
        normalizedTenengrad < config.tenengradUngradable)
    hardFailures{end + 1} = 'focus is severely blurred';
elseif focusUsable && (normalizedLaplacian < config.laplacianBorderline || ...
        normalizedTenengrad < config.tenengradBorderline)
    borderlineFailures{end + 1} = 'focus is soft / borderline';
end

% 3. Under-exposure (Darkness)
darkFraction = localGet(features, 'darkPixelFraction', NaN);
if ~isfinite(meanIntensity) || ~isfinite(darkFraction) || ...
        meanIntensity < config.meanDarkUngradable || darkFraction >= config.darkFractionUngradable
    hardFailures{end + 1} = 'exposure is severely dark';
elseif meanIntensity < config.meanDarkBorderline || darkFraction >= config.darkFractionBorderline
    borderlineFailures{end + 1} = 'exposure is under-illuminated / dark';
end

% 4. Over-exposure (Saturation)
saturatedFraction = localGet(features, 'saturatedPixelFraction', NaN);
if ~isfinite(saturatedFraction) || saturatedFraction >= config.saturatedFractionUngradable
    hardFailures{end + 1} = 'exposure is severely saturated / flash glare';
elseif saturatedFraction >= config.saturatedFractionBorderline
    borderlineFailures{end + 1} = 'exposure is partially over-bright';
end

% 5. Contrast and Texture
rmsContrast = localGet(features, 'rmsContrast', NaN);
entropyValue = localGet(features, 'entropy', NaN);
if ~isfinite(rmsContrast) || ~isfinite(entropyValue) || ...
        (rmsContrast < config.rmsContrastUngradable && entropyValue < config.entropyUngradable)
    hardFailures{end + 1} = 'contrast and entropy are severely washed out';
elseif rmsContrast < config.rmsContrastBorderline || entropyValue < config.entropyBorderline
    borderlineFailures{end + 1} = 'contrast or retinal detail is low';
end

% 6. Uneven illumination
illumination = localGet(features, 'quadrantIlluminationVariation', NaN);
if ~isfinite(illumination) || illumination >= config.illuminationCvUngradable
    hardFailures{end + 1} = 'illumination is highly uneven (shadow/crescent)';
elseif illumination >= config.illuminationCvBorderline
    borderlineFailures{end + 1} = 'illumination is somewhat uneven';
end

% 7. Camera Centering
if isfield(fovInfo, 'centerOffset') && isfinite(fovInfo.centerOffset) && ...
        fovInfo.centerOffset > config.centerOffsetLimit
    borderlineFailures{end + 1} = 'retina is off-centre';
end

% Triage Decision
if ~isempty(hardFailures)
    qualityClass = 'BAD';
elseif ~isempty(borderlineFailures)
    qualityClass = 'BORDERLINE';
else
    qualityClass = 'GOOD';
end

% Overall Quality Score [0, 100]
baseScore = 100;
baseScore = baseScore - 40 * numel(hardFailures) - 15 * numel(borderlineFailures);
qualityScore = max(0, min(100, baseScore));

diagnostics = struct();
diagnostics.qualityClass = qualityClass;
diagnostics.qualityScore = qualityScore;
diagnostics.hardFailures = hardFailures;
diagnostics.borderlineFailures = borderlineFailures;
diagnostics.failureReasons = [hardFailures, borderlineFailures];
diagnostics.normalizedLaplacian = normalizedLaplacian;
diagnostics.normalizedTenengrad = normalizedTenengrad;
end

function val = localGet(features, field, defaultVal)
if isfield(features, field)
    val = double(features.(field));
else
    val = defaultVal;
end
end
