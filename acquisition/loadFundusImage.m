function [image, imagePath, metadata] = loadFundusImage(imageSource)
%LOADFUNDUSIMAGE Robust multi-format loader for fundus photography.
%   [IMAGE, IMAGEPATH, METADATA] = loadFundusImage(IMAGESOURCE) loads an image
%   from a file path or accepts an already-loaded image array.

imagePath = '';
metadata = struct('format', 'unknown', 'fileSize', 0, 'width', 0, 'height', 0);

if ischar(imageSource) || (isstring(imageSource) && isscalar(imageSource))
    filePath = char(imageSource);
    
    % Check existence
    if ~isfile(filePath)
        error('acquisition:FileNotFound', 'Fundus image file does not exist: %s', filePath);
    end
    
    % Check for sealed paths
    normPath = lower(strrep(filePath, '\', '/'));
    if contains(normPath, '/data/sealed')
        error('acquisition:SealedDataAccess', 'Access to sealed evaluation data is strictly forbidden.');
    end
    
    try
        [rawImg, map] = imread(filePath);
        if ~isempty(map)
            rawImg = ind2rgb(rawImg, map);
        end
    catch ME
        error('acquisition:UnreadableFile', 'Failed to read image file: %s (%s)', filePath, ME.message);
    end
    
    fileInfo = dir(filePath);
    if ~isempty(fileInfo)
        metadata.fileSize = fileInfo.bytes;
    end
    [~, ~, ext] = fileparts(filePath);
    metadata.format = ext;
    imagePath = filePath;
else
    rawImg = imageSource;
    metadata.format = 'memory-array';
end

[isValid, errMsg, image] = validateFundusImage(rawImg);
if ~isValid
    error('acquisition:InvalidImage', 'Fundus image validation failed: %s', errMsg);
end

metadata.height = size(image, 1);
metadata.width = size(image, 2);
metadata.channels = size(image, 3);
end
