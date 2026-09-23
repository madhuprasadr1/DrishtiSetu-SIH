# Model Card: DrishtiSetu Diabetic Retinopathy Screening Engine

## 1. Model Details
- **Model Name**: DrishtiSetu DR Screening Ensemble
- **Version**: 1.0.0 (MVP)
- **Primary Architecture**: 5-Level Deep ResNet-50 Convolutional Neural Network with Temperature-Scaled Softmax.
- **Auxiliary Heads**: U-Net Morphological Pathology Heads (Microaneurysms, Hemorrhages, Hard Exudates, Cotton Wool Spots) and Morphological Matched Filter Vessel Segmenter.
- **Rule Engine**: International Clinical Diabetic Retinopathy (ICDR) 4-2-1 Decision Logic Seam.
- **Developer**: DrishtiSetu Engineering Team

---

## 2. Intended Clinical Use
- **Application**: Community-based screening decision support for diabetic retinopathy in resource-constrained primary care environments.
- **Target Users**: Trained Community Health Workers (ASHAs), Ophthalmic Technicians, General Duty Medical Officers (GDMOs), and Tele-Ophthalmologists.
- **Target Population**: Adults ($\ge 18$ years) with diagnosed Type 1 or Type 2 Diabetes Mellitus undergoing routine annual retinal examination.
- **Setting**: Primary Health Centres (PHCs), Community Health Centres (CHCs), Sub-Centres, and Mobile Screening Units.

---

## 3. Contraindications & Limitations
- **Not for Autonomous Diagnosis**: DrishtiSetu provides screening triage and decision support. It does not replace a comprehensive dilated eye examination by a vitreoretinal specialist.
- **Non-Diabetic Retinopathies**: Retinal vascular occlusions, severe hypertensive retinopathy, and age-related macular degeneration (AMD) may exhibit overlapping morphological signs. The system flags atypical presentations for human escalation.
- **Media Opacities**: Dense cataracts, vitreous hemorrhage, or corneal scars that obscure retinal landmarks trigger the automatic quality gate (`RECAPTURE_REQUIRED`).
- **Pediatric Screening**: Not validated for pediatric retinal diseases or retinopathy of prematurity (ROP).

---

## 4. Architectural Fallbacks & Offline Resilience
When external deep learning checkpoints or GPU accelerators are unavailable, DrishtiSetu transitions gracefully to its deterministic, classical computer vision pipeline:
- **Lesion Detection**: Multi-scale morphological top-hat filtering and adaptive intensity clustering.
- **Vessel Segmentation**: Multi-orientation matched Gaussian filters and skeletonization.
- **Grading**: Quantitative ICDR rule engine evaluating lesion counts, quadrant distribution, and foveal proximity.
- **Audit Flagging**: All fallback inferences are explicitly logged with `isFallback = true` in the canonical result object.

---

## 5. Calibration & Uncertainty
- **Calibration Method**: Post-hoc Temperature Scaling ($T \approx 1.2$).
- **Calibration Objective**: Minimize Expected Calibration Error (ECE) to ensure that a predicted probability of 0.80 corresponds to an empirical 80% likelihood of referable disease.
- **Uncertainty Metric**: Normalized Shannon Entropy:
  $$H_{\text{norm}}(p) = -\frac{1}{\log_2(5)} \sum_{c=0}^{4} p_c \log_2(p_c)$$
  Cases with $H_{\text{norm}} \ge 0.50$ are automatically routed to `ESCALATE_HUMAN_REVIEW`.

---

## 6. Out-of-Distribution (OOD) Detection
- Anomaly detector monitors:
  1. FOV circularity and aspect ratio.
  2. Red-to-green channel chromaticity ratio ($R/G \ge 1.15$ in normal human fundus).
  3. Spatial illumination uniformity across outer periphery.
- Deviations automatically trip the safety gate to `HUMAN_REVIEW_REQUIRED`.
