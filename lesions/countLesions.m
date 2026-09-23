function [count, centroids, areas, mask] = countLesions(probabilityMap, threshold, minimumArea)
%COUNTLESIONS Threshold one lesion probability map and extract connected components.
%   [COUNT, CENTROIDS, AREAS, MASK] = countLesions(PROBABILITYMAP, THRESHOLD, MINIMUMAREA)
%   converts pixel-level probability map into connected discrete lesion candidates.
%   Also supports COUNT = countLesions(MASKS_STRUCT) to count across all lesion types.

if isstruct(probabilityMap)
    s = probabilityMap;
    maC = 0; if isfield(s, 'ma') && ~isempty(s.ma); maC = countLesions(s.ma); elseif isfield(s, 'MA') && ~isempty(s.MA); maC = countLesions(s.MA); end
    heC = 0; if isfield(s, 'he') && ~isempty(s.he); heC = countLesions(s.he); elseif isfield(s, 'HE') && ~isempty(s.HE); heC = countLesions(s.HE); end
    exC = 0; if isfield(s, 'ex') && ~isempty(s.ex); exC = countLesions(s.ex); elseif isfield(s, 'EX') && ~isempty(s.EX); exC = countLesions(s.EX); end
    seC = 0; if isfield(s, 'se') && ~isempty(s.se); seC = countLesions(s.se); elseif isfield(s, 'SE') && ~isempty(s.SE); seC = countLesions(s.SE); end
    
    countStruct = struct();
    countStruct.maCount = maC;
    countStruct.heCount = heC;
    countStruct.exCount = exC;
    countStruct.seCount = seC;
    countStruct.totalCount = maC + heC + exC + seC;
    count = countStruct;
    centroids = [];
    areas = [];
    mask = [];
    return;
end

if nargin < 2 || isempty(threshold)
    threshold = 0.50;
end
if nargin < 3 || isempty(minimumArea)
    minimumArea = 4;
end

if islogical(probabilityMap)
    mask = probabilityMap;
else
    mask = probabilityMap >= threshold;
end

if minimumArea > 1
    mask = bwareaopen(mask, minimumArea);
end

components = bwconncomp(mask);
properties = regionprops(components, 'Centroid', 'Area');

if isempty(properties)
    centroids = zeros(0, 2);
    areas = zeros(0, 1);
else
    centroids = reshape([properties.Centroid], 2, []).';
    areas = [properties.Area].';
end

count = components.NumObjects;
end
