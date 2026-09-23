function locMetrics = calculateAnatomicalDistance(centroid, foveaLoc, odCenter, discDiameter, eye)
%CALCULATEANATOMICALDISTANCE Compute spatial anatomical location and distances.
%   LOCMETRICS = calculateAnatomicalDistance(CENTROID, FOVEALOC, ODCENTER, DISCDIAMETER, EYE)
%   computes Euclidean distance from lesion centroid to fovea and optic disc,
%   reporting both in pixels and normalized Optic Disc Diameters (DD),
%   plus the anatomical retinal quadrant (ST, IT, SN, IN).
%
%   Part of Module M06: Quantitative Measurement Engine.

if nargin < 4 || isempty(discDiameter) || isnan(discDiameter) || discDiameter <= 0
    discDiameter = 80; % Nominal default disc diameter in pixels
end
if nargin < 5 || isempty(eye)
    eye = 'OD';
end

locMetrics = struct( ...
    'centroid', centroid, ...
    'distToFoveaPixels', NaN, ...
    'distToFoveaDD', NaN, ...
    'distToDiscPixels', NaN, ...
    'distToDiscDD', NaN, ...
    'quadrant', 'Unknown', ...
    'quadrantFull', 'Unknown');

if isempty(centroid) || any(isnan(centroid))
    return;
end

cx = centroid(1);
cy = centroid(2);

% 1. Distance to Fovea
if ~isempty(foveaLoc) && ~any(isnan(foveaLoc))
    fx = foveaLoc(1);
    fy = foveaLoc(2);
    dFov = sqrt((cx - fx)^2 + (cy - fy)^2);
    locMetrics.distToFoveaPixels = dFov;
    locMetrics.distToFoveaDD = dFov / discDiameter;
end

% 2. Distance to Optic Disc
if ~isempty(odCenter) && ~any(isnan(odCenter))
    dx = odCenter(1);
    dy = odCenter(2);
    dDisc = sqrt((cx - dx)^2 + (cy - dy)^2);
    locMetrics.distToDiscPixels = dDisc;
    locMetrics.distToDiscDD = dDisc / discDiameter;
end

% 3. Quadrant Determination (relative to fovea or disc center)
% Reference center: fovea if available, otherwise disc
refX = cx; refY = cy;
if ~isempty(foveaLoc) && ~any(isnan(foveaLoc))
    refX = foveaLoc(1);
    refY = foveaLoc(2);
elseif ~isempty(odCenter) && ~any(isnan(odCenter))
    refX = odCenter(1);
    refY = odCenter(2);
end

isSuperior = cy < refY; % In image coords, y increases downwards

% Temporal vs Nasal depends on eye (OD vs OS)
% In fundus photo:
% For OD (Right Eye): Temporal is rightwards/outer, Nasal is leftwards (towards nose/disc)
% For OS (Left Eye): Temporal is leftwards/outer, Nasal is rightwards
if strcmpi(eye, 'OS')
    isTemporal = cx < refX;
else
    isTemporal = cx > refX;
end

if isSuperior && isTemporal
    locMetrics.quadrant = 'ST';
    locMetrics.quadrantFull = 'Superotemporal';
elseif ~isSuperior && isTemporal
    locMetrics.quadrant = 'IT';
    locMetrics.quadrantFull = 'Inferotemporal';
elseif isSuperior && ~isTemporal
    locMetrics.quadrant = 'SN';
    locMetrics.quadrantFull = 'Superonasal';
else
    locMetrics.quadrant = 'IN';
    locMetrics.quadrantFull = 'Inferonasal';
end
end
