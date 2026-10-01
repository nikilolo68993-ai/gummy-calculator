@echo off
setlocal
cd /d "%~dp0"
set "GUMMY_FLUTTER_CMD=%GUMMY_FLUTTER%"
if not defined GUMMY_FLUTTER_CMD set "GUMMY_FLUTTER_CMD=flutter"
call "%GUMMY_FLUTTER_CMD%" --version >nul 2>&1
if errorlevel 1 (
  echo Flutter SDK not found. Install Flutter and add its bin folder to PATH.
  echo https://docs.flutter.dev/install
  echo Or set GUMMY_FLUTTER to the full path to flutter.bat.
  pause
  exit /b 1
)
call "%GUMMY_FLUTTER_CMD%" pub get
if errorlevel 1 goto :failed
call "%GUMMY_FLUTTER_CMD%" run -d windows
if errorlevel 1 goto :failed
exit /b 0
:failed
echo See the error above. Windows builds also need Visual Studio Desktop development with C++.
pause
exit /b 1
