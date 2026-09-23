function octaData = loadOCTAData(caseOrPath, varargin)
%LOADOCTAData Load en-face OCTA angiogram and microvascular ground truths.
%   OCTADATA = loadOCTAData(CASEORPATH) loads OCTA-500 angiogram images,
%   foveal avascular zone (FAZ) masks, artery/vein ground truths, and
%   structural layers for cross-modal 3D validation and prior learning.
%
%   Part of Module M13: Advanced Estimated 3D Retinal Visualization.

if nargin < 1 || isempty(caseOrPath)
    caseOrPath = '10001'; % Default sample case
end

% Resolve root directory for OCTA-500
baseOCTAPath = fullfile('data', 'datasets', 'octa500');
if ~isfolder(baseOCTAPath)
    % Look in parent or alternative locations
    altPath = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'datasets', 'octa500');
    if isfolder(altPath)
        baseOCTAPath = altPath;
    end
end

octaData = struct( ...
    'caseID', '', ...
    'angiogramILM_OPL', [], ...
    'fazMask', [], ...
    'capillaryMask', [], ...
    'arteryMask', [], ...
    'veinMask', [], ...
    'source', 'NOT_FOUND', ...
    'metadata', struct());

if ischar(caseOrPath) || isstring(caseOrPath)
    caseStr = char(caseOrPath);
    [~, nameOnly, extOnly] = fileparts(caseStr);
    if ~isempty(extOnly) && isfile(caseStr)
        % Direct file path provided
        try
            img = imread(caseStr);
            if size(img, 3) == 1
                octaData.angiogramILM_OPL = repmat(img, 1, 1, 3);
            else
                octaData.angiogramILM_OPL = img;
            end
            octaData.caseID = nameOnly;
            octaData.source = caseStr;
        catch ME
            warning('octa:LoadFailed', 'Could not read OCTA image: %s', ME.message);
        end
        return;
    else
        % Subject ID specified (e.g. '10001')
        idStr = nameOnly;
    end
else
    idStr = sprintf('%05d', caseOrPath);
end

octaData.caseID = idStr;

% Locate En-Face Angiogram (ILM to OPL superficial vascular plexus)
ilmOplDir = fullfile(baseOCTAPath, 'OCTA(ILM_OPL)');
imgFile = fullfile(ilmOplDir, [idStr '.bmp']);
if ~isfile(imgFile)
    imgFile = fullfile(ilmOplDir, [idStr '.png']);
end

if isfile(imgFile)
    raw = imread(imgFile);
    if size(raw, 3) == 1
        octaData.angiogramILM_OPL = repmat(raw, 1, 1, 3);
    else
        octaData.angiogramILM_OPL = raw;
    end
    octaData.source = 'OCTA-500 En-Face ILM_OPL';
    octaData.metadata.dimensions = size(raw);
    octaData.metadata.resolution = '3mm x 3mm FOV';
end

% Locate Ground Truth Labels
labelsDir = fullfile(baseOCTAPath, 'Label', 'Label');
if ~isfolder(labelsDir)
    labelsDir = fullfile(baseOCTAPath, 'Label');
end

if isfolder(labelsDir)
    % FAZ / CAVF
    fazDir = fullfile(labelsDir, 'GT_FAZ');
    if ~isfolder(fazDir); fazDir = fullfile(labelsDir, 'GT_CAVF'); end
    if isfolder(fazDir)
        fazFile = fullfile(fazDir, [idStr '.bmp']);
        if ~isfile(fazFile); fazFile = fullfile(fazDir, [idStr '.png']); end
        if isfile(fazFile)
            octaData.fazMask = imread(fazFile) > 0;
        end
    end
    
    % Artery
    artDir = fullfile(labelsDir, 'GT_Artery');
    if isfolder(artDir)
        artFile = fullfile(artDir, [idStr '.bmp']);
        if ~isfile(artFile); artFile = fullfile(artDir, [idStr '.png']); end
        if isfile(artFile)
            octaData.arteryMask = imread(artFile) > 0;
        end
    end
    
    % Capillary
    capDir = fullfile(labelsDir, 'GT_Capillary');
    if isfolder(capDir)
        capFile = fullfile(capDir, [idStr '.bmp']);
        if ~isfile(capFile); capFile = fullfile(capDir, [idStr '.png']); end
        if isfile(capFile)
            octaData.capillaryMask = imread(capFile) > 0;
        end
    end
end
end
