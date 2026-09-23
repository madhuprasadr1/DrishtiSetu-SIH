@echo off
REM ===============================================================================
REM DrishtiSetu MVP: Windows Desktop Launch Script
REM Explainable AI for Diabetic Retinopathy Screening in Rural India
REM ===============================================================================

echo ===============================================================================
echo DRISHTISETU: Clinical Retinal Screening Workstation (Offline-First)
echo Initializing MATLAB environment...
echo ===============================================================================

start "" "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -nodesktop -nosplash -r "try, run('main_DrishtiSetu.m'); catch ME, fprintf('Startup Error: %%s\n', ME.message); end"
