@echo off
:: launcher da tool do fortnite — duplo-clique pra compilar (se precisar) e executar
setlocal enabledelayedexpansion

set SRC_DIR=..\fortnite
set EXE=%SRC_DIR%\fortnite_tool.exe

echo [load] verificando executavel...

if not exist "%EXE%" (
    echo [load] fortnite_tool.exe nao encontrado, compilando...
    call "%SRC_DIR%\build.bat"
    if %ERRORLEVEL% neq 0 (
        echo [load] falha na compilacao. verifique se tem MSVC + Windows SDK instalados.
        pause
        exit /b %ERRORLEVEL%
    )
)

if not exist "%EXE%" (
    echo [load] ainda nao encontrou %EXE% apos build.
    pause
    exit /b 1
)

echo [load] executando %EXE%
start "" "%EXE%"
