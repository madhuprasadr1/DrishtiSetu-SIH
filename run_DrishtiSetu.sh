#!/usr/bin/env bash
# ===============================================================================
# DrishtiSetu MVP: Linux/macOS Launch Script
# Explainable AI for Diabetic Retinopathy Screening in Rural India
# ===============================================================================

echo "==============================================================================="
echo "DRISHTISETU: Clinical Retinal Screening Workstation (Offline-First)"
echo "Initializing MATLAB environment..."
echo "==============================================================================="

MATLAB_BIN=$(which matlab 2>/dev/null || echo "/usr/local/bin/matlab")

if [ ! -x "$MATLAB_BIN" ]; then
    echo "Error: MATLAB executable not found in PATH."
    exit 1
fi

"$MATLAB_BIN" -nodesktop -nosplash -r "try, run('main_DrishtiSetu.m'); catch ME, fprintf('Startup Error: %s\n', ME.message); exit(1); end"
