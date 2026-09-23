function [isValid, message, normalizedImage] = validateFundusImage(imageInput)
%VALIDATEFUNDUSIMAGE Validate input image array or filepath for fundus screening.
%   [ISVALID, MESSAGE, NORMALIZEDIMAGE] = validateFundusImage(IMAGEINPUT)
%   checks that the input is a valid 2D or 3D numeric/logical matrix, non-empty,
%   real-valued, and converts grayscale to 3-channel RGB if needed.

isValid = false;
message = '';
normalizedImage = [];

if isempty(imageInput)
    message = 'Fundus image input is empty.';
    return;
end

if ~(isnumeric(imageInput) || islogical(imageInput))
    message = 'Fundus image must be a numeric or logical array.';
    return;
end

if ~isreal(imageInput)
    message = 'Fundus image must contain real values (complex numbers detected).';
    return;
end

dims = size(imageInput);
if numel(dims) < 2 || numel(dims) > 3
    message = sprintf('Invalid image dimensions (%d dimensions). Expected 2D or 3D array.', numel(dims));
    return;
end

if dims(1) < 64 || dims(2) < 64
    message = sprintf('Image resolution too low (%dx%d). Minimum supported is 64x64.', dims(1), dims(2));
    return;
end

% Convert to single/double [0, 1] range if needed or keep uint8
img = imageInput;
if islogical(img)
    img = uint8(img) * 255;
elseif isfloat(img)
    if max(img(:)) <= 1.0
        img = uint8(round(img * 255));
    else
        img = uint8(round(img));
    end
else
    img = uint8(img);
end

% Check channels
if size(img, 3) == 1
    % Grayscale: replicate to 3 channels
    normalizedImage = repmat(img, 1, 1, 3);
elseif size(img, 3) == 3
    normalizedImage = img;
else
    message = sprintf('Unsupported number of color channels: %d. Expected 1 or 3 channels.', size(img, 3));
    return;
end

isValid = true;
message = 'Image validation successful.';
end
