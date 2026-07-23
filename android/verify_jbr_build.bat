@echo off
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d "%~dp0"
echo JAVA_HOME=%JAVA_HOME%
echo PATH=%PATH% | findstr /i "java.exe"
java -version
javac -version
gradlew.bat --no-daemon clean assembleDebug --stacktrace --console=plain
