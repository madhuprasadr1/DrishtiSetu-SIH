function out3D = constructPseudo3D(image, anatomy, lesions, config)
%CONSTRUCTPSEUDO3D Canonical entry point for Module M13 (Advanced 3D Visualization).
%   OUT3D = constructPseudo3D(IMAGE, ANATOMY, LESIONS, CONFIG)
%   orchestrates anatomically grounded depth estimation and high-definition
%   isometric 3D rendering for retinal vascular morphology.
%
%   ARCHITECTURAL GUARANTEE:
%   This subsystem is strictly independent of the primary DR screening pathway.
%   If any 3D operation encounters an error or resource constraint, the system
%   records a non-fatal status and allows DR diagnosis, safety gating, and
%   clinical referral to proceed completely unimpeded.

if nargin < 2 || isempty(anatomy); anatomy = struct(); end
if nargin < 3 || isempty(lesions); lesions = struct(); end
if nargin < 4 || isempty(config);  config = projectConfig(); end

out3D = struct( ...
    'status', 'INITIALIZED', ...
    'mode', 'FUNDUS_ESTIMATED', ...
    'depthInfo', struct(), ...
    'rendered3DImage', [], ...
    'elevationSpan', 0, ...
    'unit', 'microns', ...
    'errorMessage', '');

if isempty(image) || ~isnumeric(image) || size(image, 1) < 16 || size(image, 2) < 16
    out3D.status = 'SKIPPED';
    out3D.errorMessage = 'Image input is empty or invalid for 3D reconstruction.';
    return;
end

try
    % Check if structural prior is trained/cached
    prior = struct();
    priorPath = fullfile('models', 'advanced3D', 'retinal_structural_prior.mat');
    if isfile(priorPath)
        try
            loaded = load(priorPath);
            prior = loaded.prior;
            out3D.mode = 'OCTA_INFORMED_PRIOR';
        catch
            prior = struct();
        end
    end
    
    % 1. Estimate 3D Depth Topography
    depthInfo = estimateDepth(image, anatomy, lesions, prior);
    out3D.depthInfo = depthInfo;
    out3D.elevationSpan = depthInfo.elevationSpan;
    out3D.unit = depthInfo.unit;
    
    % 2. Render High-Resolution Isometric 3D Visualization
    renderedImg = visualizeRetina3D(depthInfo, 'Resolution', [550, 750]);
    out3D.rendered3DImage = renderedImg;
    
    out3D.status = 'COMPLETED';
catch ME
    % Strict clinical isolation: never fail screening if 3D fails
    out3D.status = 'FAILED';
    out3D.errorMessage = ME.message;
    out3D.rendered3DImage = [];
    warning('advanced3D:ConstructionFailed', ...
        'Advanced 3D visualization skipped: %s (Core screening continues unaffected)', ME.message);
end
end
