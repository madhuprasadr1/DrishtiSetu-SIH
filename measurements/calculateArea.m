function [pixelArea, calibratedArea, unit] = calculateArea(maskOrRegion, scaleCalibration)
%CALCULATEAREA Compute lesion area in pixel count and calibrated physical units.
%   [PIXELAREA, CALIBRATEDAREA, UNIT] = calculateArea(MASKORREGION, SCALECALIBRATION)
%   computes lesion area: A = N_pixels * scale.
%   Only reports physical units (mm^2 / um^2) when defensible scale calibration exists.
%   Otherwise reports normalized pixel measurements to avoid false clinical precision.
%
%   Part of Module M06: Quantitative Measurement Engine.

if nargin < 2 || isempty(scaleCalibration)
    scaleCalibration = struct('hasScale', false, 'umPerPixel', NaN);
end

if islogical(maskOrRegion) || isnumeric(maskOrRegion)
    pixelArea = double(sum(maskOrRegion(:) > 0));
elseif isstruct(maskOrRegion) && isfield(maskOrRegion, 'Area')
    pixelArea = double(maskOrRegion.Area);
else
    pixelArea = 0;
end

if isfield(scaleCalibration, 'hasScale') && scaleCalibration.hasScale && ...
   isfield(scaleCalibration, 'umPerPixel') && ~isnan(scaleCalibration.umPerPixel) && scaleCalibration.umPerPixel > 0
    % Physical calibration available
    calibratedArea = pixelArea * (scaleCalibration.umPerPixel ^ 2);
    unit = 'um^2';
else
    calibratedArea = pixelArea;
    unit = 'pixels';
end
end
