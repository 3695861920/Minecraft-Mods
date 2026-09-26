@echo off
rem Launches the development client so model/texture loading is validated for real.
rem Captures the log; the caller greps it and then kills the java process.
cd /d "%~dp0.."
call gradlew.bat runClient --console=plain > "%~dp0client.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%~dp0client.log"
