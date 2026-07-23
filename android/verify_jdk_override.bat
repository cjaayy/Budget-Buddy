@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion
set "JAVA_HOME=C:\Progra~1\Java\jdk-22"
set "PATH=!JAVA_HOME!\bin;!PATH!"
echo JAVA_HOME=!JAVA_HOME!
where java
gradlew.bat --no-daemon --version
