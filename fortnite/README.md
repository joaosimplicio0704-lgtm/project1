# fortnite external tool

Tool externo, leitura via `ReadProcessMemory` + mira com `SendInput` (`INPUT_MOUSE`, `MOUSEEVENTF_MOVE`).
Sem injeção, sem escrita na memória do jogo. Portanto sem instant kill / bullet TP (precisariam de write e quebram a regra padrão).

Stack: externo, RPM read-only, mouse via SendInput, offsets do seu dump (Unreal Engine).

## build
Abra o "x64 Native Tools Command Prompt for VS" na pasta `fortnite/` e rode:

```
build.bat
```

Gera `fortnite/fortnite_tool.exe`. Requer Windows SDK + MSVC (d3d11.lib, dxgi.lib).

## como usar
1. Inicie o Fortnite e entre em uma partida (offline/community/practice — contexto padrão).
2. Rode `fortnite_tool.exe`.
3. `INSERT` abre/fecha o menu (ESP, aimbot, team check, distância, vida/escudo, FOV).
4. `END` fecha a ferramenta.
5. Aimbot: segure `XBUTTON2` (botão lateral do mouse) pra mirar no alvo mais próximo da crosshair dentro do FOV.

## o que falta preencher (// FILL)
O dump não cobre tudo. Preencher uma linha em cada lugar marcado `// FILL`:

1. `offsets.hpp::kGNames` — RVA de `GNames` (obrigatório pra comparar nomes de classe).
   Receita: ache uma string de classe conhecida (ex: `"FortPlayerPawnAthena"`) com CE, descubre o pool de FName, `GNames` fica perto de outras globais de engine.

2. `offsets.hpp::kLevel_Actors` — offset de `ULevel::Actors` (`TArray<AActor*>`).
   Receita CE: `PersistentLevel` → `Levels[0]` → pointer-scan do TArray de atores (endereço do primeiro ator).

3. `offsets.hpp::kScene_ComponentToWorld` — `FTransform::Translation` em `+0x20` se quiser posição exata do ator (senão usa `RelativeLocation`, aproximação).

4. `offsets.hpp::kMesh_CachedComponentSpaceTransforms` + índice do osso da cabeça — pra W2S da cabeça (atual usa `feet.Z + 90`, aproximação).

5. `main.cpp` — resolver o `APlayerController` local e chamar `ents.setLocal(local, <controller>)`.
   Receita: `GWorld` (`base + 0x1C8E1578`) → `GameInstance` (pattern/dumper) → `LocalPlayers` (`0x38`) → `[0]` → `PlayerController` (pointer-scan do controller com `PlayerCameraManager != 0`).

6. `aimbot.hpp::kAimSens` — converção ângulo → pixels do mouse; ajuste por feeling.

## offsets usados (do dump)
`kGWorld = 0x1C8E1578`, `kGEngine = 0x1C8E2F48`, `World.PersistentLevel = 0x40`, `World.GameState = 0x1D0`, `GameState.PlayerArray = 0x290`, `Actor.RootComponent = 0x1B0`, `Scene.RelativeLocation = 0x140`, `Pawn.PlayerState = 0x298`, `Character.Mesh = 0x2F8`, `FortPawn.HealthSet = 0x1430`, `FortPawn.CurrentWeapon = 0x9E0`, `FortPawn.bIsDBNO = 0x892`, `HealthSet.Health = 0x48`, `HealthSet.MaxHealth = 0x70`, `HealthSet.CurrentShield = 0xC0`, `PlayerController.PlayerCameraManager = 0x330`, `PlayerCameraManager.CameraCachePrivate = 0x15A0`, `MinimalViewInfo.Location/Rotation/FOV = 0x0/0x18/0x30`, `PlayerState.TeamIndex = 0xF81`, `PlayerState.PlayerNamePrivate = 0x310`.

## nota
Não compilei aqui (não há MSVC/Windows SDK neste sandbox) — verifique a compilação com `build.bat` na sua máquina. Confirme cada offset contra um dumper atual do seu build do Fortnite antes de usar.
