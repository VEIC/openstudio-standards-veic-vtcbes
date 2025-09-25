@echo off

REM This line tests that the openstudio-standards gem can be loaded into a model for create typical workflows
REM add -m below to run measures only
openstudio run -w ./model_90_1_2016/workflow.osw

openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ run -w ./model_vt_cbes/workflow.osw
pause