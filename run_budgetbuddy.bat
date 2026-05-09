@echo off
setlocal enabledelayedexpansion
title Budget Buddy - Run on Physical Device

cd /d "%~dp0"

if not exist "pubspec.yaml" (
    echo [ERROR] pubspec.yaml not found in %cd%
    echo Please run this script from the Flutter project root folder.
    echo.
    pause
    exit /b 1
)

call :ensure_pub

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "PACKAGE=com.budgetbuddy.app"
set "DEBUG_APK=%cd%\android\app\build\outputs\apk\debug\app-debug.apk"
set "RELEASE_APK=%cd%\android\app\build\outputs\apk\release\app-release.apk"
set "GRADLEW=%cd%\android\gradlew.bat"
set "ANDROID_DIR=%cd%\android"

echo ========================================
echo    Budget Buddy - Physical Device Run
echo ========================================
echo.
echo -------- System Specs --------
powershell -NoProfile -Command ^
    "$os = Get-CimInstance Win32_OperatingSystem; " ^
    "$cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name; " ^
    "$gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name; " ^
    "$ram = [math]::Round($os.TotalVisibleMemorySize/1MB,1); " ^
    "$drive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':'); " ^
    "$free = [math]::Round($drive.Free/1GB,1); " ^
    "$size = [math]::Round(($drive.Free + $drive.Used)/1GB,1); " ^
    "Write-Host \"OS: $($os.Caption) $($os.Version)\"; " ^
    "Write-Host \"CPU: $cpu\"; " ^
    "Write-Host \"RAM: $ram GB\"; " ^
    "Write-Host \"GPU: $gpu\"; " ^
    "Write-Host \"Disk ($($env:SystemDrive)): $free GB free / $size GB\""
echo -----------------------------
echo.

:connection_menu
echo How do you want to connect?
echo   [1] USB (device already connected)
echo   [2] Wireless Debugging (connect via WiFi)
echo   [3] Already connected wirelessly
echo.
set /p "CONN_TYPE=Enter choice (1-3): "

if "%CONN_TYPE%"=="2" goto wireless_connect
if "%CONN_TYPE%"=="3" goto check_device
if "%CONN_TYPE%"=="1" goto check_device
echo Invalid choice.
echo.
goto connection_menu

:wireless_connect
echo.
echo ========================================
echo   Wireless Debugging Setup
echo ========================================
echo.
echo How do you want to pair?
echo   [1] Guided Setup (recommended)
echo   [2] Quick Manual (enter IP and code directly)
echo   [3] Skip pairing (already paired before)
echo.
set /p "PAIR_METHOD=Enter choice (1-3): "

if "%PAIR_METHOD%"=="1" goto wireless_guided
if "%PAIR_METHOD%"=="2" goto wireless_manual
if "%PAIR_METHOD%"=="3" goto wireless_direct
echo Invalid choice.
goto wireless_connect

:wireless_guided
echo.
echo On your phone, tap "Pair device with pairing code"
echo.
echo Enter the PAIRING address (e.g., 192.168.1.100:37215):
set /p "PAIR_ADDR="
echo Enter the PAIRING code shown on device:
set /p "PAIR_CODE="
echo.
echo Pairing with device...
"%ADB%" pair %PAIR_ADDR% %PAIR_CODE%
if errorlevel 1 (
    echo.
    echo [ERROR] Pairing failed! Check the address and code.
    echo.
    goto connection_menu
)
echo.
echo Pairing successful!
echo.
goto wireless_direct

:wireless_manual
echo.
echo On your phone, tap "Pair device with pairing code"
echo.
echo Enter the PAIRING address (e.g., 192.168.1.100:37215):
set /p "PAIR_ADDR="
echo Enter the PAIRING code shown on device:
set /p "PAIR_CODE="
echo.
echo Pairing with device...
"%ADB%" pair %PAIR_ADDR% %PAIR_CODE%
if errorlevel 1 (
    echo.
    echo [ERROR] Pairing failed! Check the address and code.
    echo.
    goto connection_menu
)
echo.
echo Pairing successful!
echo.

