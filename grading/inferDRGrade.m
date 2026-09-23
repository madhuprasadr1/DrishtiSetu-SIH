function drResult = inferDRGrade(imageOrPreprocessed, varargin)
%INFERDRGRADE 5-level diabetic retinopathy grading and referable screening inference.
%   DRRESULT = inferDRGrade(IMAGE, CONFIG, LESIONEVIDENCE)
%   DRRESULT = inferDRGrade(IMAGE, LESIONEVIDENCE, ANATOMY, CONFIG)
%   returns:
%       drGrade                        - 0 to 4 integer severity grade
%       drLabel                        - Full clinical label (e.g. 'Moderate NPDR (Level 2)')
%       referable                      - Boolean (true for Grade >= 2)
%       rawProbabilities               - 5-element softmax probability vector
%       calibratedProbabilities        - Temperature-scaled calibrated probabilities
%       calibratedReferableProbability - Sum of calibrated P(Level 2, 3, 4)
%       modelCheckpoint                - Path to model file or fallback descriptor

config = projectConfig();
lesionEvidence = struct();
anatomy = struct();

for i = 1:numel(varargin)
    arg = varargin{i};
    if isstruct(arg)
        if isfield(arg, 'project') || isfield(arg, 'grading') || isfield(arg, 'operating_point') || isfield(arg, 'quality')
            config = arg;
        elseif isfield(arg, 'suggestedGrade') || isfield(arg, 'counts') || isfield(arg, 'summary') || isfield(arg, 'quadrants') || isfield(arg, 'evidence')
            lesionEvidence = arg;
        elseif isfield(arg, 'opticDisc') || isfield(arg, 'fovea') || isfield(arg, 'vessels')
            anatomy = arg;
        else
            if isempty(fieldnames(lesionEvidence))
                lesionEvidence = arg;
            else
                config = arg;
            end
        end
    end
end

classLabels = {'No DR (Level 0)', 'Mild NPDR (Level 1)', ...
    'Moderate NPDR (Level 2)', 'Severe NPDR (Level 3)', 'Proliferative DR (Level 4)'};

hasDL = false;
modelPath = '';
if isfield(config, 'grading') && isfield(config.grading, 'checkpoint')
    modelPath = config.grading.checkpoint;
    if isfile(modelPath)
        hasDL = true;
    end
end

temp = 2.1414;
if isfield(config, 'operating_point') && isfield(config.operating_point, 'temperature')
    temp = config.operating_point.temperature;
elseif isfield(config, 'grading') && isfield(config.grading, 'temperature')
    temp = config.grading.temperature;
end

if hasDL
    try
        % Execute deep learning model
        loaded = load(modelPath);
        net = loaded.net;
        
        % Ensure input is preprocessed [448, 448, 3] single
        if size(imageOrPreprocessed, 1) ~= 448 || size(imageOrPreprocessed, 2) ~= 448
            [prepImg, ~, ~] = preprocessFundus(imageOrPreprocessed, config);
        else
            prepImg = single(imageOrPreprocessed);
        end
        
        rawOutput = minibatchpredict(net, prepImg, 'MiniBatchSize', 1, ...
            'ExecutionEnvironment', 'cpu', 'OutputDataFormats', 'CB');
        rawProb = double(gather(extractdata(rawOutput)));
        rawProb = rawProb(:);
        
        rawLogits = log(max(rawProb, 1e-7));
        [calibratedProb, ~] = applyCalibration(rawLogits, temp);
        [~, bestClassIdx] = max(calibratedProb);
        drGrade = bestClassIdx - 1;
        checkpointReport = modelPath;
    catch ME
        % If DL execution fails, log reason and use fallback
        hasDL = false;
    end
end

if ~hasDL
    % Evidence-based Fallback
    checkpointReport = 'Demo / Rule-based Fallback (Deep learning checkpoint not loaded)';
    ruleRes = icdrEvidence(lesionEvidence);
    drGrade = ruleRes.level;
    
    % Construct surrogate distribution centered at evidence grade
    rawLogits = -2.5 * ones(5, 1);
    rawLogits(drGrade + 1) = 2.0;
    if drGrade > 0; rawLogits(drGrade) = 0.5; end
    if drGrade < 4; rawLogits(drGrade + 2) = 0.5; end
    
    [rawProb, ~] = applyCalibration(rawLogits, 1.0);
    [calibratedProb, ~] = applyCalibration(rawLogits, temp);
end

referable = (drGrade >= 2);
calibratedReferableProb = sum(calibratedProb(3:5));

drResult = struct();
drResult.drGrade = drGrade;
drResult.predictedGrade = drGrade;
drResult.drLabel = classLabels{drGrade + 1};
drResult.referable = referable;
drResult.isReferable = referable;
drResult.rawProbabilities = rawProb;
drResult.calibratedProbabilities = calibratedProb;
drResult.classProbabilities = calibratedProb;
drResult.calibratedReferableProbability = calibratedReferableProb;
drResult.referableProbability = calibratedReferableProb;
drResult.temperature = temp;
drResult.calibrationApplied = true;
drResult.modelCheckpoint = checkpointReport;
drResult.isDeepLearning = hasDL;
drResult.decisionPolicy = decisionPolicy(drResult, config);
end
