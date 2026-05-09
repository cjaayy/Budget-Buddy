@echo off
setlocal EnableExtensions EnableDelayedExpansion
title BudgetBuddy Launcher
color 0A

rem ==========================================================================
rem BudgetBuddy Flutter launcher for Windows 10/11
rem - Detects the project root automatically
rem - Detects Flutter and Android SDK paths
rem - Writes android\local.properties when needed
rem - Runs flutter pub get automatically
rem - Detects USB or wireless Android devices through adb
rem - Supports debug, release, APK, AAB, uninstall, and wireless reconnect
rem ==========================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"
set "APP_ID=com.budgetbuddy.app"
set "WIRELESS_FILE=%SCRIPT_DIR%.budgetbuddy_wireless"
set "APK_DIR=%PROJECT_DIR%build\app\outputs\flutter-apk"
set "AAB_DIR=%PROJECT_DIR%build\app\outputs\bundle\release"
set "DEVICE_ID="
set "FLUTTER_BAT="
set "ADB_EXE="
set "ANDROID_SDK="
set "FLUTTER_SDK="

call :FindProjectRoot
if not exist "%PROJECT_DIR%pubspec.yaml" (
    call :Error "Unable to find pubspec.yaml. Place this script inside the BudgetBuddy project root."
    pause
    exit /b 1
)

call :DetectFlutter
if errorlevel 1 (
    pause
    exit /b 1
)

call :DetectAndroidSdk
if errorlevel 1 (
    pause
    exit /b 1
)

call :WriteLocalProperties
call :RunPubGet
call :AutoReconnectWireless
call :DetectDevice

:MenuLoop
cls
call :ShowHeader
call :ShowSystemSpecs
echo.
echo Project: %PROJECT_DIR%
echo Flutter : %FLUTTER_BAT%
echo ADB     : %ADB_EXE%
echo Device  : %DEVICE_ID%
echo.
echo  1. Launch App
echo  2. Restart App
echo  3. Debug Run (Hot Reload)
echo  4. Release Run
echo  5. Clean Rebuild
echo  6. Build APK
echo  7. Build App Bundle
echo  8. Flutter Doctor
echo  9. View Connected Devices
echo 10. Open APK Folder
echo 11. Uninstall App
echo 12. Disconnect Wireless
echo 13. Guided Wireless Pairing
echo  0. Exit
echo.
set /p "CHOICE=Select an option: "

if "%CHOICE%"=="1" call :LaunchDebugRun && goto MenuLoop
if "%CHOICE%"=="2" call :RestartApp && goto MenuLoop
if "%CHOICE%"=="3" call :StartHotReloadRun && goto MenuLoop
if "%CHOICE%"=="4" call :StartReleaseRun && goto MenuLoop
if "%CHOICE%"=="5" call :CleanRebuild && goto MenuLoop
if "%CHOICE%"=="6" call :BuildApk && goto MenuLoop
if "%CHOICE%"=="7" call :BuildAppBundle && goto MenuLoop
if "%CHOICE%"=="8" call :FlutterDoctor && goto MenuLoop
if "%CHOICE%"=="9" call :ShowDevices && goto MenuLoop
if "%CHOICE%"=="10" call :OpenApkFolder && goto MenuLoop
if "%CHOICE%"=="11" call :UninstallApp && goto MenuLoop
if "%CHOICE%"=="12" call :DisconnectWireless && goto MenuLoop
if "%CHOICE%"=="13" call :GuidedWirelessPairing && goto MenuLoop
if "%CHOICE%"=="0" goto :EOF

call :Warn "Invalid choice. Please select a menu option."
timeout /t 1 /nobreak >nul
goto MenuLoop

:FindProjectRoot
for %%P in ("%SCRIPT_DIR%." "%SCRIPT_DIR%.." "%SCRIPT_DIR%..\..") do (
    if exist "%%~fP\pubspec.yaml" set "PROJECT_DIR=%%~fP\"
)
goto :EOF

:DetectFlutter
if defined FLUTTER_ROOT (
    set "FLUTTER_BAT=%FLUTTER_ROOT%\bin\flutter.bat"
)
if not defined FLUTTER_BAT (
    for /f "usebackq delims=" %%F in (`where flutter 2^>nul`) do (
        if not defined FLUTTER_BAT set "FLUTTER_BAT=%%F"
    )
)
if not exist "%FLUTTER_BAT%" (
    call :Error "Flutter was not found. Install Flutter and make sure it is in PATH."
    exit /b 1
)
for %%F in ("%FLUTTER_BAT%\..\..") do set "FLUTTER_SDK=%%~fF"
exit /b 0

