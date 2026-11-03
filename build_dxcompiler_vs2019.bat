@echo off
if "%~1"=="__INNER__" goto :main
chcp 65001 >nul
cmd /c ""%~f0" __INNER__"
set "RET=%ERRORLEVEL%"
echo.
pause
exit /b %RET%

:main
setlocal EnableDelayedExpansion

echo ============================================================================
echo   DirectXShaderCompiler [dxcompiler] - VS2019 x64 Release Build ^& Install
echo ============================================================================
echo.

REM Switch to repository root directory
set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"
cd /d "%REPO_ROOT%"
if errorlevel 1 (
    echo [ERROR] Failed to cd to repository root: "%REPO_ROOT%"
    exit /b 1
)

if not exist "%REPO_ROOT%\CMakeLists.txt" (
    echo [ERROR] CMakeLists.txt not found in "%REPO_ROOT%"
    exit /b 1
)

REM ============================================================================
REM 1. Locate Visual Studio 2019 and vcvars64.bat
REM ============================================================================
echo [1/7] Checking Visual Studio 2019 environment...

set "VS2019_DIR="
set "PF86=%ProgramFiles(x86)%"
set "VSWHERE=%PF86%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -version "[16.0,17.0)" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set "VS2019_DIR=%%i"
    )
)

if "%VS2019_DIR%"=="" if exist "%PF86%\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvars64.bat" set "VS2019_DIR=%PF86%\Microsoft Visual Studio\2019\Enterprise"
if "%VS2019_DIR%"=="" if exist "%PF86%\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat" set "VS2019_DIR=%PF86%\Microsoft Visual Studio\2019\Professional"
if "%VS2019_DIR%"=="" if exist "%PF86%\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat" set "VS2019_DIR=%PF86%\Microsoft Visual Studio\2019\Community"
if "%VS2019_DIR%"=="" if exist "%PF86%\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" set "VS2019_DIR=%PF86%\Microsoft Visual Studio\2019\BuildTools"

if "%VS2019_DIR%"=="" (
    echo [ERROR] Visual Studio 2019 with C++ x64 toolset was not found!
    echo         Please install VS2019 with "Desktop development with C++" workload.
    exit /b 1
)

set "VCVARS64=%VS2019_DIR%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS64%" (
    echo [ERROR] vcvars64.bat not found at: "%VCVARS64%"
    exit /b 1
)

echo       VS2019 Path: "%VS2019_DIR%"
echo       Initializing x64 Native Tools Command Prompt for VS 2019...
set "PreferredToolArchitecture=x64"
call "%VCVARS64%"
if errorlevel 1 (
    echo [ERROR] Failed to initialize VS2019 x64 environment via vcvars64.bat!
    exit /b 1
)

REM Check DIA SDK (required for building dxcompiler on Windows)
set "DIA_SDK_DIR=%VS2019_DIR%\DIA SDK"
if not exist "%DIA_SDK_DIR%\include\dia2.h" (
    echo [ERROR] DIA SDK header not found: "%DIA_SDK_DIR%\include\dia2.h"
    exit /b 1
)

REM Check Windows 10/11 SDK and d3d12.h
set "WIN_SDK_DIR=%WindowsSdkDir%"
if "%WIN_SDK_DIR:~-1%"=="\" set "WIN_SDK_DIR=%WIN_SDK_DIR:~0,-1%"
set "WIN_SDK_VER=%WindowsSDKVersion%"
if "%WIN_SDK_VER:~-1%"=="\" set "WIN_SDK_VER=%WIN_SDK_VER:~0,-1%"
if "%WIN_SDK_VER%"=="" (
    echo [ERROR] WindowsSDKVersion was not set by vcvars64.bat. Please check Windows 10/11 SDK installation!
    exit /b 1
)
if not exist "%WIN_SDK_DIR%\Include\%WIN_SDK_VER%\um\d3d12.h" (
    echo [ERROR] d3d12.h not found in Windows SDK %WIN_SDK_VER%!
    echo         Expected path: "%WIN_SDK_DIR%\Include\%WIN_SDK_VER%\um\d3d12.h"
    exit /b 1
)
set "WIN10_SDK_PATH=%WIN_SDK_DIR%"
set "WIN10_SDK_VERSION=%WIN_SDK_VER%"
echo       Windows SDK Path   : %WIN_SDK_DIR%
echo       Windows SDK Version: %WIN_SDK_VER%

