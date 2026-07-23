@echo off
cd /d "%~dp0"
set "JAVA_HOME=C:\Progra~1\Java\jdk-22"
set "PATH=%JAVA_HOME%\bin;%PATH%"
echo [TEST] JAVA_HOME=%JAVA_HOME%
where java
"%JAVA_HOME%\bin\java.exe" -version
call gradlew.bat --no-daemon -Dorg.gradle.java.home=C:\Progra~1\Java\jdk-22 assembleDebug --stacktrace
pause
