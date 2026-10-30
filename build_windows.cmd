@echo off
rem Builds and starts the Windows launcher with the Liquid Glass renderer.
rem   build_windows.cmd            build, then start
rem   build_windows.cmd --no-run   build only
rem vcpkg: uses core\cmake\vcpkg when present, otherwise %VCPKG_ROOT%.
rem   git clone https://github.com/microsoft/vcpkg core\cmake\vcpkg
setlocal
cd /d "%~dp0core"
set "QT_ROOT=C:\Qt\6.12.0\msvc2022_64"
set "BUILD_DIR=%CD%\build-win11"
rem Executable names: VitraLauncher.exe, VitraLauncher_updater.exe, VitraLauncher_filelink.exe.
set "BINARY_NAME=VitraLauncher"
set "LAUNCHER_EXE=%BUILD_DIR%\Release\%BINARY_NAME%.exe"
rem Prism's Java helpers target Java 7 bytecode, which JDK 21+ javac rejects.
set "JDK17=C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot"
if exist "%JDK17%\bin\javac.exe" set "JAVA_HOME=%JDK17%"
rem Kept in its own variable: vcvars64.bat replaces VCPKG_ROOT with the
rem Visual Studio bundled vcpkg.
set "PG_VCPKG=%VCPKG_ROOT%"
if exist "%CD%\cmake\vcpkg\scripts\buildsystems\vcpkg.cmake" set "PG_VCPKG=%CD%\cmake\vcpkg"
if not defined PG_VCPKG goto no_vcpkg
if not exist "%PG_VCPKG%\scripts\buildsystems\vcpkg.cmake" goto no_vcpkg
rem The running launcher locks its executable; stop rather than half-update.
powershell.exe -NoProfile -Command "$ErrorActionPreference='Stop'; if (Test-Path -LiteralPath $env:LAUNCHER_EXE) { try { $f=[System.IO.File]::Open($env:LAUNCHER_EXE,'Open','Write','ReadWrite'); $f.Dispose() } catch { exit 1 } }"
if errorlevel 1 goto in_use
set "PATH=C:\Qt\Tools\CMake_64\bin;C:\Qt\Tools\Ninja;%QT_ROOT%\bin;%PATH%"
where cl >nul 2>nul
if errorlevel 1 call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
set "VCPKG_ROOT=%PG_VCPKG%"
rem Updater: checks the GitHub releases of PG_UPDATER_REPO for assets whose
rem names contain PG_BUILD_ARTIFACT ("windows-msvc"); package_windows.ps1
rem builds such an asset.
if not defined PG_UPDATER_REPO set "PG_UPDATER_REPO=https://github.com/Davizcbia/Vitra-Launcher"
if not defined PG_BUILD_ARTIFACT set "PG_BUILD_ARTIFACT=Windows-MSVC"
rem Passed every run so an old cached value (the upstream Prism repository)
rem can never survive in build-win11.
rem CurseForge: off unless PG_CURSEFORGE_API_KEY is set (never commit the key).
if not defined PG_CURSEFORGE_API_KEY echo PG_CURSEFORGE_API_KEY is not set; building without CurseForge.
cmake --preset default -B "%BUILD_DIR%" -DCMAKE_PREFIX_PATH=%QT_ROOT:\=/% ^
    "-DLauncher_UPDATER_GITHUB_REPO=%PG_UPDATER_REPO%" "-DLauncher_BUILD_ARTIFACT=%PG_BUILD_ARTIFACT%" ^
    "-DLauncher_CURSEFORGE_API_KEY=%PG_CURSEFORGE_API_KEY%" "-DLauncher_APP_BINARY_NAME=%BINARY_NAME%" ^
    "-DCMAKE_TOOLCHAIN_FILE=%PG_VCPKG%\scripts\buildsystems\vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-windows ^
    -DLauncher_WARNING_AS_ERROR=OFF -DENABLE_LTO=OFF -DBUILD_TESTING=OFF ^
    "-DJava_JAVA_EXECUTABLE=%JAVA_HOME%\bin\java.exe" "-DJava_JAVAC_EXECUTABLE=%JAVA_HOME%\bin\javac.exe" "-DJava_JAR_EXECUTABLE=%JAVA_HOME%\bin\jar.exe"
if errorlevel 1 goto failed
cmake --build "%BUILD_DIR%" --config Release --parallel 16
if errorlevel 1 goto failed
rem Runtime files beside the executable, so Release\VitraLauncher.exe also
rem starts by double-click: Java helper jars, Qt and QML modules, and vcpkg
rem DLLs if a dynamic triplet is used (the bundled triplet links statically).
set "RELEASE_DIR=%BUILD_DIR%\Release"
if exist "%BUILD_DIR%\vcpkg_installed\x64-windows\bin\*.dll" xcopy /y /q "%BUILD_DIR%\vcpkg_installed\x64-windows\bin\*.dll" "%RELEASE_DIR%\" >nul
xcopy /y /q /i "%BUILD_DIR%\jars\*.jar" "%RELEASE_DIR%\jars\" >nul
if errorlevel 1 goto failed
windeployqt --release --no-translations --qmldir "%CD%\launcher\project-glass" "%LAUNCHER_EXE%" >nul
if errorlevel 1 goto failed
if /i "%~1"=="--no-run" exit /b 0
set "QSG_RHI_BACKEND=d3d11"
start "" "%LAUNCHER_EXE%"
exit /b 0
:no_vcpkg
echo vcpkg not found. Clone it into core\cmake\vcpkg or set VCPKG_ROOT:
echo   git clone https://github.com/microsoft/vcpkg core\cmake\vcpkg
exit /b 1
:in_use
echo The launcher is running and its executable is locked:
echo %LAUNCHER_EXE%
echo Close it, then run this script again.
exit /b 1
:failed
echo Build failed. Copy the first error and send it for review.
if /i "%~1"=="--no-run" exit /b 1
pause
exit /b 1
