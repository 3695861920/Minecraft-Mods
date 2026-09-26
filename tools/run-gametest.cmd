@echo off
rem Runs the in-game test suite; the server starts, runs the tests and exits by itself.
cd /d "%~dp0.."
call gradlew.bat runGameTestServer --console=plain > "%~dp0gametest.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%~dp0gametest.log"
