@echo off

REM This line tests that the openstudio-standards gem can be loaded into a model for create typical workflows
@REM openstudio run -m -w ./model_90_1_2016/workflow.osw

openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ run -m -w ./model_vt_cbes/workflow.osw

@REM 
pause