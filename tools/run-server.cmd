@echo off
rem Runs the dedicated test server and writes a clean log for inspection.
rem Kept as a .cmd file so PowerShell never has to quote this command line.
rem
rem The run tasks belong to a target module, not to the root project, since the repository became multi target.
rem TFC_TARGET selects which one and defaults to the only target that exists.
setlocal
cd /d "%~dp0.."
if "%TFC_TARGET%"=="" set TFC_TARGET=neoforge-26.1.2
call gradlew.bat :versions:%TFC_TARGET%:runServer --console=plain > "%~dp0server.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%~dp0server.log"
endlocal
