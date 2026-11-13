@echo off
:: launcher da tool do fortnite — duplo-clique pra compilar (se precisar) e executar
setlocal enabledelayedexpansion

set SRC_DIR=..\fortnite
set EXE=%SRC_DIR%\fortnite_tool.exe
set BUILD=%SRC_DIR%\build.bat

echo [load] verificando executavel...

if exist "%EXE%" goto executar

:: --- tenta achar o cl.exe (compilador MSVC) sozinho, sem precisar abrir o x64 Native Tools CMD ---
set CL_PATH=
for %%i in (
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe",
    "C:\Program Files\Microsoft Visual Studio\Build Tools\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe"
) do (
    if exist "%%i" if not defined CL_PATH set CL_PATH=%%i
)

if defined CL_PATH (
    echo [load] compilador encontrado: %CL_PATH%
    for %%j in ("%CL_PATH%") do set CL_DIR=%%~dpj
    set PATH=%CL_DIR%;%PATH%
) else (
    echo [load] AVISO: cl.exe nao encontrado automaticamente.
    echo [load] se o build falhar, abra o "x64 Native Tools Command Prompt for VS"
    echo [load] e rode build.bat manualmente dentro da pasta fortnite/.
)

echo [load] fortnite_tool.exe nao encontrado, compilando...
if not exist "%BUILD%" (
    echo [load] ERRO: nao encontrou %BUILD%.
    echo [load] certifique-se de que esta pasta esta dentro do repositorio (load/ ao lado de fortnite/).
    pause
    exit /b 1
)

call "%BUILD%"
if %ERRORLEVEL% neq 0 (
    echo [load] FALHA NA COMPILACAO.
    echo [load] necessario: MSVC + Windows SDK (cl.exe).
    echo [load] instale o "Build Tools for Visual Studio 2022" com a carga "Desenvolvimento para desktop em C++".
    pause
    exit /b %ERRORLEVEL%
)

:executar
if not exist "%EXE%" (
    echo [load] ERRO: %EXE% nao foi gerado apos o build.
    pause
    exit /b 1
)

echo [load] executando %EXE%
start "" "%EXE%"
