# Clinical Validation Protocol & Performance Benchmark

## 1. Clinical Evaluation Standard
In accordance with international consensus guidelines for automated diabetic retinopathy screening:
- **Referable Diabetic Retinopathy (RDR)**: Defined as ICDR Grade 2 (Moderate NPDR), Grade 3 (Severe NPDR), Grade 4 (PDR), and/or Clinically Significant Macular Edema (CSME).
- **Non-Referable DR**: Defined as ICDR Grade 0 (No DR) or Grade 1 (Mild NPDR without macular edema).

---

## 2. Target Performance Benchmarks

| Metric | Target Acceptance Threshold | Clinical Justification |
| :--- | :--- | :--- |
| **RDR Sensitivity** | $\ge 90.0\%$ | Essential to minimize false negatives and prevent untreated vision loss. |
| **RDR Specificity** | $\ge 85.0\%$ | Prevents overburdening tertiary ophthalmology referral centers with false alarms. |
| **Gradability Rate** | $\ge 92.0\%$ | Maximizes rural throughput; achieved via instant auto-enhancement and feedback. |
| **Area Under ROC (AUC)** | $\ge 0.940$ | High discriminatory ability across all patient demographics. |
| **Expected Calibration Error** | $\le 0.050$ | High reliability of confidence scores in primary health triage. |

---

## 3. Evaluation Modules & Usage

DrishtiSetu includes standalone validation utilities in `validation/`:

### 3.1 Diabetic Retinopathy Classification (`validation/evaluateDR.m`)
Evaluates 5-class multi-class metrics and binary Referable DR metrics:
```matlab
% groundTruth: [N x 1] integer vector (0 to 4)
% predictedProbs: [N x 5] float matrix of calibrated probabilities
metrics = evaluateDR(groundTruth, predictedProbs);

fprintf('RDR Sensitivity: %.2f%%\n', metrics.rdrSensitivity * 100);
fprintf('RDR Specificity: %.2f%%\n', metrics.rdrSpecificity * 100);
fprintf('RDR AUC:         %.3f\n', metrics.rdrAUC);
fprintf('Quadratic Kappa: %.3f\n', metrics.quadraticKappa);
```

### 3.2 Expected Calibration Error (`validation/evaluateCalibration.m`)
Computes ECE across 10 probability bins:
```matlab
ece = evaluateCalibration(groundTruthReferable, predictedReferableProbs, 10);
fprintf('Expected Calibration Error (ECE): %.4f\n', ece);
```

### 3.3 Lesion & Vessel Segmentation (`validation/evaluateLesions.m`, `evaluateVessels.m`)
Calculates Dice Similarity Coefficient, Jaccard Index, Sensitivity, and Specificity against expert pixel-level annotations.

---

## 4. Operational Safety Protocol
In real-world deployment:
1. All cases flagged `HUMAN_REVIEW_REQUIRED` are routed to tele-ophthalmologists.
2. All cases flagged `RECAPTURE_REQUIRED` prompt immediate repeat imaging before the patient leaves the clinic.
3. No patient is discharged without either an automated `AUTO_CLEAR` verification or documented specialist referral ticket.
