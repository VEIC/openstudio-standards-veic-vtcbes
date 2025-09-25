@echo off
REM This line tests that the openstudio-standards gem version can be loaded correctly
openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ -e "require 'openstudio-standards'" -e "puts OpenstudioStandards::VERSION"

REM This line tests that the openstudio-standards gem can load a script and produce assumptions
openstudio -I C:\OSLibraries\openstudio-standards-veic\lib\ "os_standards_simple.rb"