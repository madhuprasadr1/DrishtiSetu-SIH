function [renderedImage, figHandle] = visualizeRetina3D(depthInfo, varargin)
%VISUALIZERETINA3D Render and visualize estimated 3D retinal vascular morphology.
%   [RENDEREDIMAGE, FIG] = visualizeRetina3D(DEPTHINFO) renders an isometric
%   3D surface with illuminated vascular relief and depth elevation colormapping,
%   returning a high-resolution RGB image suitable for UI display and reports.
%
%   VISUALIZERETINA3D(DEPTHINFO, 'TargetAxes', AXES_HANDLE) renders directly
%   into the specified MATLAB uiaxes or standard axes.
%
%   Part of Module M13: Advanced Estimated 3D Retinal Visualization.

parser = inputParser;
parser.addParameter('TargetAxes', [], @(x) isempty(x) || ishghandle(x));
parser.addParameter('Resolution', [600, 800], @isnumeric);
parser.addParameter('ViewAngles', [-35, 42], @isnumeric);
parser.addParameter('Colormap', 'turbo', @ischar);
parser.addParameter('ShowBScan', true, @islogical);
parser.parse(varargin{:});

targetAxes = parser.Results.TargetAxes;
res = parser.Results.Resolution;
viewAngles = parser.Results.ViewAngles;
cmapName = parser.Results.Colormap;
showBScan = parser.Results.ShowBScan;

renderedImage = [];
figHandle = [];

if nargin < 1 || isempty(depthInfo) || ~isfield(depthInfo, 'zSurface')
    return;
end

zSurface = depthInfo.zSurface;
retinalMask = depthInfo.retinalMask;
vesselMask = depthInfo.vesselMask;
odCenter = depthInfo.opticDiscCenter;
fovLoc = depthInfo.foveaLocation;

[origH, origW] = size(zSurface);

% Downsample grid for responsive and smooth 3D surface rendering
targetGridSize = 128;
scale = targetGridSize / max(origH, origW);
newH = round(origH * scale);
newW = round(origW * scale);

zSmall = imresize(zSurface, [newH, newW], 'bilinear');
maskSmall = imresize(retinalMask, [newH, newW], 'nearest');
vesselSmall = imresize(vesselMask, [newH, newW], 'nearest');

% Replace non-retinal pixels with NaN for clean clipping
zSmall(~maskSmall) = NaN;

[X, Y] = meshgrid(linspace(1, origW, newW), linspace(1, origH, newH));