:DetectAndroidSdk
if defined ANDROID_SDK_ROOT set "ANDROID_SDK=%ANDROID_SDK_ROOT%"
if not defined ANDROID_SDK if defined ANDROID_HOME set "ANDROID_SDK=%ANDROID_HOME%"
if not defined ANDROID_SDK (
    if exist "%LOCALAPPDATA%\Android\Sdk" set "ANDROID_SDK=%LOCALAPPDATA%\Android\Sdk"
)
if not defined ANDROID_SDK (
    for /f "usebackq delims=" %%A in (`where adb 2^>nul`) do (
        if not defined ADB_EXE set "ADB_EXE=%%A"
    )
    if defined ADB_EXE (
        for %%A in ("%ADB_EXE%\..") do set "ANDROID_SDK=%%~fA\.."
    )
)
if not defined ANDROID_SDK (
    call :Error "Android SDK was not found. Set ANDROID_SDK_ROOT or install platform-tools."
    exit /b 1
)
if not defined ADB_EXE set "ADB_EXE=%ANDROID_SDK%\platform-tools\adb.exe"
if not exist "%ADB_EXE%" (
    for /f "usebackq delims=" %%A in (`where adb 2^>nul`) do (
        if not defined ADB_EXE set "ADB_EXE=%%A"
    )
)
if not exist "%ADB_EXE%" (
    call :Error "adb was not found in the Android SDK platform-tools folder."
    exit /b 1
)
exit /b 0

:WriteLocalProperties
set "ANDROID_ESC=%ANDROID_SDK:\=\\%"
set "FLUTTER_ESC=%FLUTTER_SDK:\=\\%"
if not exist "%PROJECT_DIR%android" mkdir "%PROJECT_DIR%android" >nul 2>&1
>"%PROJECT_DIR%android\local.properties" (
    echo sdk.dir=%ANDROID_ESC%
    echo flutter.sdk=%FLUTTER_ESC%
)
exit /b 0

:RunPubGet
call :Info "Running flutter pub get..."
pushd "%PROJECT_DIR%"
"%FLUTTER_BAT%" pub get
if errorlevel 1 (
    popd
    call :Error "flutter pub get failed."
    exit /b 1
)
popd
exit /b 0

:DetectDevice
set "DEVICE_ID="
for /f "usebackq tokens=1" %%D in (`"%ADB_EXE%" devices ^| findstr /R "device$"`) do (
    if not defined DEVICE_ID set "DEVICE_ID=%%D"
)
if not defined DEVICE_ID (
    for /f "usebackq delims=" %%H in ("%WIRELESS_FILE%") do (
        if not defined DEVICE_ID set "DEVICE_ID=%%H"
    )
)
if defined DEVICE_ID (
    "%ADB_EXE%" connect %DEVICE_ID% >nul 2>&1
)
if not defined DEVICE_ID (
    call :Warn "No connected device detected. Use option 13 to pair a wireless device or connect USB debugging."
)
exit /b 0

:AutoReconnectWireless
if not exist "%WIRELESS_FILE%" exit /b 0
for /f "usebackq delims=" %%H in ("%WIRELESS_FILE%") do (
    call :Info "Trying to reconnect wireless device %%H..."
    "%ADB_EXE%" connect %%H >nul 2>&1
)
exit /b 0

:ShowHeader
echo ============================================================
echo  BudgetBuddy Flutter Launcher
echo ============================================================
exit /b 0

:ShowSystemSpecs
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "Get-CimInstance Win32_Processor ^| Select-Object -First 1 -ExpandProperty Name"`) do set "CPU_NAME=%%L"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "[Math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)"`) do set "RAM_GB=%%L"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "Get-CimInstance Win32_VideoController ^| Select-Object -First 1 -ExpandProperty Name"`) do set "GPU_NAME=%%L"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem ^| Select-Object -ExpandProperty Caption"`) do set "OS_NAME=%%L"
for /f "usebackq delims=" %%L in (`powershell -NoProfile -Command "Get-PSDrive -Name C ^| ForEach-Object { '{0:N1} GB free of {1:N1} GB' -f ($_.Free / 1GB), (($_.Free + $_.Used) / 1GB) }"`) do set "DISK_C=%%L"
echo CPU   : %CPU_NAME%
echo RAM   : %RAM_GB% GB
echo GPU   : %GPU_NAME%
echo Disk  : %DISK_C%
echo OS    : %OS_NAME%
exit /b 0

:LaunchDebugRun
call :EnsureDevice
if errorlevel 1 exit /b 1
call :StartFlutterRun debug
exit /b 0

