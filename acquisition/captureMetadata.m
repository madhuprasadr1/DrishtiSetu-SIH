function meta = captureMetadata(patientID, eye, cameraID)
%CAPTUREMETADATA Generate acquisition metadata with pseudonymous privacy protection.
%   META = captureMetadata(PATIENTID, EYE, CAMERAID) creates a standardized
%   metadata record for a screening capture.

if nargin < 1 || isempty(patientID)
    patientID = ['PHC-' upper(dec2hex(randi([16^4, 16^5-1]), 5))];
end
if nargin < 2 || isempty(eye)
    eye = 'OD';
end
if nargin < 3 || isempty(cameraID)
    cameraID = 'PHC-Fundus-Camera-01';
end

meta = struct();
meta.patientPseudoID = char(patientID);
meta.eye = char(upper(eye));
meta.cameraID = char(cameraID);
meta.captureTimestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
meta.operatorID = 'HCW-Trained';
meta.phcLocation = 'Rural Health Subcentre';
end
