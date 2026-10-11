@echo off
setlocal
cd /d "%~dp0"
title Noor AI - Build Android APK

echo.
echo ==========================================
echo        Noor AI - APK Builder
echo ==========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter was not found in PATH.
  echo Install Flutter SDK and add its bin folder to PATH, then reopen VS Code.
  echo Guide: https://docs.flutter.dev/get-started/install/windows
  pause
  exit /b 1
)

echo [1/4] Checking Flutter and Android toolchain...
call flutter doctor
if errorlevel 1 (
  echo Flutter doctor reported a problem. Check the output above.
  pause
  exit /b 1
)

if not exist "android\gradlew.bat" (
  echo [2/4] Android platform files are missing. Generating them...
  call flutter create --platforms=android --project-name noor_ai .
  if errorlevel 1 (
    echo ERROR: Could not generate Android project files.
    pause
    exit /b 1
  )
) else (
  echo [2/4] Android platform files already exist.
)

echo [3/4] Downloading Flutter packages...
call flutter pub get
if errorlevel 1 (
  echo ERROR: flutter pub get failed. Check internet and the error above.
  pause
  exit /b 1
)

echo [4/4] Building release APK...
call flutter build apk --release
if errorlevel 1 (
  echo ERROR: APK build failed. Read the first error shown above.
  pause
  exit /b 1
)

echo.
echo SUCCESS! Your APK is here:
echo %CD%\build\app\outputs\flutter-apk\app-release.apk
echo.
pause
