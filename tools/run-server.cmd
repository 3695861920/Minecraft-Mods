@echo off
rem Runs the dedicated test server and writes a clean log for inspection.
rem Kept as a .cmd file so PowerShell never has to quote this command line.
cd /d "%~dp0.."
call gradlew.bat runServer --console=plain > "%~dp0server.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%~dp0server.log"
