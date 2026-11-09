# roblox-external

Reescrita do base `misery1x/Roblox-External` com o dump de offsets
`version-f0ea5da9412f4e35` e o `StealthyOpenProcess` v5 no lugar do `OpenProcess` cru.

Externo, read-only: `ReadProcessMemory` + overlay D3D11/ImGui. Nada é escrito em memória do jogo,
nada é injetado, nenhum driver.

```
processo   RobloxPlayerBeta.exe
handle     StealthyOpenProcess (HWBP + VEH) — fallback OpenProcess
leitura    ReadProcessMemory, PROCESS_VM_READ | PROCESS_QUERY_INFORMATION
render     D3D11 swapchain + ImGui, janela layered topmost
toolchain  MSVC v143 (C++20) ou zig/clang cross-compile
```

## Build

```bat
:: x64 Native Tools Command Prompt
build.bat
```

```sh
# linux/mac cross-compile
pip install ziglang
ZIG="python3 -m ziglang" ./build.sh
```

Saída: `build/RobloxExternal.exe`. Já existe um binário compilado em `dist/RobloxExternal.exe`
(x86-64, PE32+, console, estático — sem dependência de runtime do mingw).

## Uso

```
INSERT   abre/fecha o menu e devolve o mouse pro jogo
F1       ESP on/off
F2       caixa on/off
END      sai
```

Menu tem duas abas: **ESP** (caixa, nome, barra de vida, distância, team check, alcance, tick)
e **Config** (stealth, handle watchdog, salvar/carregar `config.json`, estado).

`config.json` fica ao lado do `.exe` e guarda o estado entre execuções.

## Estrutura

```
src/
  main.cpp              loop, hotkeys, ciclo de vida
  config.h/.cpp         knobs + persistência JSON
  offsets.h             dump inteiro em namespace rbx
  sdk/memory.*          handle, leitura validada, base do módulo
  sdk/sdk.h             Vector2/3, Matrix4x4, WorldToScreen
  stealth/StealthyOpenProcess.*   HWBP + VEH (v5)
  stealth/handle_cleanup.*        sweeper de handles de thread órfãos
  stealth/xorstr.h                shim do XorStr.hpp que faltava
  features/esp.*        ActorLoop — leitura da cena + draw
  menu/menu.*           menu tabbed
  overlay/overlay.*     janela + D3D11 + ImGui
  imgui/                v1.92.1-WIP vendorizado (upstream, verificado)
```

## Atualizar offsets

Tudo em `src/offsets.h`, dentro de `namespace rbx`. Cola o dump novo por cima, recompila.
Nenhum outro arquivo tem offset cru — exceção: `features/esp.cpp` tem um fallback
para o layout antigo de nome (`Instance + 0x90`), que só é usado se o caminho novo falhar.

Offsets que este projeto realmente usa:

```
FakeDataModel::Pointer       -> DataModel::+RealDataModel
VisualEngine::Pointer        -> +ViewMatrix
Instance::{ChildrenStart, ChildrenEnd, NameContainer, ClassDescriptor, ClassName}
Player::{LocalPlayer, ModelInstance, Team}
Humanoid::{Health, MaxHealth}
BasePart::Primitive          -> Primitive::{Position, Size}
```

## Diff contra o original

| original | aqui |
|---|---|
| `OpenProcess(PROCESS_VM_READ)` | `StealthyOpenProcess::Execute` com fallback, acesso `VM_READ\|QUERY_INFORMATION` |
| offsets de novembro/2025 chutados | dump `version-f0ea5da9412f4e35` |
| `WS_EX_TRANSPARENT` fixo, sem menu | toggle de input no INSERT, mouse volta pro jogo ao fechar |
| `WorldToScreen` com `960/540` | dimensões do overlay passadas por parâmetro |
| `Initialize()` sempre `true` | checagem de `HRESULT`, fallback WARP, mensagem de erro |
| `Present(0, DO_NOT_WAIT)` em spin | `Present(1, 0)` sincronizado + `Sleep(tick)` |
| cache de filhos sem evicção | TTL 500ms, limpeza no rejoin e ao passar de 1024 entradas |
| `ReadProcessMemory` sem retorno | `Read()` valida faixa de endereço e bytes lidos |
| `std::string::c_str()` no vetor de draw | `Target` com `std::string` própria |
| duas implementações de W2S | uma, em `sdk/sdk.h` |
| ESP só com nome | caixa, nome, barra de vida, distância, team check, alcance |
| sem reattach | detecta saída do processo e reabre handle a cada 1s |

## Limitações

- assume Roblox **fullscreen / borderless no monitor primário** — a matriz de projeção é mapeada
  direto no tamanho do overlay. Janela pequena desalinha.
- transparência por **color-key**: pixel preto é vazado. O tema do menu usa fundo escuro, não puro preto.
- `Live` protegido por Hyperion: leitura no cliente de produção tends a derrubar o processo.
  **Testar em Studio ou em VM.**

```bat
:: Hyperion mata leitura no cliente live — Studio/VM primeiro
```

## Análise do repositório original

`ANALISE.md` — scan completo, 12 bugs com arquivo:linha, verificação dos hashes do imgui.
