@echo off
echo "This is intended to be used with OpenStudio 3.6.1"
REM add -m below to run measures only
echo "Running OpenStudio Standards 90.1-2016 model test"
openstudio run -w ./model_90_1_2016/workflow.osw
echo "Running VEIC OpenStudio Standards w/ custom VT CBES model test"
openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ run -w ./model_vt_cbes/workflow.osw
pause