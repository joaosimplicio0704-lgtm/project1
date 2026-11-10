@echo off
:: launcher da tool do fortnite — duplo-clique pra compilar (se precisar) e executar
setlocal enabledelayedexpansion

set SRC_DIR=..\fortnite
set EXE=%SRC_DIR%\fortnite_tool.exe
set BUILD=%SRC_DIR%\build.bat

echo [load] verificando executavel...

if not exist "%EXE%" (
    echo [load] fortnite_tool.exe nao encontrado.
    if not exist "%BUILD%" (
        echo [load] ERRO: nao encontrou %BUILD%.
        echo [load] certifique-se de que esta pasta esta dentro do repositorio (load/ ao lado de fortnite/).
        pause
        exit /b 1
    )
    echo [load] compilando com %BUILD% ...
    call "%BUILD%"
    if %ERRORLEVEL% neq 0 (
        echo [load] FALHA NA COMPILACAO.
        echo [load] necessario: MSVC + Windows SDK (cl.exe no PATH).
        echo [load] abra o "x64 Native Tools Command Prompt for VS" e rode build.bat manualmente.
        pause
        exit /b %ERRORLEVEL%
    )
)

if not exist "%EXE%" (
    echo [load] ERRO: %EXE% nao foi gerado apos o build.
    pause
    exit /b 1
)

echo [load] executando %EXE%
start "" "%EXE%"
