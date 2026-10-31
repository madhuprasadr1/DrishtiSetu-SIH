# DrishtiSetu

Project Demonstartion link : [(https://youtu.be/qFzCdkRTA2U)]

### Offline-First Explainable AI for Diabetic Retinopathy Screening & Estimated 3D Retinal Visualization in Rural India

[![MATLAB](https://img.shields.io/badge/Platform-MATLAB%20%7C%20Simulink%20%7C%20Stateflow-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Release](https://img.shields.io/badge/Release-v1.0.0--MVP-success.svg)](#1-final-system-objective)
[![Deployment](https://img.shields.io/badge/Deployment-100%25%20Offline%20PHC-brightgreen.svg)](#deployment-levels)
[![AI Philosophy](https://img.shields.io/badge/AI%20Philosophy-Explainable%20%2B%20Uncertainty--Aware-orange.svg)](#m08--safety-engine)
[![3D Architecture](https://img.shields.io/badge/Advanced%203D-Decoupled%20%26%20Independent-purple.svg)](#m13--advanced-3d-visualization)

---

## 1. Final System Objective

**DrishtiSetu** ("Bridge to Vision") is an offline-first, mathematically calibrated, explainable diabetic retinopathy (DR) screening platform engineered specifically for **Primary Health Centres (PHCs)**, **Community Health Centres (CHCs)**, and mobile vision clinics across rural and peri-urban India.

The platform takes a standard digital color fundus photograph and executes a 16-module clinical workflow:

```text
Image Acquisition ──► Integrity Check ──► Quality Assessment ──► Borderline Enhancement
         │                                                            │
         ▼                                                            ▼
Retinal Anatomy (Retina, Disc, Fovea, Vessels) ◄──────────────────────┘
         │
         ├──► Quantitative Lesion Measurement (MA, HE, EX, SE)
         │
         ├──► 5-Level ICDR Severity Grading & Referable DR Determination
         │
         ├──► Safety Engine (Temperature Scaling, Confidence, Shannon Uncertainty, OOD)
         │
         ├──► Multi-Source Explainable AI (Grad-CAM, Lesion Map, Vascular Density, Narrative)
         │
         ├──► Advanced Estimated 3D Retinal Vascular Visualization (Decoupled Research Branch)
         │
         └──► Clinical Decision Support & Multi-Format Reporting (Vector PDF, PNG, TXT)
```





> [!IMPORTANT]
> **Core Clinical Pathway vs. Advanced 3D Decoupling Guarantee**:
> The core clinical diagnostic pipeline remains strictly independent of the advanced estimated 3D subsystem. The 3D visualization operates as an independent structural research layer. If 3D reconstruction encounters resource constraints or fails, the primary DR diagnosis, safety gating, and referral dispatch proceed completely unimpeded.

---

## 2. Complete End-to-End System Architecture

```text
                         DRISHTISETU
                              │
                              ▼
                    ┌───────────────────┐
                    │ FUNDUS CAMERA     │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ ACQUISITION       │
                    │ + METADATA (M01)  │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ IMAGE INTEGRITY   │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ QUALITY ENGINE    │
                    │ (M02)             │
                    │ Focus, Illum, FOV │
                    └─────────┬─────────┘
                              │
                  ┌───────────┼────────────┐
                  │           │            │
                 BAD      BORDERLINE      GOOD
                  │           │            │
                  ▼           ▼            │
              RECAPTURE   ENHANCEMENT      │
              ADVICE      (CLAHE M03)      │
                  │           │            │
                  │           ▼            │
                  │      QUALITY RECHECK   │
                  │           │            │
                  └───────────┴────────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ STANDARDIZATION   │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ RETINAL ANATOMY   │
                    │ (M04)             │
                    │ Retina, Disc,     │
                    │ Fovea, Vessels    │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ LESION ENGINE     │
                    │ (M05)             │
                    │ MA, HE, EX, SE    │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ MEASUREMENT ENGINE│
                    │ (M06)             │
                    │ Count, Area, Diam │
                    │ Shape, Dist to OD │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ DR GRADING (M07)  │
                    │ Level 0, 1, 2, 3,4│
                    │ Referable = L>=2  │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ SAFETY ENGINE     │
                    │ (M08)             │
                    │ Calib, Conf,      │
                    │ Uncertainty, OOD  │
                    └─────────┬─────────┘
                              │
                    ┌─────────┴──────────┐
                    │                    │
                 SAFE/HIGH            UNCERTAIN
                 CONFIDENCE               │
                    │                    ▼
                    │              HUMAN REVIEW
                    │                 (M10)
                    └──────────┬─────────┘
                               │
               ┌───────────────┴───────────────┐
               │                               │
               ▼                               ▼
     ┌───────────────────┐           ┌───────────────────┐
     │ EXPLAINABLE AI    │           │ ADVANCED 3D (M13) │
     │ (M09)             │           │ Decoupled Retinal │
     │ Grad-CAM, Lesions,│           │ Vascular Relief & │
     │ Vessels, Narrative│           │ Synthetic B-Scan  │
     └─────────┬─────────┘           └─────────┬─────────┘
               │                               │
               └───────────────┬───────────────┘
                               ▼
                    ┌───────────────────┐
                    │ CLINICAL REPORT   │
                    │ (M11) PDF/PNG/TXT │
                    └─────────┬─────────┘
                              │
                 ┌────────────┼────────────┐
                 ▼            ▼            ▼
              STORE        REFER        FOLLOW-UP
            (SQLite/MAT) (Specialist)  (12-Mo Recall)
                 │
                 ▼
             AUDIT LOG (M12)
```

---

## 3. The 16 Modules

| Module | Code Location | Responsibility & Primary Output |
| :--- | :--- | :--- |
| **M01 — Acquisition** | `acquisition/` | Native image loading, validation, metadata capture, pseudonymous patient IDs (`P-XXXXX`). |
| **M02 — Image Quality** | `quality/` | Sharpness, exposure, illumination, FOV coverage; 3-way triage (`GOOD`, `BORDERLINE`, `BAD`). |
| **M03 — Adaptive Enhancement** | `preprocessing/` | Illumination normalization, localized CLAHE, contrast adjustment; preserves original image untouched. |
| **M04 — Retinal Anatomy** | `anatomy/` | Retinal mask, optic disc cup localization, foveal coordinates, vessel tree segmentation, vessel area density. |
| **M05 — Lesion Intelligence** | `lesions/` | Multi-head candidate detection: Microaneurysms (MA), Haemorrhages (HE), Hard Exudates (EX), Soft Exudates (SE). |
| **M06 — Measurement Engine** | `measurements/` | Quantitative lesion quantification: Area ($A = N_{px} \cdot scale$), Diameter ($D = 2\sqrt{A/\pi}$), Circularity ($4\pi A/P^2$), Eccentricity, and Anatomical Distances to Fovea/Disc in Disc Diameters (DD). |
| **M07 — DR Severity** | `grading/` | 5-level ICDR classification (0: No DR, 1: Mild, 2: Moderate, 3: Severe, 4: Proliferative); derives Referable DR ($Grade \ge 2$). |
| **M08 — Safety Engine** | `safety/` | Temperature scaling ($T=2.1414$), Top-1 confidence, Shannon entropy uncertainty, and Out-of-Distribution (OOD) chromaticity gating. |
| **M09 — Explainable AI** | `explainability/` | Evidence fusion: Grad-CAM attention heatmap, lesion biomarker map, vascular tree overlay, and synthesized natural language narrative. |
| **M10 — Human-in-the-Loop** | `review/` | Clinician Accept / Modify / Recapture / Refer interface with immutable reviewer signature logging. |
| **M11 — Reporting** | `reporting/` | Multi-page publication-grade Vector PDF, high-resolution PNG screening card, and companion TXT report with embedded 3D topography. |
| **M12 — Privacy & Audit** | `database/` | Offline structured MAT/SQLite case registry and tamper-evident append-only audit trail (`drishtisetu_audit.log`). |
| **M13 — Advanced Estimated 3D** | `advanced3D/` | Anatomically grounded 3D retinal surface mesh, vascular caliber elevation relief, optic cup depression, and synthetic B-scan depth profiles. |
| **M14 — Model Intelligence** | `models/`, `training/` | Deep learning checkpoints (ResNet-50 grading, Multi-head Lesion U-Net, Retinal Vessel U-Net) and transfer learning laboratory. |
| **M15 — Robustness & Validation** | `validation/` | External multi-dataset validation (Sensitivity, Specificity, AUROC, ECE, Brier score) across 5 standard benchmarks. |
| **M16 — Simulink & Stateflow** | `simulation/` | Discrete-event PHC operational queue model: patient arrival rates, operator utilization, queue lengths, and annual capacity modeling. |

---

## 4. The 5 Supported Datasets

DrishtiSetu is calibrated to operate on **real clinical imagery** from 5 standard international retinal datasets:

```text
data/datasets/
├── aptos2019/                  # 3,296 images: 5-level DR severity grading benchmark
│   ├── train_images/           # High-resolution clinical fundus images (.png)
│   └── train.csv               # Ground-truth diagnosis labels (0 to 4)
│
├── drive/                      # 40 images: Retinal vascular tree segmentation benchmark
│   ├── training/images/        # High-resolution TIFF fundus photographs
│   └── training/1st_manual/    # Gold-standard expert vessel annotations
│
├── idrid/                      # Multi-task benchmark: Lesions + Grading + Anatomy
│   ├── 1. Original Images/     # High-fidelity RGB fundus images
│   └── 2. Groundtruths/        # Pixel-level masks: MAs, HEs, Hard Exudates, Soft Exudates
│
├── messidor2/                  # 1,744 images: External multicenter clinical validation
│   ├── images/                 # Uncompressed clinical fundus captures
│   └── messidor_data.csv       # Specialist consensus DR grades & macular edema tags
│
└── octa500/                    # 300 volumes: Cross-modal 3D structural learning
    ├── OCTA(ILM_OPL)/          # Superficial vascular plexus en-face angiograms (.bmp)
    └── Label/Label/            # Ground truth: FAZ, Artery, and Capillary non-perfusion
```

---

## 5. Prerequisites & Environment Setup

### System Requirements
- **OS**: Windows 10/11 (64-bit) or Linux (Ubuntu 22.04 LTS+).
- **RAM**: Minimum 8 GB (16 GB recommended for high-volume rural screening).
- **GPU**: Optional (CPU-optimized native matrix acceleration enables fast offline inference).
- **MATLAB**: R2024b or R2026a.

### Required MATLAB Toolboxes
- Image Processing Toolbox
- Computer Vision Toolbox
- Deep Learning Toolbox
- Statistics and Machine Learning Toolbox
- Simulink & Stateflow (Required for Module M16 PHC operational simulations)

---

## 6. Step-by-Step Instructions to Run After Cloning

### Step 1: Open the Project in MATLAB
Launch MATLAB, navigate to the repository directory, and initialize the system environment:
```matlab
cd('c:\Users\TARUN\Downloads\SIH_Prototype\DrishtiSetu');
main_DrishtiSetu('Headless', true);
```
*Expected Output:*
```text
================================================================================
DRISHTISETU: Explainable AI for Diabetic Retinopathy Screening in Rural India
Version: 1.0.0-MVP  |  Offline-First Primary Healthcare Deployment
================================================================================

[1/6] Initializing project paths...
[2/6] Verifying MATLAB toolboxes...
  + Image Processing Toolbox                : INSTALLED
  + Computer Vision Toolbox                 : INSTALLED
  + Deep Learning Toolbox                   : INSTALLED
  + Statistics and Machine Learning Toolbox : INSTALLED
  + Simulink & Stateflow                    : INSTALLED
[3/6] Initializing local database and audit subsystem...
  + Local screening registry initialized (cases on record).
[4/6] Checking AI model checkpoints...
  + DR 5-Level ResNet50 Classifier         : READY
  + Multi-Head Lesion U-Net                 : READY
  + Retinal Vessel U-Net                    : READY
[5/5] Ready for live clinical fundus intake.
```

---

### Step 2: Screen Real Fundus Images (Command Line)

To screen an **actual fundus image** with full quality gating, lesion quantification, 5-level DR prediction, and **Estimated 3D Retinal Visualization**:

#### Example A: Real APTOS 2019 Image
```matlab
result = screenFundusImage('data/datasets/aptos2019/train_images/000c1434d8d7.png', 'Eye', 'OD', 'Save3D', true);
```

#### Example B: Real DRIVE Vessel Benchmark Image
```matlab
result = screenFundusImage('data/datasets/drive/training/images/21_training.tif', 'Eye', 'OS', 'Save3D', true);
```

#### Example C: Real IDRiD Multi-Lesion Image
```matlab
result = screenFundusImage('data/datasets/idrid/1. Original Images/a. Training Set/IDRiD_01.jpg', 'Eye', 'OD');
```

#### Example D: Real Messidor-2 Validation Image
```matlab
result = screenFundusImage('data/datasets/messidor2/images/20051020_43808_0100_PP.png', 'Eye', 'OD');
```

---

### Step 3: Launch the Interactive Clinical Workstation UI

To open the graphical interface:
```matlab
main_DrishtiSetu
```

#### Workstation Tabs:
1. **1. Clinical Screening**:
   - Open any real image via the "Open Fundus Image..." button.
   - Enter Patient Pseudo-ID and select Eye Laterality (OD / OS).
   - Click **Run DrishtiSetu Screening** to trigger the automated 12-stage pipeline.
   - View the 4-panel diagnostic workspace: Original Image, Native Retinal Field, Grad-CAM Attention Heatmap, and Lesion Biomarkers.
   - Review quality status, calibrated referable risk percentage, confidence, and safety gate triage.
2. **2. Estimated 3D Retina (Module M13)**:
   - Interactive 3D retinal surface mesh showing vascular caliber elevation relief.
   - Optic nerve cup excavation depression and foveal avascular depression profiles.
   - View presets: **Isometric**, **Top-Down**, and **Side Profile**.
   - Synthetic OCT B-scan depth profile curve through the optic disc to fovea transect.
   - Metrics card displaying total elevation span in microns ($\mu m$).
3. **3. Human Review**:
   - Ophthalmologist review seam with action buttons: **ACCEPT**, **MODIFY**, or **REJECT / Recapture**.
   - Clinician notes field and immutable signature recording.
4. **4. Clinical Report**:
   - Instant preview of the generated clinical report summary.
   - One-click buttons to open the Vector PDF report or high-resolution PNG screening card.
5. **5. Case History & Audit**:
   - Searchable local screening database registry.
   - Tamper-evident append-only audit trail.

---

### Step 4: Run the Complete Automated Verification Test Suite

To verify system correctness, run the comprehensive 11-suite test runner:
```matlab
addpath('tests');
results = runAllDrishtiSetuTests();
```
*Expected Result:*
```text
================================================================================
  TEST SUITE EXECUTION SUMMARY
================================================================================
Total Tests:      36
Passed:           36
Failed:           0
Incomplete:       0
>>> ALL DRISHTISETU VERIFICATION TESTS PASSED SUCCESSFULLY! <<<
```

---

### Step 5: Run the PHC Operational Workflow Simulation (Simulink / SimEvents)

Simulate clinical capacity, queuing bottlenecks, and patient turnaround times for rural PHCs:
```matlab
cfg = simulationConfig();
cfg.simDurationHours = 8;        % Full 8-hour rural clinic shift
cfg.arrivalRatePerHour = 15;      % 15 patients/hour arrival load
simResults = runPHCSimulation(cfg);

fprintf('Mean Patient Wait Time:    %.1f minutes\n', simResults.meanWaitTimeMinutes);
fprintf('Total Patients Screened:   %d\n', simResults.totalScreened);
fprintf('Camera Utilization:        %.1f%%\n', simResults.cameraUtilization * 100);
```

---

## 7. Module M13: Advanced Estimated 3D Retinal Visualization

### Anatomical Depth Modeling
Module M13 reconstructs an estimated 3D vascular and retinal relief map $Z(x, y)$ using geometric and histological priors:

$$Z(x, y) = Z_{\text{globe}}(x, y) + Z_{\text{cup}}(x, y) + Z_{\text{fovea}}(x, y) + Z_{\text{vessels}}(x, y) + Z_{\text{lesions}}(x, y)$$

1. **Posterior Globe Curvature ($Z_{\text{globe}}$)**: Parabolic concave dome modeling the spherical posterior fundus shell.
2. **Optic Nerve Head Cup Excavation ($Z_{\text{cup}}$)**: Steep Gaussian cup depression plunging $\sim 280\ \mu m$ below the retinal baseline.
3. **Foveal Avascular Depression ($Z_{\text{fovea}}$)**: Foveal pit clivus depression $\sim 135\ \mu m$ at the fovea centralis.
4. **Retinal Vascular Tree Elevation ($Z_{\text{vessels}}$)**: Continuous relief mapped to vessel caliber $r$ via non-linear scaling:
   $$Z_{\text{vessels}} = H_{\max} \cdot \left(\frac{bwdist(\sim\text{vesselMask})}{\max(bwdist)}\right)^{0.65}$$
5. **Pathological Relief ($Z_{\text{lesions}}$)**: Localized elevation for hard exudates (lipid accumulation in OPL) and intraretinal hemorrhages.
6. **Synthetic B-Scan Profile**: 1D axial depth slice sampled along the optic disc $\rightarrow$ fovea transect.

### Output Files Generated:
- High-definition 3D isometric render: `results/3d_visualizations/DrishtiSetu_3D_<CaseID>_<Eye>.png`
- Embedded in the 6-panel Clinical Report: `results/reports/DrishtiSetu_Report_<CaseID>_<Eye>.pdf`
- Interactive 3D surface viewport in **Tab 2** of the `DrishtiSetuApp`.

---

## 8. Module M06: Quantitative Measurement Engine

Every detected lesion candidate is quantified geometrically without manufacturing false precision:

- **Count**: Total candidate regions per category (MA, HE, EX, SE).
- **Area ($A$)**: Computed as $A = N_{\text{pixels}} \cdot \text{scale}^2$. Reported in $\mu m^2$ when optical scale calibration is provided, or in exact pixel units.
- **Equivalent Diameter ($D$)**:
  $$D = 2 \cdot \sqrt{\frac{A}{\pi}}$$
- **Shape Biomarkers**: Perimeter ($P$), Circularity ($C = 4\pi A / P^2$), and Eccentricity ($e$).
- **Anatomical Distance**: Euclidean distance to the fovea center and optic disc center, reported both in pixels and in **Optic Disc Diameters (DD)**.
- **Macular Threat**: Flags lesions located within $1.0\ \text{DD}$ of the fovea centralis.
- **Retinal Quadrants**: Categorizes lesions into Superotemporal (ST), Inferotemporal (IT), Superonasal (SN), and Inferonasal (IN).

---

## 9. The Central Result Object Schema

All modules communicate through one standardized MATLAB structure:

```matlab
result = 
    caseID: 'DS-20260923-E963'
    patient: [struct with pseudoID, age, gender, diabetesYears]
    eye: 'OD'
    acquisition: [struct with timestamp, cameraID, originalImage]
    quality: [struct with qualityClass, qualityScore, isEnhanced, recaptureAdvice]
    preprocessing: [struct with processedImage, modelInputImage, cropBBox]
    anatomy: [struct with retinalMask, opticDiscCenter, foveaLocation, vesselMask, vesselDensity]
    lesions: [struct with MA, HE, EX, SE counts and masks]
    measurements: [struct with counts, totalArea, equivalentDiameters, macularThreat, quadrants] (M06)
    dr: [struct with drGrade, drLabel, referable, calibratedRisk, probabilities] (M07)
    safety: [struct with confidenceScore, uncertaintyScore, oodFlag, safetyStatus] (M08)
    explainability: [struct with gradCAMOverlay, lesionOverlay, vesselOverlay, narrative] (M09)
    review: [struct with status, reviewerID, clinicianNotes] (M10)
    advanced3D: [struct with status, mode, depthInfo, rendered3DImage, elevationSpan] (M13)
    report: [struct with reportPDFPath, reportPNGPath, reportTextPath, summaryText] (M11)
    audit: [struct with systemName, version, inferenceDurationSeconds, executionEnvironment] (M12)
```

---

## 10. Offline-First Security & Audit Architecture

1. **Zero External Network Dependencies**: Operates 100% offline. No cloud APIs, credentials, or remote servers.
2. **Pseudonymous Patient Identity**: Strips identifying PII; uses hash-based pseudonymous identifiers (`P-XXXXX`).
3. **Immutable Audit Journal**: Every screening event, quality gate check, classification, and clinician override is recorded with an ISO-8601 timestamp in `data/drishtisetu_audit.log`.
4. **Original Image Preservation**: Original camera captures are preserved unaltered in native fidelity alongside preprocessed model inputs.

---

## 11. Regulatory & Clinical Decision Support Notice

> [!CAUTION]
> **Clinical Disclaimer**:
> DrishtiSetu is an investigational **Screening Decision Support System (SDSS)** designed to assist healthcare workers in rural Primary Health Centres. It is **not** an autonomous diagnostic device. 
> 
> All referable, borderline, or high-uncertainty determinations must be verified by a certified ophthalmologist or eye care specialist prior to clinical intervention.

---

## 12. Project Directory Structure

```text
DrishtiSetu/
├── main_DrishtiSetu.m              # Primary startup & verification entrypoint
├── screenFundusImage.m             # Live clinical screening entrypoint for real fundus images
├── README.md                       # Complete project manual & execution instructions
│
├── acquisition/                    # Module M01: Image ingestion & validation
├── quality/                        # Module M02: Deterministic quality gating & feedback
├── preprocessing/                  # Module M03: Adaptive CLAHE & FOV normalization
├── anatomy/                        # Module M04: Retinal FOV, optic disc, fovea & vessels
├── lesions/                        # Module M05: Candidate detection (MA, HE, EX, SE)
├── measurements/                   # Module M06: Quantitative geometric lesion quantification
├── grading/                        # Module M07: 5-level ICDR grading & referable DR triage
├── safety/                         # Module M08: Temperature calibration, uncertainty & OOD
├── explainability/                 # Module M09: Grad-CAM, lesion overlays & clinical narrative
├── review/                         # Module M10: Ophthalmologist review interface
├── reporting/                      # Module M11: Vector PDF, PNG, and TXT report generation
├── database/                       # Module M12: Offline MAT/SQLite registry & audit logging
├── advanced3D/                     # Module M13: Estimated 3D retinal vascular visualization
├── models/                         # Module M14: Checkpoint weights (ResNet-50, U-Nets)
├── validation/                     # Module M15: Diagnostic metric evaluators
├── simulation/                     # Module M16: Simulink / Stateflow PHC operational queuing
├── app/                            # DrishtiSetuApp: 5-tab clinical workstation UI
├── config/                         # System, model, and simulation configuration structs
├── tests/                          # 11-suite automated unit & integration test runner
├── data/                           # Local datasets, cases, database & audit log
└── results/                        # Exported PDF/PNG reports & 3D visualization renders
    ├── reports/
    └── 3d_visualizations/
```
