function [mask, info] = retinalMask(image, config)
%RETINALMASK Segment illuminated retinal region and field of view.
%   [MASK, INFO] = retinalMask(IMAGE, CONFIG) extracts the retinal boundary
%   and geometric properties (centroid, radius, equivalent diameter).

if nargin < 2; config = []; end
[mask, info] = fovMask(image, config);
end
