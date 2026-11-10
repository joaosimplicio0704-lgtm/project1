@echo off
setlocal
cd /d "%~dp0"
cmake -S . -B cmake-build -G "Visual Studio 17 2022" -A x64 || exit /b 1
cmake --build cmake-build --config Release --parallel || exit /b 1
if not exist "%CD%\build" mkdir "%CD%\build" || exit /b 1
copy /y "%CD%\cmake-build\Release\FortniteExternal.exe" "%CD%\build\FortniteExternal.exe" >nul || exit /b 1
copy /y "%CD%\cmake-build\Release\FortLoader.exe" "%CD%\build\FortLoader.exe" >nul || exit /b 1
echo Built and copied both executables to %CD%\build
