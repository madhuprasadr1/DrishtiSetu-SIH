function [probabilities, scaledLogits] = applyCalibration(logits, temperature)
%APPLYCALIBRATION Temperature scaling calibration for deep learning probabilities.
%   [PROBABILITIES, SCALEDLOGITS] = applyCalibration(LOGITS, TEMPERATURE)
%   scales logits by positive scalar TEMPERATURE and applies softmax.
%   LOGITS is classes-by-samples (e.g. 5-by-1).

if ~isnumeric(logits) || isempty(logits)
    error('grading:InvalidLogits', 'Logits must be a non-empty numeric array.');
end
if any(~isfinite(logits(:)))
    error('grading:InvalidLogits', 'Logits must contain only finite values.');
end
if nargin < 2 || isempty(temperature)
    temperature = 1.0;
end
if ~isnumeric(temperature) || ~isscalar(temperature) || ~isfinite(temperature) || temperature <= 0
    error('grading:InvalidTemperature', 'Temperature must be a finite positive scalar.');
end

if isvector(logits)
    isRow = isrow(logits);
    logits = logits(:);
else
    isRow = false;
end

if temperature == 1.0
    scaledLogits = logits;
else
    scaledLogits = logits ./ double(temperature);
end

shiftedLogits = scaledLogits - max(scaledLogits, [], 1);
unnormalized = exp(shiftedLogits);
probabilities = unnormalized ./ sum(unnormalized, 1);

if isRow
    probabilities = probabilities.';
    scaledLogits = scaledLogits.';
end
end
