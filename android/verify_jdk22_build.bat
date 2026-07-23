@echo off
setlocal
set "JAVA_HOME=C:\Program Files\Java\jdk-22"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d "%~dp0"
echo JAVA_HOME=%JAVA_HOME%
java -version
javac -version
echo --- gradlew version ---
gradlew.bat --version
echo --- build start ---
gradlew.bat --no-daemon clean assembleDebug --stacktrace --console=plain > build_verify_jdk22.log 2>&1
echo EXIT=%ERRORLEVEL%
endlocal