% Create figure if no target axes provided
isOffscreen = isempty(targetAxes);
if isOffscreen
    figHandle = figure('Visible', 'off', 'Color', [0.08, 0.10, 0.14], ...
        'Position', [50, 50, res(2), res(1)]);
    cleanupFig = onCleanup(@() close(figHandle));
    
    if showBScan && isfield(depthInfo, 'bScanProfile') && ~isempty(depthInfo.bScanProfile.depthCurve)
        tiled = tiledlayout(figHandle, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
        ax3D = nexttile(tiled, 1, [2, 1]);
        axB = nexttile(tiled, 3);
    else
        ax3D = axes(figHandle);
        axB = [];
    end
else
    ax3D = targetAxes;
    cla(ax3D);
    axB = [];
end

% Set up 3D surface in ax3D
hold(ax3D, 'on');

% 1. Render 3D Retinal Mesh Surface
hSurf = surf(ax3D, X, Y, zSmall, 'EdgeColor', 'none', 'FaceColor', 'interp', ...
    'FaceAlpha', 0.95);

% Apply rich colormap (warm elevated vessels, deep cool excavations)
try
    colormap(ax3D, cmapName);
catch
    colormap(ax3D, 'parula');
end

% Lighting & Material Properties
shading(ax3D, 'interp');
lighting(ax3D, 'gouraud');
material(ax3D, [0.4, 0.8, 0.4, 15, 0.5]);
camlight(ax3D, 'headlight');
camlight(ax3D, -45, 55);

% 2. Emphasize Vascular Ridges in 3D
if any(vesselSmall(:))
    [vy, vx] = find(vesselSmall);
    if ~isempty(vx)
        % Sample vascular points
        step = max(1, round(numel(vx) / 3000));
        sampleIdx = 1:step:numel(vx);
        vX = X(sub2ind([newH, newW], vy(sampleIdx), vx(sampleIdx)));
        vY = Y(sub2ind([newH, newW], vy(sampleIdx), vx(sampleIdx)));
        vZ = zSmall(sub2ind([newH, newW], vy(sampleIdx), vx(sampleIdx))) + 3.0; % Slight elevation offset
        
        scatter3(ax3D, vX, vY, vZ, 6, [0.95, 0.25, 0.25], 'filled', ...
            'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
    end
end

% 3. Mark Key Anatomical Centers
% Optic Disc
if ~any(isnan(odCenter)) && odCenter(1) >= 1 && odCenter(1) <= origW && odCenter(2) >= 1 && odCenter(2) <= origH
    odZ = interp2(X, Y, zSmall, odCenter(1), odCenter(2));
    if isnan(odZ); odZ = nanmin(zSmall(:)); end
    plot3(ax3D, odCenter(1), odCenter(2), odZ - 5, 'o', ...
        'MarkerSize', 10, 'MarkerFaceColor', [0.2, 0.8, 1.0], 'MarkerEdgeColor', [1, 1, 1], 'LineWidth', 1.5);
    text(ax3D, odCenter(1), odCenter(2), odZ + 25, 'Optic Disc (Cup)', ...
        'Color', [0.3, 0.9, 1.0], 'FontSize', 9, 'FontWeight', 'bold');
end

% Fovea
if ~any(isnan(fovLoc)) && fovLoc(1) >= 1 && fovLoc(1) <= origW && fovLoc(2) >= 1 && fovLoc(2) <= origH
    fovZ = interp2(X, Y, zSmall, fovLoc(1), fovLoc(2));
    if isnan(fovZ); fovZ = nanmin(zSmall(:)); end
    plot3(ax3D, fovLoc(1), fovLoc(2), fovZ - 5, 's', ...
        'MarkerSize', 9, 'MarkerFaceColor', [1.0, 0.85, 0.2], 'MarkerEdgeColor', [1, 1, 1], 'LineWidth', 1.5);
    text(ax3D, fovLoc(1), fovLoc(2), fovZ + 25, 'Fovea Centralis', ...
        'Color', [1.0, 0.85, 0.2], 'FontSize', 9, 'FontWeight', 'bold');
end

% View & Axis Properties
view(ax3D, viewAngles);
grid(ax3D, 'on');
ax3D.GridColor = [0.3, 0.4, 0.5];
ax3D.GridAlpha = 0.4;
ax3D.Color = [0.08, 0.10, 0.14];
ax3D.XColor = [0.7, 0.75, 0.8];
ax3D.YColor = [0.7, 0.75, 0.8];
ax3D.ZColor = [0.7, 0.75, 0.8];

xlabel(ax3D, 'X (pixels)', 'Color', [0.7, 0.75, 0.8], 'FontSize', 8);
ylabel(ax3D, 'Y (pixels)', 'Color', [0.7, 0.75, 0.8], 'FontSize', 8);
zlabel(ax3D, 'Elevation (\mum)', 'Color', [0.7, 0.75, 0.8], 'FontSize', 8);

title(ax3D, sprintf('Estimated 3D Retinal Vascular Topography (Span: %.0f \\mum)', ...
    depthInfo.elevationSpan), 'Color', [0.95, 0.95, 0.98], 'FontSize', 11, 'FontWeight', 'bold');

cb = colorbar(ax3D);
cb.Color = [0.8, 0.85, 0.9];
ylabel(cb, 'Depth / Elevation (\mum)', 'Color', [0.8, 0.85, 0.9], 'FontSize', 8);

hold(ax3D, 'off');

% 4. Render Cross-Sectional B-Scan Profile (if axB exists)
if ~isempty(axB) && isfield(depthInfo, 'bScanProfile') && ~isempty(depthInfo.bScanProfile.depthCurve)
    bCurve = depthInfo.bScanProfile.depthCurve;
    bArc = depthInfo.bScanProfile.arcLength;
    
    hold(axB, 'on');
    axB.Color = [0.08, 0.10, 0.14];
    axB.XColor = [0.7, 0.75, 0.8];
    axB.YColor = [0.7, 0.75, 0.8];
    grid(axB, 'on');
    axB.GridColor = [0.3, 0.4, 0.5];
    
    % Draw retinal layer synthetic boundaries
    plot(axB, bArc, bCurve, 'LineWidth', 2.0, 'Color', [0.2, 0.8, 1.0]);
    plot(axB, bArc, bCurve - 120, '--', 'LineWidth', 1.0, 'Color', [0.3, 0.6, 0.4]); % OPL
    plot(axB, bArc, bCurve - 250, 'LineWidth', 1.5, 'Color', [0.9, 0.5, 0.2]);   % RPE reference
    
    legend(axB, {'ILM (Vascular)', 'OPL', 'RPE Base'}, 'TextColor', [0.8, 0.85, 0.9], ...
        'Color', [0.12, 0.15, 0.20], 'Location', 'southeast', 'FontSize', 7);
    
    title(axB, 'Synthetic OCT B-Scan Profile (Optic Disc \rightarrow Fovea Transect)', ...
        'Color', [0.95, 0.95, 0.98], 'FontSize', 9, 'FontWeight', 'bold');
    xlabel(axB, 'Transect Distance (pixels)', 'Color', [0.7, 0.75, 0.8], 'FontSize', 8);
    ylabel(axB, 'Elevation (\mum)', 'Color', [0.7, 0.75, 0.8], 'FontSize', 8);
    hold(axB, 'off');
end

% 5. Capture Offscreen Frame
if isOffscreen && ~isempty(figHandle) && isvalid(figHandle)
    drawnow;
    try
        frame = getframe(figHandle);
        renderedImage = frame.cdata;
    catch
        % Fallback using print to matrix
        tempImgFile = [tempname '.png'];
        saveas(figHandle, tempImgFile);
        if isfile(tempImgFile)
            renderedImage = imread(tempImgFile);
            delete(tempImgFile);
        end
    end
end
end