:wireless_direct
echo.
echo Now enter the CONNECT address from Wireless debugging screen
echo (This is different from the pairing address, e.g., 192.168.1.100:43567):
set /p "CONNECT_ADDR="
echo.
echo Connecting to device...
"%ADB%" connect %CONNECT_ADDR%
if errorlevel 1 (
    echo.
    echo [ERROR] Connection failed!
    echo.
    goto connection_menu
)
echo.
timeout /t 2 /nobreak >nul

:check_device
echo.
echo Checking for Android device...
echo.

REM Extract device ID using PowerShell
for /f "usebackq delims=" %%i in (`powershell -Command "(flutter devices | Select-String 'mobile.*android' | ForEach-Object { ($_ -split '•')[1].Trim() } | Select-Object -First 1)"`) do set "DEVICE_ID=%%i"

if "%DEVICE_ID%"=="" (
    echo [ERROR] No physical Android device found!
    echo.
    echo Please make sure:
    echo   - For USB: Device connected and USB debugging enabled
    echo   - For Wireless: Device paired and connected via adb
    echo.
    echo Available devices:
    flutter devices
    echo.
    pause
    goto connection_menu
)

echo Found device: %DEVICE_ID%
echo.

REM Check if app is already installed
"%ADB%" -s %DEVICE_ID% shell pm list packages | findstr /i "%PACKAGE%" >nul 2>&1
if errorlevel 1 (
    echo App not installed. Building and installing...
    echo.
    goto buildrun
)

:menu
echo ----------------------------------------
echo Select an option:
echo.
echo   QUICK ACTIONS:
echo   [1] Launch App
echo   [2] Restart App (force stop + launch)
echo.
echo   DEBUG MODE (Hot Reload):
echo   [3] Debug Run (r=hot reload, R=hot restart)
echo.
echo   RELEASE MODE:
echo   [4] Release Build ^& Run
echo   [5] Clean Release Build
echo.
echo   SHARE:
echo   [6] Build APK ^& Open Folder (share manually)
echo.
echo   OTHER:
echo   [7] Uninstall App
echo   [8] Disconnect Wireless ^& Reconnect
echo   [0] Exit
echo ----------------------------------------
echo.
set /p "CHOICE=Enter choice (1-8, 0): "

if "%CHOICE%"=="1" goto launch
if "%CHOICE%"=="2" goto restart
if "%CHOICE%"=="3" goto debugrun
if "%CHOICE%"=="4" goto buildrun
if "%CHOICE%"=="5" goto cleanrebuild
if "%CHOICE%"=="6" goto buildapk
if "%CHOICE%"=="7" goto uninstall
if "%CHOICE%"=="8" goto disconnect
if "%CHOICE%"=="0" exit /b 0
echo Invalid choice. Please enter 1-8 or 0.
echo.
goto menu

:launch
echo.
echo Launching app...
"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo App launched!
echo.
goto menu

:restart
echo.
echo Restarting app...
"%ADB%" -s %DEVICE_ID% shell am force-stop %PACKAGE%
timeout /t 1 /nobreak >nul
"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo App restarted!
echo.
goto menu

:debugrun
echo.
echo ========================================
echo   DEBUG MODE - Hot Reload Enabled
echo ========================================
echo.
echo   While running, press:
echo     r = Hot Reload (update UI instantly)
echo     R = Hot Restart (restart app state)
echo     q = Quit
echo.
echo ========================================
echo.

pushd "%ANDROID_DIR%"
call gradlew.bat assembleDebug
set "GRADLE_STATUS=%ERRORLEVEL%"
popd
if not "%GRADLE_STATUS%"=="0" (
	echo.
	echo [ERROR] Debug build failed!
	echo.
	goto menu
)

if not exist "%DEBUG_APK%" (
	echo.
	echo [ERROR] Debug APK not found at:
	echo   %DEBUG_APK%
	echo.
	goto menu
)

flutter run -d %DEVICE_ID% --use-application-binary "%DEBUG_APK%"
echo.
goto menu

:buildrun
echo.
echo Building and installing app (debug)...
echo.

pushd "%ANDROID_DIR%"
call gradlew.bat assembleDebug
set "GRADLE_STATUS=%ERRORLEVEL%"
popd
if not "%GRADLE_STATUS%"=="0" (
	echo.
	echo [ERROR] Debug build failed!
	echo.
	goto menu
)

