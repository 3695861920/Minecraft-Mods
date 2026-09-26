@echo off
rem Launches the development client so model/texture loading is validated for real.
rem Captures the log; the caller greps it and then kills the java process.
rem
rem The run tasks belong to a target module, not to the root project, since the repository became multi target.
rem TFC_TARGET selects which one and defaults to the only target that exists.
setlocal
cd /d "%~dp0.."
if "%TFC_TARGET%"=="" set TFC_TARGET=neoforge-26.1.2
call gradlew.bat :versions:%TFC_TARGET%:runClient --console=plain > "%~dp0client.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%~dp0client.log"
endlocal
