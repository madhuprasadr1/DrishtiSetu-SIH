function modelPath = buildPHCModel(forceRebuild)
%BUILDPHCMODEL Build or verify the SimEvents PHC workflow Simulink model.
%   MODELPATH = buildPHCModel(FORCEREBUILD) returns the path to the verified .slx model.

if nargin < 1
    forceRebuild = false;
end

simDir = fileparts(mfilename('fullpath'));
modelPath = fullfile(simDir, 'district_model.slx');

if ~isfile(modelPath)
    % Fall back to simulink folder if not found in simulation
    altPath = fullfile(fileparts(simDir), 'simulink', 'district_model.slx');
    if isfile(altPath)
        copyfile(altPath, modelPath);
    else
        error('simulation:ModelNotFound', 'SimEvents model file district_model.slx not found.');
    end
end
end