REM ============================================================================
REM 2. Check Git, CMake, Python3
REM ============================================================================
echo.
echo [2/7] Checking required build tools [Git / CMake / Python3]...

where git.exe >nul 2>nul
if not errorlevel 1 goto :check_cmake
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%PATH%;%ProgramFiles%\Git\cmd"
if exist "%PF86%\Git\cmd\git.exe" set "PATH=%PATH%;%PF86%\Git\cmd"
if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Git\cmd"
where git.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] git.exe not found in PATH! Please install Git.
    exit /b 1
)

:check_cmake
where cmake.exe >nul 2>nul
if not errorlevel 1 goto :check_python
if exist "%VS2019_DIR%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe" set "PATH=%PATH%;%VS2019_DIR%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "PATH=%PATH%;%ProgramFiles%\CMake\bin"
if exist "%PF86%\CMake\bin\cmake.exe" set "PATH=%PATH%;%PF86%\CMake\bin"
where cmake.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] cmake.exe not found! Please install CMake ^>= 3.17.2 or enable CMake in VS2019.
    exit /b 1
)

:check_python
where python.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] python.exe not found in PATH! Python 3.x is required to build DXC.
    exit /b 1
)

python.exe -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" >nul 2>nul
if errorlevel 1 (
    echo [ERROR] python.exe is not a valid Python 3.x installation!
    exit /b 1
)

for /f "tokens=*" %%g in ('where git.exe') do (echo       Git   : %%g & goto :git_ok)
:git_ok
for /f "tokens=*" %%c in ('where cmake.exe') do (echo       CMake : %%c & goto :cmake_ok)
:cmake_ok
for /f "tokens=*" %%p in ('where python.exe') do (echo       Python: %%p & goto :py_ok)
:py_ok

REM ============================================================================
REM 3. Initialize Git Submodules
REM ============================================================================
echo.
echo [3/7] Initializing and updating Git submodules...

cd /d "%REPO_ROOT%"
git submodule update --init --recursive
if errorlevel 1 (
    echo [ERROR] Failed to initialize git submodules! Please check network connection.
    exit /b 1
)

if not exist "%REPO_ROOT%\external\SPIRV-Headers\CMakeLists.txt" (
    echo [ERROR] Submodule external/SPIRV-Headers is missing after init!
    exit /b 1
)
if not exist "%REPO_ROOT%\external\SPIRV-Tools\CMakeLists.txt" (
    echo [ERROR] Submodule external/SPIRV-Tools is missing after init!
    exit /b 1
)

REM ============================================================================
REM 4. Configure CMake (Visual Studio 16 2019 x64)
REM ============================================================================
set "BUILD_DIR=%REPO_ROOT%\build_vs2019_x64"
echo.
echo [4/7] Running CMake configuration for Visual Studio 16 2019 x64...
echo       Build Directory: "%BUILD_DIR%"

cmake -S "%REPO_ROOT%" -B "%BUILD_DIR%" ^
    -C "%REPO_ROOT%\cmake\caches\PredefinedParams.cmake" ^
    -G "Visual Studio 16 2019" ^
    -A x64 ^
    -DCMAKE_GENERATOR_INSTANCE="%VS2019_DIR%" ^
    -DCMAKE_SYSTEM_VERSION="%WIN_SDK_VER%" ^
    -DMSVC_DIA_SDK_DIR="%DIA_SDK_DIR%" ^
    -DHLSL_INCLUDE_TESTS=OFF ^
    -DSPIRV_BUILD_TESTS=OFF ^
    -DLLVM_INCLUDE_TESTS=OFF ^
    -DHLSL_BUILD_DXILCONV=OFF

