# load — binários necessários pra executar

esta pasta é onde ficam os `.exe` (e dlls, se houver) pra rodar a tool do Fortnite.

**não existe .exe pré-compilado aqui.** o sandbox não tem MSVC / Windows SDK, então não foi possível compilar.

pra gerar o executável:

1. abra o **"x64 Native Tools Command Prompt for VS"** (ou qualquer terminal com `cl.exe` no PATH e as libs do Windows SDK).
2. rode na raiz do projeto:

```
fortnite\build.bat
```

isso produz:

```
fortnite\fortnite_tool.exe
```

3. copie `fortnite_tool.exe` pra cá (`load/`) se quiser manter os binários separados do código, ou execute direto da pasta `fortnite/`.

arquivos necessários pra executar (após compilar):

- `load\fortnite_tool.exe` (gerado pelo `build.bat`)

não são necessárias dlls extras além das do sistema (user32, d3d11, dxgi, ole32, shell32, advapi32).

## como usar (resumo)

1. inicie o Fortnite e entre em uma partida (contexto padrão: offline / community / practice).
2. rode `load\fortnite_tool.exe` (ou `fortnite\fortnite_tool.exe`).
3. `INSERT` abre/fecha o menu (ESP, aimbot, team check, visibilidade, distância, vida/escudo, FOV).
4. segure `XBUTTON2` (botão lateral do mouse) pra mirar no alvo mais perto da crosshair.
5. `END` fecha a tool.

## antes de usar

confirme cada offset contra um dumper atual do seu build do Fortnite. os marcados `// FILL` no código (`GNames`, `ULevel::Actors`, `ComponentToWorld`, ossos, `APlayerController` local) precisam ser preenchidos — receitas em `fortnite/README.md` e `fortnite/offsets.hpp`.

`closehandle.cpp` depende de `Cheat/Globals.hpp` e `DynamicStub/DynamicStub.hpp` (nao enviados por voce); stubs minimos estao em `fortnite/Cheat/` e `fortnite/DynamicStub/` com `// FILL`. Preencha a implementacao real antes de compilar.

stack: externo, RPM read-only, mouse via SendInput, offsets do dump UE.
