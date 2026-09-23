function overlay = generateVesselMap(image, vesselMask, vesselSkeleton)
%GENERATEVESSELMAP Retinal vascular tree and skeleton visualization.
%   OVERLAY = generateVesselMap(IMAGE, VESSELMASK, VESSELSKELETON) highlights
%   the segmented vasculature in vibrant green and centerline skeleton in yellow
%   over a contrast-enhanced fundus background.

[h, w, ~] = size(image);
if isfloat(image)
    base = double(image);
    if max(base(:)) > 1.0; base = base / 255.0; end
else
    base = double(image) / 255.0;
end

% CLAHE on luminance for dark vascular contrast
gray = 0.2989 * base(:, :, 1) + 0.5870 * base(:, :, 2) + 0.1140 * base(:, :, 3);
if min(size(gray)) >= 16
    grayEnh = adapthisteq(gray, 'NumTiles', [8, 8], 'ClipLimit', 0.02);
else
    grayEnh = gray;
end

overlay = repmat(grayEnh * 0.7, 1, 1, 3);

% Highlight vessel mask in bright emerald green [0.1, 0.9, 0.3]
vMask = logical(vesselMask);
overlay(repmat(vMask, 1, 1, 3)) = 0; % Clear
overlay(:, :, 1) = overlay(:, :, 1) + 0.1 * double(vMask);
overlay(:, :, 2) = overlay(:, :, 2) + 0.9 * double(vMask);
overlay(:, :, 3) = overlay(:, :, 3) + 0.3 * double(vMask);

% Highlight skeleton in gold [1.0, 0.85, 0.0] if supplied
if nargin >= 3 && ~isempty(vesselSkeleton)
    sMask = logical(vesselSkeleton);
    for ch = 1:3
        channel = overlay(:, :, ch);
        if ch == 1; channel(sMask) = 1.0; end
        if ch == 2; channel(sMask) = 0.85; end
        if ch == 3; channel(sMask) = 0.0; end
        overlay(:, :, ch) = channel;
    end
end

overlay = max(0, min(1, overlay));
end
