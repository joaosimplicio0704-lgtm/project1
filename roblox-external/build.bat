@echo off
setlocal
REM build MSVC x64 — rode dentro do "x64 Native Tools Command Prompt for VS"
REM saida: build\RobloxExternal.exe

where cl >nul 2>nul
if errorlevel 1 (
    echo [erro] cl.exe nao esta no PATH. abra o Developer Command Prompt.
    exit /b 1
)

if not exist build mkdir build

cl /nologo /std:c++20 /O2 /EHsc /MT /W3 /utf-8 ^
   /D_WIN32_WINNT=0x0A00 /DWIN32_LEAN_AND_MEAN /DNOMINMAX /DUNICODE /D_UNICODE ^
   src\main.cpp ^
   src\config.cpp ^
   src\sdk\memory.cpp ^
   src\stealth\StealthyOpenProcess.cpp ^
   src\stealth\handle_cleanup.cpp ^
   src\features\esp.cpp ^
   src\overlay\overlay.cpp ^
   src\menu\menu.cpp ^
   src\imgui\imgui.cpp ^
   src\imgui\imgui_draw.cpp ^
   src\imgui\imgui_tables.cpp ^
   src\imgui\imgui_widgets.cpp ^
   src\imgui\imgui_impl_win32.cpp ^
   src\imgui\imgui_impl_dx11.cpp ^
   /Fo:build\ /Fe:build\RobloxExternal.exe ^
   /link d3d11.lib dxgi.lib dwmapi.lib

if errorlevel 1 (
    echo [erro] build falhou
    exit /b 1
)

echo [ok] build\RobloxExternal.exe
endlocal