if not exist "%DEBUG_APK%" (
	echo.
	echo [ERROR] Debug APK not found at:
	echo   %DEBUG_APK%
	echo.
	goto menu
)

"%ADB%" -s %DEVICE_ID% install -r "%DEBUG_APK%"
if errorlevel 1 (
	echo.
	echo [ERROR] APK install failed!
	echo.
	goto menu
)

"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo App installed and launched!
echo.
goto menu

:cleanrebuild
echo.
echo Cleaning and rebuilding app...
echo.
flutter clean
flutter pub get

pushd "%ANDROID_DIR%"
call gradlew.bat assembleRelease
set "GRADLE_STATUS=%ERRORLEVEL%"
popd
if not "%GRADLE_STATUS%"=="0" (
	echo.
	echo [ERROR] Release build failed!
	echo.
	goto menu
)

if not exist "%RELEASE_APK%" (
	echo.
	echo [ERROR] Release APK not found at:
	echo   %RELEASE_APK%
	echo.
	goto menu
)

"%ADB%" -s %DEVICE_ID% install -r "%RELEASE_APK%"
if errorlevel 1 (
	echo.
	echo [ERROR] Release APK install failed!
	echo.
	goto menu
)

"%ADB%" -s %DEVICE_ID% shell am start -n %PACKAGE%/.MainActivity
echo.
goto menu

:uninstall
echo.
echo Uninstalling app...
"%ADB%" -s %DEVICE_ID% uninstall %PACKAGE%
echo App uninstalled!
echo.
goto menu

:buildapk
echo.
echo ========================================
echo   Build APK for Sharing
echo ========================================
echo.
echo Building release APK...

pushd "%ANDROID_DIR%"
call gradlew.bat assembleRelease
set "GRADLE_STATUS=%ERRORLEVEL%"
popd
if not "%GRADLE_STATUS%"=="0" (
    echo.
    echo [ERROR] Build failed!
    echo.
    goto menu
)
echo.
echo ========================================
echo   APK built successfully!
echo   Opening folder...
echo ========================================
echo.
explorer "android\app\build\outputs\apk\release"
echo.
echo Send "app-release.apk" to share via WhatsApp, Drive, email, etc.
echo.
goto menu

:disconnect
echo.
echo Disconnecting all wireless devices...
"%ADB%" disconnect
echo.
echo Disconnected. Returning to connection menu...
echo.
set "DEVICE_ID="
goto connection_menu

:ensure_pub
if not exist ".dart_tool\package_config.json" (
    echo.
    echo [INFO] Running flutter pub get...
    flutter pub get
    if errorlevel 1 (
        echo.
        echo [ERROR] flutter pub get failed.
        echo.
        pause
        exit /b 1
    )
)
exit /b 0
[{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
		call android\gradlew.bat assembleRelease
	"code": {
		"value": "unused_local_variable",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/unused_local_variable",
			"scheme": "https",
			"authority": "dart.dev"
		if not exist "%RELEASE_APK%" (
			echo.
			echo [ERROR] Release APK not found at:
			echo   %RELEASE_APK%
			echo.
			goto menu
		)

		}
	},
	"severity": 4,
	"message": "The value of the local variable 'state' isn't used.\nTry removing the variable or using it.",
	"source": "dart",
	"startLineNumber": 53,
		explorer "android\app\build\outputs\apk\release"
	"endLineNumber": 53,
	"endColumn": 31,
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 11,
	"startColumn": 72,
	"endLineNumber": 11,
	"endColumn": 83,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 15,
	"startColumn": 56,
	"endLineNumber": 15,
	"endColumn": 67,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 19,
	"startColumn": 56,
	"endLineNumber": 19,
	"endColumn": 67,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 23,
	"startColumn": 68,
	"endLineNumber": 23,
	"endColumn": 79,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'StateNotifierProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 28,
	"startColumn": 4,
	"endLineNumber": 28,
	"endColumn": 28,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 37,
	"startColumn": 56,
	"endLineNumber": 37,
	"endColumn": 67,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 42,
	"startColumn": 65,
	"endLineNumber": 42,
	"endColumn": 76,
	"tags": [
		2
	],
	"origin": "extHost1"
},{
	"resource": "/c:/Users/mjhay/Desktop/Programming/Visual Studio Code/Android Application/Budget Buddy/lib/core/state/app_controller.dart",
	"owner": "_generated_diagnostic_collection_name_#8",
	"code": {
		"value": "deprecated_member_use",
		"target": {
			"$mid": 1,
			"path": "/diagnostics/deprecated_member_use",
			"scheme": "https",
			"authority": "dart.dev"
		}
	},
	"severity": 2,
	"message": "'ProviderRef' is deprecated and shouldn't be used. will be removed in 3.0.0. Use Ref instead.\nTry replacing the use of the deprecated member with the replacement.",
	"source": "dart",
	"startLineNumber": 52,
	"startColumn": 73,
	"endLineNumber": 52,
	"endColumn": 84,
	"tags": [
		2
	],
	"origin": "extHost1"
}]tter-apk"
set "AAB_DIR=%PROJECT_DIR%\build\app\outputs\bundle\release"
set "DEVICE_ID="
set "FLUTTER_BAT="
set "ADB_EXE="
set "ANDROID_SDK="
set "FLUTTER_SDK="
set "JAVA_BIN="
set "JAVA_VERSION="

