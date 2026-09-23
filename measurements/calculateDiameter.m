function [equivDiameter, unit] = calculateDiameter(areaVal, areaUnit)
%CALCULATEDIAMETER Compute equivalent circular diameter of a retinal lesion.
%   [EQUIVDIAMETER, UNIT] = calculateDiameter(AREAVAL, AREAUNIT)
%   computes: D = 2 * sqrt(A / pi).
%
%   Part of Module M06: Quantitative Measurement Engine.

if nargin < 2 || isempty(areaUnit)
    areaUnit = 'pixels';
end

if isempty(areaVal) || isnan(areaVal) || areaVal <= 0
    equivDiameter = 0;
else
    equivDiameter = 2 * sqrt(double(areaVal) / pi);
end

if strcmp(areaUnit, 'um^2')
    unit = 'um';
elseif strcmp(areaUnit, 'mm^2')
    unit = 'mm';
else
    unit = 'pixels';
end
end
