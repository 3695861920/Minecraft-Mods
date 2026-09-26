@echo off
rem Runs the in-game test suite; the server starts, runs the tests and exits by itself.
rem
rem The run tasks belong to a target module, not to the root project, since the repository became multi target.
rem TFC_TARGET selects which one and defaults to the only target that exists.
setlocal
cd /d "%~dp0.."
if "%TFC_TARGET%"=="" set TFC_TARGET=neoforge-26.1.2
call gradlew.bat :versions:%TFC_TARGET%:runGameTestServer --console=plain > "%~dp0gametest.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%~dp0gametest.log"
endlocal
