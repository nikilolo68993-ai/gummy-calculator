@echo off
setlocal
cd /d "%~dp0"
set "GUMMY_FLUTTER_CMD=%GUMMY_FLUTTER%"
if not defined GUMMY_FLUTTER_CMD set "GUMMY_FLUTTER_CMD=flutter"
call "%GUMMY_FLUTTER_CMD%" pub get
if errorlevel 1 goto :failed
call "%GUMMY_FLUTTER_CMD%" build windows --release
if errorlevel 1 goto :failed
echo Done. Share the entire Release folder, including its DLLs and data folder.
start "" "%~dp0build\windows\x64\runner\Release"
pause
exit /b 0
:failed
echo Build failed. See the error above and README.md.
pause
exit /b 1
