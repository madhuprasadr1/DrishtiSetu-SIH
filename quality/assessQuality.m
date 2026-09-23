function [qualityResult, processedImage] = assessQuality(image, config)
%ASSESSQUALITY Primary Quality Engine entry point for DrishtiSetu.
%   [QUALITYRESULT, PROCESSEDIMAGE] = assessQuality(IMAGE, CONFIG) assesses
%   sharpness, illumination, exposure, field of view, and artifacts.

if nargin < 2 || isempty(config)
    config = projectConfig();
end

[fovMaskImg, fovInfo] = fovMask(image, config);
fovInfo.mask = fovMaskImg;

features = qualityFeatures(image, fovMaskImg, config);
rawFeatures = features;
[qualityClass, diagnostics] = classifyQuality(features, config, fovInfo);

processedImage = image;
isEnhanced = false;

% Borderline enhancement loop
if strcmp(qualityClass, 'BORDERLINE') && config.quality.enhancementEnabled
    enhancedCandidate = enhanceBorderline(image, fovMaskImg, config);
    % Reassess enhanced image
    enhancedFeatures = qualityFeatures(enhancedCandidate, fovMaskImg, config);
    [reassessedClass, reassessedDiag] = classifyQuality(enhancedFeatures, config, fovInfo);
    
    if strcmp(reassessedClass, 'GOOD') || strcmp(reassessedClass, 'BORDERLINE')
        processedImage = enhancedCandidate;
        isEnhanced = true;
        diagnostics = reassessedDiag;
        features = enhancedFeatures;
    end
end

% Recapture guidance
if strcmp(qualityClass, 'GOOD')
    advice = {};
    adviceDetails = struct('dominantFailure', 'Image quality is good for screening.', ...
        'reasons', {{}});
elseif isEnhanced && strcmp(reassessedClass, 'GOOD')
    advice = {};
    adviceDetails = struct('dominantFailure', 'Borderline quality successfully restored by enhancement.', ...
        'reasons', {{}});
else
    [advice, adviceDetails] = recaptureAdvice(image, rawFeatures, fovInfo, config);
end

qualityResult = struct();
qualityResult.qualityClass = qualityClass;
qualityResult.class = lower(qualityClass);
if strcmp(qualityClass, 'GOOD')
    qualityResult.class = 'gradable';
elseif strcmp(qualityClass, 'BAD')
    qualityResult.class = 'ungradable';
end

qualityResult.qualityScore = diagnostics.qualityScore;
qualityResult.failureReasons = diagnostics.failureReasons;
qualityResult.hardFailures = diagnostics.hardFailures;
qualityResult.borderlineFailures = diagnostics.borderlineFailures;
qualityResult.recaptureAdvice = advice;
qualityResult.advice = advice;
qualityResult.adviceDetails = adviceDetails;
qualityResult.features = features;
qualityResult.fovMask = fovMaskImg;
qualityResult.fovInfo = fovInfo;
qualityResult.isEnhanced = isEnhanced;
qualityResult.enhancementApplied = isEnhanced;
qualityResult.wasEnhanced = isEnhanced;
qualityResult.isGradable = strcmp(qualityClass, 'GOOD') || strcmp(qualityClass, 'BORDERLINE');
qualityResult.overallStatus = qualityClass;
qualityResult.overallScore = diagnostics.qualityScore / 100.0;
qualityResult.operatorAdvice = advice;
qualityResult.classifierDiagnostics = diagnostics;
end
