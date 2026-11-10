@echo off
:: build do tool externo de fortnite (MSVC + Windows SDK)
:: requisitos: "x64 Native Tools Command Prompt for VS" ou variaveis INCLUDE/LIB do SDK setadas.

set SRC_DIR=%~dp0
set IMGUI=%SRC_DIR%deps\imgui

cl /EHsc /O2 /nologo /W3 ^
  /I"%SRC_DIR%" ^
  /I"%IMGUI%" ^
  /I"%IMGUI%\backends" ^
  "%SRC_DIR%main.cpp" ^
  "%SRC_DIR%overlay.cpp" ^
  "%SRC_DIR%StealthyOpenProcess.cpp" ^
  "%IMGUI%\imgui.cpp" ^
  "%IMGUI%\imgui_draw.cpp" ^
  "%IMGUI%\imgui_tables.cpp" ^
  "%IMGUI%\imgui_widgets.cpp" ^
  "%IMGUI%\backends\imgui_impl_win32.cpp" ^
  "%IMGUI%\backends\imgui_impl_dx11.cpp" ^
  /link user32.lib d3d11.lib dxgi.lib ole32.lib shell32.lib advapi32.lib ^
  /OUT:"%SRC_DIR%fortnite_tool.exe"

if %ERRORLEVEL% neq 0 (
    echo ERRO na compilacao
    pause
    exit /b 1
)
echo build ok: %SRC_DIR%fortnite_tool.exe
