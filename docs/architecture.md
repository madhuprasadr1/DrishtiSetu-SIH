# DrishtiSetu System Architecture & Technical Specification

## 1. Overview
DrishtiSetu is an offline-first clinical decision support system designed to operate autonomously in resource-limited rural healthcare environments. The architecture is strictly decoupled into 14 distinct functional subsystems coordinated through a central orchestration seam (`core/runScreeningCase.m`) and a unified 14-field data model (`core/createScreeningResult.m`).

---

## 2. Canonical 14-Field Schema Specification

Every screening result object maintains strict structure across its lifecycle:

```matlab
result = struct( ...
    'caseID',          '', ...      % Unique encounter identifier (e.g. DS-YYYYMMDD-XXXX)
    'patient',         struct(), ...% Pseudonymized patient demographics (ID, age, gender, site)
    'eye',             '', ...      % Laterality: 'OD' (Right) or 'OS' (Left)
    'acquisition',     struct(), ...% Camera model, sensor resolution, capture timestamp
    'quality',         struct(), ...% Focus, illumination, exposure scores, gradability, operator advice
    'preprocessing',   struct(), ...% FOV bounding box, normalized dimensions, enhancement flags
    'anatomy',         struct(), ...% Optic disc (center, radius, mask), fovea (center), vessel density
    'lesions',         struct(), ...% Segmentation masks (MA, HE, EX, SE), counts, quadrants, foveal threat
    'dr',              struct(), ...% ICDR grade (0-4), calibrated probabilities, referable flag, 3-way triage
    'safety',          struct(), ...% Top-1 confidence, Shannon entropy, OOD flag, safety gate status
    'explainability',  struct(), ...% Grad-CAM heatmap, lesion overlay map, vessel map, clinical narrative
    'review',          struct(), ...% Clinician review status, reviewer ID, confirmed grade, notes
    'report',          struct(), ...% Filepaths to generated PDF, PNG, and TXT reports
    'audit',           struct(), ...% Chronological audit trail of all mutations and actions
    'status',          '' ...       % Pipeline lifecycle state ('COMPLETED', 'GATED_RECAPTURE', etc.)
);
```

---

## 3. Subsystem Detailed Design

### 3.1 Acquisition Engine (`acquisition/`)
- **`validateFundusImage.m`**: Ensures input is a valid 2D/3D numerical matrix, handles single/double/uint8 formats, verifies RGB dimensionality, and converts grayscale fundus captures to 3-channel RGB.
- **`loadFundusImage.m`**: Protected file/memory loader that validates file existence and verifies sealed evaluation paths are never breached during inference.
- **`captureMetadata.m`**: Assembles patient demographics and hardware metadata while enforcing pseudonymization (replacing PII with clinical site IDs).

### 3.2 Quality Engine (`quality/`)
- **`fovMask.m`**: Computes binary circular Field-of-View mask using adaptive thresholding and morphological closing.
- **`qualityFeatures.m`**: Computes focus (Laplacian variance and Tenengrad gradient energy), illumination (mean intensity and saturation), exposure (under/over-exposure histograms), and contrast.
- **`classifyQuality.m`**: Triages image into `GOOD`, `BORDERLINE`, or `BAD`.
- **`enhanceBorderline.m`**: For borderline images, applies localized Contrast Limited Adaptive Histogram Equalization (CLAHE) on the green channel and reassesses quality.
- **`recaptureAdvice.m`**: Produces actionable tips for rural camera operators (e.g., "Image out of focus: Adjust camera diopter ring", "Patient blinked: Request wide eye opening").

### 3.3 Preprocessing Engine (`preprocessing/`)
- **`preprocessFundus.m`**: Crops image tightly to the active FOV bounding box with 2% margin, resizes using bicubic interpolation to canonical model input dimensions ($448 \times 448 \times 3$), and normalizes channels to $[0, 1]$ floating-point range.

### 3.4 Anatomy Engine (`anatomy/`)
- **`opticDisc.m`**: Localizes optic nerve head through red-channel brightness clustering and vessel convergence tracking.
- **`fovea.m`**: Identifies macula/fovea using anatomical geometry (approximately 2.5 disc diameters temporal to the optic disc center in the avascular zone, oriented based on eye laterality `OD` vs `OS`).
- **`vessels.m`**: Extracts retinal vascular tree using matched morphological filtering and top-hat transformations.
- **`vesselFeatures.m`**: Computes vessel caliber, skeleton length, bifurcation/branching points, and per-quadrant vascular density.

