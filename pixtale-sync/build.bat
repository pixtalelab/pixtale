@echo off
setlocal
cd /d "%~dp0"

where flutter >nul 2>&1
if errorlevel 1 goto :no_flutter

if not exist "installer.iss" goto :no_script

echo [1/2] Building Windows release...
call flutter build windows --release
if errorlevel 1 goto :fail

set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist "%ISCC%" goto :compile
set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if exist "%ISCC%" goto :compile
for /f "delims=" %%I in ('where ISCC 2^>nul') do (
  if not defined ISCC_FOUND set "ISCC=%%I" & set "ISCC_FOUND=1"
)
if not exist "%ISCC%" goto :no_iscc

:compile
echo [2/2] Building installer...
"%ISCC%" "%~dp0installer.iss"
if errorlevel 1 goto :fail

echo.
echo Setup created:
echo %~dp0dist\pixtale-setup.exe
goto :done

:no_flutter
echo Flutter was not found. Add Flutter to PATH.
goto :fail

:no_script
echo installer.iss was not found. Run this script from the project root.
goto :fail

:no_iscc
echo ISCC.exe was not found. Install Inno Setup 6.
goto :fail

:fail
echo.
echo Packaging failed.
call :pause_if_clicked
exit /b 1

:done
call :pause_if_clicked
exit /b 0

:pause_if_clicked
echo %cmdcmdline% | find /i "%~nx0" >nul
if not errorlevel 1 pause
exit /b 0
