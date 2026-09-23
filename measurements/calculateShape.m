function shapeMetrics = calculateShape(region)
%CALCULATESHAPE Compute morphological shape metrics for retinal lesion candidate.
%   SHAPEMETRICS = calculateShape(REGION) computes:
%       perimeter, eccentricity, circularity, major axis, minor axis.
%
%   Part of Module M06: Quantitative Measurement Engine.

shapeMetrics = struct( ...
    'perimeter', 0, ...
    'eccentricity', 0, ...
    'circularity', 0, ...
    'majorAxis', 0, ...
    'minorAxis', 0, ...
    'aspectRatio', 1.0);

if isempty(region) || ~isstruct(region)
    return;
end

if isfield(region, 'Perimeter')
    shapeMetrics.perimeter = double(region.Perimeter);
end
if isfield(region, 'Eccentricity')
    shapeMetrics.eccentricity = double(region.Eccentricity);
end
if isfield(region, 'MajorAxisLength')
    shapeMetrics.majorAxis = double(region.MajorAxisLength);
end
if isfield(region, 'MinorAxisLength')
    shapeMetrics.minorAxis = double(region.MinorAxisLength);
end

if shapeMetrics.minorAxis > 0
    shapeMetrics.aspectRatio = shapeMetrics.majorAxis / shapeMetrics.minorAxis;
end

% Circularity: 4 * pi * Area / (Perimeter^2)
% Circle = 1.0; irregular/elongated approaches 0.0
if isfield(region, 'Area') && shapeMetrics.perimeter > 0
    areaVal = double(region.Area);
    circ = (4 * pi * areaVal) / (shapeMetrics.perimeter ^ 2);
    shapeMetrics.circularity = min(max(circ, 0.0), 1.0);
end
end