### 3.5 Lesion Engine (`lesions/`)
- **`detectMicroaneurysmCandidates.m`**: Multi-scale disk-top-hat filtering on green channel, excluding vessel and optic disc regions.
- **`segmentLesions.m`**: Multi-pathology segmentation separating:
  - Microaneurysms (MA)
  - Retinal Hemorrhages (HE)
  - Hard Exudates (EX)
  - Cotton Wool Spots / Soft Exudates (SE)
- **`assignLesionQuadrants.m`**: Assigns lesion counts to the 4 clinical fundus quadrants: Superior-Temporal (ST), Inferior-Temporal (IT), Superior-Nasal (SN), Inferior-Nasal (IN).
- **`buildLesionEvidence.m`**: Synthesizes lesion distances to the foveal avascular zone to calculate Clinically Significant Macular Edema (CSME) risk.

### 3.6 Grading Engine (`grading/`)
- **`applyCalibration.m`**: Applies temperature scaling ($T \approx 1.2$) to raw logits/softmax outputs to prevent neural network overconfidence.
- **`icdrEvidence.m`**: Implements standard international clinical classification rules:
  - Level 0: No DR (0 lesions)
  - Level 1: Mild NPDR (Microaneurysms only)
  - Level 2: Moderate NPDR (More than microaneurysms, but less than Severe)
  - Level 3: Severe NPDR (4-2-1 Rule: $\ge 20$ hemorrhages in all 4 quadrants, OR venous beading in 2+ quadrants, OR IRMA in 1+ quadrant)
  - Level 4: PDR (Neovascularization or vitreous hemorrhage)
- **`decisionPolicy.m`**: Maps calibrated risk and uncertainty into 3 clinical actions (`AUTO_CLEAR`, `REFER`, `ESCALATE_HUMAN_REVIEW`).

### 3.7 Safety Engine (`safety/`)
- **`estimateConfidence.m`**: Computes top-1 probability and margin to top-2 probability.
- **`estimateUncertainty.m`**: Computes normalized Shannon entropy $H(p) / \log_2(5)$.
- **`detectOOD.m`**: Flags non-retinal, corrupted, or spectrally aberrant captures.
- **`safetyGate.m`**: Recommends `SAFE_FOR_AI_ASSISTED_RESULT`, `HUMAN_REVIEW_REQUIRED`, or `RECAPTURE_REQUIRED`.

### 3.8 Explainability Engine (`explainability/`)
- **`generateGradCAM.m`**: Computes Class Activation Maps highlighting regions driving the grading score.
- **`generateLesionMap.m`**: High-contrast color-coded pathology overlay (MA: Red, HE: Dark Red, EX: Yellow, SE: White).
- **`generateVesselMap.m`**: Vascular skeleton overlay.
- **`buildExplanation.m`**: Synthesizes an automated, plain-language clinical explanation narrative detailing lesion distribution, macula involvement, and rationale for referral.

### 3.9 Human-in-the-Loop Review (`review/`)
- Enables tele-ophthalmologists and medical officers to review cases, accept the AI assessment, modify the grade, or reject/order recapture, writing an immutable record with doctor credentials and clinical notes.

### 3.10 Reporting Engine (`reporting/`)
- Compiles a complete visual and textual clinical screening report in 3 formats:
  - High-resolution Vector PDF (`.pdf`)
  - Multi-panel visual summary PNG (`.png`)
  - Plaintext clinical summary (`.txt`) for EHR integration.

### 3.11 Database Engine (`database/`)
- Zero-external-dependency offline storage:
  - Master metadata index in `data/drishtisetu_db.mat`
  - High-fidelity serialized cases in `data/cases/<caseID>.mat`
  - Append-only text audit trail in `data/drishtisetu_audit.log`.

### 3.12 Simulation Engine (`simulation/`)
- SimEvents / Monte Carlo queuing model representing patient arrivals, screening throughput, queuing delays, operator fatigue, and referral logistics in a rural PHC.
