# DrishtiSetu: Dataset Setup & Training Guide

This guide describes where to add the 5 medical imaging datasets (**APTOS 2019**, **IDRiD**, **DRIVE**, **Messidor-2**, and **OCTA-500**) and how to run their training pipelines in DrishtiSetu.

---

## 1. Directory Hierarchy Overview

All datasets are housed in the dedicated `data/datasets/` directory:

```
c:\Users\TARUN\Downloads\sih26038-master\sih26038-master\data\datasets\
├── aptos2019/          <-- APTOS 2019 Blindness Detection (Kaggle)
├── idrid/              <-- Indian Diabetic Retinopathy Image Dataset (IEEE Dataport)
├── drive/              <-- Digital Retinal Images for Vessel Extraction (DRIVE)
├── messidor2/          <-- Messidor-2 Dataset & Adjudicated Labels
└── octa500/            <-- OCTA-500 Angiography (6mm & 3mm volumes / projections)
```

---

## 2. Dataset Specific Setup Instructions

### 1. APTOS 2019 Blindness Detection (5-Level DR Severity)
- **Path**: `data/datasets/aptos2019/`
- **Files to Place**:
  - `train_images/` $\rightarrow$ Place all training images (`*.png`).
  - `train.csv` $\rightarrow$ Must contain columns: `id_code,diagnosis` (0=Normal, 1=Mild, 2=Moderate, 3=Severe, 4=PDR).
  - *(Optional)* `test_images/` and `test.csv`.
- **Target Model**: Deep-learning 5-class classifier (`models/dr_grading_resnet50.mat`).
- **How to Train**:
  ```matlab
  run('training/train_aptos_grading.m');
  ```

---

### 2. IDRiD: Indian Diabetic Retinopathy Image Dataset
- **Path**: `data/datasets/idrid/`
- **Files to Place**:
  - `1. Original Images/`
    - `a. Training Set/` $\rightarrow$ Training `.jpg` fundus photos (`IDRiD_001.jpg` to `IDRiD_413.jpg`).
    - `b. Testing Set/` $\rightarrow$ Test photos (`IDRiD_414.jpg` to `IDRiD_516.jpg`).
  - `2. Groundtruths/`
    - `a. DR Grading/` $\rightarrow$ `IDRiD_Disease Grading_Training Labels.csv`.
    - `b. Lesion Masks/`
      - `1. Microaneurysms/` $\rightarrow$ Binary ground truth masks (`*_MA.tif`).
      - `2. Haemorrhages/` $\rightarrow$ Binary ground truth masks (`*_HE.tif`).
      - `3. Hard Exudates/` $\rightarrow$ Binary ground truth masks (`*_EX.tif`).
      - `4. Soft Exudates/` $\rightarrow$ Binary ground truth masks (`*_SE.tif`).
    - `c. Optic Disc/` $\rightarrow$ Optic disc masks and center coordinates.
- **Target Model**: Multi-head lesion segmentation U-Net (`models/lesion_unet_multihead.mat`).
- **How to Train**:
  ```matlab
  run('training/train_idrid_lesions.m');
  ```

---

### 3. DRIVE: Digital Retinal Images for Vessel Extraction
- **Path**: `data/datasets/drive/`
- **Files to Place**:
  - `training/`
    - `images/` $\rightarrow$ `21_training.tif` through `40_training.tif`.
    - `1st_manual/` $\rightarrow$ `21_manual1.gif` through `40_manual1.gif` (ground truth manual vessel segmentation).
    - `mask/` $\rightarrow$ `21_training_mask.gif` through `40_training_mask.gif`.
  - `test/`
    - `images/` $\rightarrow$ `01_test.tif` through `20_test.tif`.
    - `1st_manual/` $\rightarrow$ `01_manual1.gif` through `20_manual1.gif`.
    - `mask/` $\rightarrow$ `01_test_mask.gif` through `20_test_mask.gif`.
- **Target Model**: Retinal vessel segmentation U-Net (`models/vessel_unet.mat`).
- **How to Train**:
  ```matlab
  run('training/train_drive_vessels.m');
  ```

---

### 4. Messidor-2 Dataset (Clinical DR & Macular Edema)
- **Path**: `data/datasets/messidor2/`
- **Files to Place**:
  - `images/` $\rightarrow$ 1,748 fundus photographs (`*.jpg`, `*.png`, or `*.tif`).
  - `messidor_data.csv` $\rightarrow$ Columns: `image_id,adjudicated_dr_grade,adjudicated_dme`.
- **Target Model**: Cross-validation & calibration model (`models/dr_grading_messidor.mat`).
- **How to Train / Evaluate**:
  ```matlab
  run('training/train_messidor2_grading.m');
  ```

---

### 5. OCTA-500: Optical Coherence Tomography Angiography
- **Path**: `data/datasets/octa500/`
- **Files to Place**:
  - `OCTA_6mm/` and/or `OCTA_3mm/`
    - `Projection Maps/`
      - `OCTA(ILM_OPL)/` (Superficial Vascular Complex - SVC)
      - `OCTA(OPL_BM)/` (Deep Vascular Complex - DVC)
      - `OCTA(Retina)/` (Full retinal thickness projection)
    - `GroundTruth/`
      - `LargeVessel/` (arteries/veins)
      - `Capillary/` (microvascular density)
      - `FAZ/` (Foveal Avascular Zone)
  - `labels.csv` $\rightarrow$ Clinical metadata & disease labels.
- **Target Model**: Microvascular biomarker & FAZ segmentation net (`models/octa_microvascular_net.mat`).
- **How to Train**:
  ```matlab
  run('training/train_octa500_vessels.m');
  ```

---

## 3. Master Training Pipeline Launcher

DrishtiSetu provides a unified training launcher that scans your `data/datasets/` folder, detects which datasets are populated, and trains or evaluates them:

```matlab
% In MATLAB command window:
run('training/runTrainingPipeline.m');
```

Once any model is trained and its `.mat` file is saved into the `models/` directory:
1. `models/dr_grading_resnet50.mat`
2. `models/lesion_unet_multihead.mat`
3. `models/vessel_unet.mat`

The DrishtiSetu clinical application automatically detects the newly trained checkpoint on launch and switches from classical morphological fallback to deep learning inference seamlessly!