if errorlevel 1 (
    echo [ERROR] CMake configuration failed! See error output above.
    exit /b 1
)

REM ============================================================================
REM 5. Build dxcompiler (Release | x64)
REM ============================================================================
echo.
echo [5/7] Building target dxcompiler [Release x64]...

cmake --build "%BUILD_DIR%" --config Release --target dxcompiler -- /m
if errorlevel 1 (
    echo [ERROR] Building dxcompiler failed! See compiler output above.
    exit /b 1
)

REM ============================================================================
REM 6. Verify Output Artifacts
REM ============================================================================
echo.
echo [6/7] Verifying output binaries...

set "OUT_DLL=%BUILD_DIR%\Release\bin\dxcompiler.dll"
set "OUT_LIB=%BUILD_DIR%\Release\lib\dxcompiler.lib"

if not exist "%OUT_DLL%" (
    echo [ERROR] Build finished, but expected output was not found: "%OUT_DLL%"
    exit /b 1
)

REM ============================================================================
REM 7. Install to Tiny3D dependencies directory (via relative path)
REM ============================================================================
echo.
echo [7/7] Installing DXC headers and binaries...

cd /d "%REPO_ROOT%"
set "INSTALL_ROOT=..\..\Tiny3D\dependencies\dxc"
set "INSTALL_INC_DIR=%INSTALL_ROOT%\include\dxc"
set "INSTALL_BIN_DIR=%INSTALL_ROOT%\prebuilt\Windows\x64"

if not exist "%INSTALL_ROOT%" (
    echo [ERROR] Target install root directory does not exist: "%INSTALL_ROOT%"
    exit /b 1
)

if not exist "%INSTALL_INC_DIR%" (
    mkdir "%INSTALL_INC_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to create directory: "%INSTALL_INC_DIR%"
        exit /b 1
    )
)

if not exist "%INSTALL_BIN_DIR%" (
    mkdir "%INSTALL_BIN_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to create directory: "%INSTALL_BIN_DIR%"
        exit /b 1
    )
)

copy /Y "include\dxc\dxcapi.h" "%INSTALL_INC_DIR%\dxcapi.h" >nul
if errorlevel 1 (
    echo [ERROR] Failed to install dxcapi.h to "%INSTALL_INC_DIR%"
    exit /b 1
)

copy /Y "include\dxc\dxcerrors.h" "%INSTALL_INC_DIR%\dxcerrors.h" >nul
if errorlevel 1 (
    echo [ERROR] Failed to install dxcerrors.h to "%INSTALL_INC_DIR%"
    exit /b 1
)

copy /Y "include\dxc\WinAdapter.h" "%INSTALL_INC_DIR%\WinAdapter.h" >nul
if errorlevel 1 (
    echo [ERROR] Failed to install WinAdapter.h to "%INSTALL_INC_DIR%"
    exit /b 1
)

copy /Y "%OUT_DLL%" "%INSTALL_BIN_DIR%\dxcompiler.dll" >nul
if errorlevel 1 (
    echo [ERROR] Failed to install dxcompiler.dll to "%INSTALL_BIN_DIR%"
    exit /b 1
)

echo       Installed: %INSTALL_INC_DIR%\dxcapi.h
echo       Installed: %INSTALL_INC_DIR%\dxcerrors.h
echo       Installed: %INSTALL_INC_DIR%\WinAdapter.h
echo       Installed: %INSTALL_BIN_DIR%\dxcompiler.dll

echo.
echo ============================================================================
echo   [SUCCESS] dxcompiler built and installed successfully!
echo   Build DLL   : %OUT_DLL%
if exist "%OUT_LIB%" echo   Build LIB   : %OUT_LIB%
echo   Install Dir : %INSTALL_ROOT%
echo ============================================================================
exit /b 0
