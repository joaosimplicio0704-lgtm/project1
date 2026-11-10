@echo off
setlocal
cd /d "%~dp0"
cmake -S . -B build -G "Visual Studio 17 2022" -A x64 || exit /b 1
cmake --build build --config Release --parallel || exit /b 1
copy /y "%CD%\build\Release\FortniteExternal.exe" "%CD%\FortniteExternal.exe" >nul || exit /b 1
copy /y "%CD%\build\Release\FortLoader.exe" "%CD%\FortLoader.exe" >nul || exit /b 1
echo Built and copied both executables to %CD%