:StartHotReloadRun
call :EnsureDevice
if errorlevel 1 exit /b 1
call :StartFlutterRun debug
exit /b 0

:StartReleaseRun
call :EnsureDevice
if errorlevel 1 exit /b 1
call :StartFlutterRun release
exit /b 0

:RestartApp
call :EnsureDevice
if errorlevel 1 exit /b 1
call :Info "Stopping the app on the connected device..."
"%ADB_EXE%" -s %DEVICE_ID% shell am force-stop %APP_ID% >nul 2>&1
call :StartFlutterRun debug
exit /b 0

:StartFlutterRun
set "MODE=%~1"
pushd "%PROJECT_DIR%"
if /i "%MODE%"=="release" (
    "%FLUTTER_BAT%" run --release -d %DEVICE_ID%
) else (
    "%FLUTTER_BAT%" run -d %DEVICE_ID%
)
popd
call :Info "Flutter run (%MODE%) finished. Use r / R inside the Flutter session for hot reload / restart."
exit /b 0

:CleanRebuild
call :Info "Cleaning Flutter build artifacts..."
pushd "%PROJECT_DIR%"
"%FLUTTER_BAT%" clean
if errorlevel 1 (
    popd
    call :Error "flutter clean failed."
    exit /b 1
)
"%FLUTTER_BAT%" pub get
popd
exit /b 0

:BuildApk
call :EnsureDeviceOptional
call :Info "Building release APK..."
pushd "%PROJECT_DIR%"
"%FLUTTER_BAT%" build apk --release
if errorlevel 1 (
    popd
    call :Error "APK build failed."
    exit /b 1
)
popd
start "" explorer "%APK_DIR%"
exit /b 0

:BuildAppBundle
call :Info "Building release App Bundle..."
pushd "%PROJECT_DIR%"
"%FLUTTER_BAT%" build appbundle --release
if errorlevel 1 (
    popd
    call :Error "App Bundle build failed."
    exit /b 1
)
popd
start "" explorer "%AAB_DIR%"
exit /b 0

:FlutterDoctor
pushd "%PROJECT_DIR%"
"%FLUTTER_BAT%" doctor -v
popd
exit /b 0

:ShowDevices
echo.
echo adb devices:
"%ADB_EXE%" devices -l
echo.
echo flutter devices:
pushd "%PROJECT_DIR%"
"%FLUTTER_BAT%" devices
popd
exit /b 0

:OpenApkFolder
if not exist "%APK_DIR%" (
    call :Warn "APK folder does not exist yet. Build the APK first."
    exit /b 0
)
start "" explorer "%APK_DIR%"
exit /b 0

:UninstallApp
call :EnsureDevice
if errorlevel 1 exit /b 1
call :Info "Uninstalling %APP_ID% from %DEVICE_ID%..."
"%ADB_EXE%" -s %DEVICE_ID% uninstall %APP_ID%
exit /b 0

:DisconnectWireless
call :Info "Disconnecting wireless adb sessions..."
"%ADB_EXE%" disconnect >nul 2>&1
if exist "%WIRELESS_FILE%" del "%WIRELESS_FILE%" >nul 2>&1
exit /b 0

:GuidedWirelessPairing
echo.
echo Follow these steps on your Android device:
echo 1. Open Developer Options.
echo 2. Turn on Wireless debugging.
echo 3. Tap Pair device with pairing code.
echo.
set /p "PAIR_HOST=Enter pairing host:port from the pairing screen: "
set /p "PAIR_CODE=Enter pairing code: "
set /p "CONNECT_HOST=Enter the connect host:port from Wireless debugging: "
if "%PAIR_HOST%"=="" goto :EOF
if "%CONNECT_HOST%"=="" set "CONNECT_HOST=%PAIR_HOST%"
call :Info "Running adb pair..."
"%ADB_EXE%" pair %PAIR_HOST% %PAIR_CODE%
call :Info "Running adb connect..."
"%ADB_EXE%" connect %CONNECT_HOST%
>"%WIRELESS_FILE%" echo %CONNECT_HOST%
call :DetectDevice
exit /b 0

:EnsureDevice
call :DetectDevice
if defined DEVICE_ID exit /b 0
call :Warn "No device detected. Connect a USB device or use option 13 for wireless pairing."
exit /b 1

:EnsureDeviceOptional
call :DetectDevice
if defined DEVICE_ID exit /b 0
call :Warn "No device detected right now. Build outputs can still be generated, but app launch will need a device later."
exit /b 0

:Info
echo [INFO] %~1
exit /b 0

:Warn
echo [WARN] %~1
exit /b 0

:Error
echo [ERROR] %~1
exit /b 0