call :FindProjectRoot
if not exist "%PROJECT_DIR%\pubspec.yaml" (
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

call :DetectJava
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
        if exist "%%~fP\pubspec.yaml" set "PROJECT_DIR=%%~fP"
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
if not defined FLUTTER_BAT (
    if exist "%USERPROFILE%\flutter\bin\flutter.bat" set "FLUTTER_BAT=%USERPROFILE%\flutter\bin\flutter.bat"
)
if not exist "%FLUTTER_BAT%" (
    call :Error "Flutter was not found. Install Flutter and make sure it is in PATH."
    exit /b 1
)
for %%F in ("%FLUTTER_BAT%") do set "FLUTTER_BIN=%%~dpF"
for %%S in ("%FLUTTER_BIN%..") do set "FLUTTER_SDK=%%~fS"
if not exist "%FLUTTER_SDK%\packages\flutter_tools\gradle" (
    call :Error "Computed flutter.sdk path is invalid: %FLUTTER_SDK%"
    exit /b 1
)
exit /b 0

:DetectJava
set "JAVA_BIN="

rem Prefer Android Studio JBR first, then common JDK 21/17 installs.
if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" (
    set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
    set "JAVA_BIN=%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe"
)

if not defined JAVA_BIN (
    for /d %%J in ("%ProgramFiles%\Eclipse Adoptium\jdk-21*" "%ProgramFiles%\Java\jdk-21*" "%ProgramFiles%\Java\jdk-17*") do (
        if not defined JAVA_BIN if exist "%%~fJ\bin\java.exe" (
            set "JAVA_HOME=%%~fJ"
            set "JAVA_BIN=%%~fJ\bin\java.exe"
        )
    )
)

if not defined JAVA_BIN if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "JAVA_BIN=%JAVA_HOME%\bin\java.exe"

if not defined JAVA_BIN (
    for /f "usebackq delims=" %%J in (`where java 2^>nul`) do (
        if not defined JAVA_BIN set "JAVA_BIN=%%J"
    )
)

if not defined JAVA_BIN (
    call :Error "Java was not found. Install JDK 17 or JDK 21 (Android Studio JBR is recommended)."
    exit /b 1
)

if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"

"%JAVA_BIN%" -version >nul 2>&1
if errorlevel 1 (
    call :Error "Java runtime check failed for %JAVA_BIN%"
    exit /b 1
)

if defined JAVA_HOME (
    call :Info "Using Java runtime from %JAVA_HOME%"
) else (
    call :Info "Using Java runtime from %JAVA_BIN%"
)
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
if not exist "%PROJECT_DIR%\android" mkdir "%PROJECT_DIR%\android" >nul 2>&1
>"%PROJECT_DIR%\android\local.properties" (
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
if /i "%MODE%"=="release" (
    start "BudgetBuddy Release" /d "%PROJECT_DIR%" cmd /k ""%FLUTTER_BAT%" run --release -d "%DEVICE_ID%""
) else (
    start "BudgetBuddy Debug" /d "%PROJECT_DIR%" cmd /k ""%FLUTTER_BAT%" run -d "%DEVICE_ID%""
)
call :Info "Flutter run (%MODE%) launched in a separate console. Use r / R inside that window for hot reload / restart."
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