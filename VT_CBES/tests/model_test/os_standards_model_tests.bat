@echo off
echo "This is intended to be used with OpenStudio 3.6.1"
REM add -m below to run measures only
echo "Running OpenStudio Standards 90.1-2016 model test"
@REM openstudio run -w ./model_90_1_2016/workflow.osw
echo "Running VEIC OpenStudio Standards w/ custom VT CBES model test"
openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ run -w ./model_vt_cbes/workflow.osw
echo "Running VEIC OpenStudio Standards w/ custom VT CBES 2020 model test (vs just replacing 2016 files with identical names)"
echo "Assumes OpenStudio Standards v0.4.0 and OpenStudio Extension v0.5.0 are installed in C:\OSLibraries"

@REM openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ -I C:\OSLibraries\openstudio-extension-gem\lib\ run -w ./model_vt_cbes_2020_ref/workflow.osw

pause