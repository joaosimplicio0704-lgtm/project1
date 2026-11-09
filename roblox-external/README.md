# roblox-external

Reescrita do base `misery1x/Roblox-External` com o dump de offsets
`version-f0ea5da9412f4e35`, `StealthyOpenProcess` v5 no lugar do `OpenProcess` cru,
**detector de jogo** e **aim assist configurável**.

Externo, read-only: `ReadProcessMemory` + `SendInput` + overlay D3D11/ImGui.
Nada é escrito em memória do jogo, nada é injetado, nenhum driver.

```
processo   RobloxPlayerBeta.exe
handle     StealthyOpenProcess (HWBP + VEH) — fallback OpenProcess
leitura    ReadProcessMemory, PROCESS_VM_READ | PROCESS_QUERY_INFORMATION
input      SendInput / INPUT_MOUSE / MOUSEEVENTF_MOVE (relativo)
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

Saída: `build/RobloxExternal.exe`. Binário pronto em `dist/RobloxExternal.exe`
(x86-64, PE32+, console, estático — sem dependência de runtime do mingw).

## Uso

```
INSERT   abre/fecha o menu e devolve o mouse pro jogo
F1       ESP on/off
F2       caixa on/off
END      sai
Mouse 5  aim assist (segurar; rebindável na aba Aim)
```

Quatro abas: **ESP**, **Aim**, **Jogo**, **Config**.
`config.json` e `profiles.json` ficam ao lado do `.exe`.

## Aim assist

Externo de verdade: lê a posição do osso (`Head` / peito / `HumanoidRootPart`),
projeta com a view matrix, mede o erro em pixels até o centro da tela, e move o
mouse com `SendInput(MOUSEEVENTF_MOVE)`. Nada de escrever view angle ou estado
do player — a câmera gira, a projeção é recalculada, o erro converge.

Alvo escolhido: o mais perto do crosshair dentro do FOV.

```
passo = erro_px * (forca / suavizacao) + resto_fracionario
passo = clamp(passo, passo_max)
```

| knob | o que faz |
|---|---|
| `Forca` (0.05–1.00) | **quanto a mira puxa**: fração do erro aplicada por tick. 1.00 = cola no osso |
| `Suavizacao` (1–20) | divisor do passo. maior = mais lento e mais discreto |
| `Passo max (px)` | teto de movimento por tick, evita flick |
| `Zona morta (px)` | para de mexer quando já está em cima |
| `Jitter (px)` | ruído no delta |
| `FOV (raio px)` | círculo do alcance, desenhado na tela |
| `Osso` | cabeça / peito / raiz |
| `Tecla` | botão `Bind` captura a próxima tecla; modo segurar ou toggle |
| `Só com o jogo em foco` | compara o PID do `GetForegroundWindow()` — não rouba o mouse fora do jogo |

Se o menu estiver aberto o aim não envia nada. O ganho real por tick aparece na
aba (`forca / suavizacao`), pra não ter que fazer conta de cabeça.

## Detector de jogo

Lê a identidade do DataModel a cada 1s (e na hora quando o DataModel muda):

```
PlaceId       DataModel+0x180
GameId        DataModel+0x178
CreatorId     DataModel+0x170
PlaceVersion  DataModel+0x19C
JobId         DataModel+0x108  (std::string)
```

Aba **Jogo** mostra tudo, contagem de players, e mantém **perfis por PlaceId**:
`Salvar config atual neste PlaceId` grava FOV/força/suavização/osso do jogo atual
em `profiles.json`; ao entrar num lugar com perfil salvo, o aim ajusta sozinho e
loga no console (`[jogo] place 1234 — perfil aplicado`).

## Estrutura

```
src/
  main.cpp              loop, hotkeys, ciclo de vida, auto-perfil
  config.h/.cpp         knobs + config.json + profiles.json
  offsets.h             dump inteiro em namespace rbx
  sdk/memory.*          handle, leitura validada, base do módulo
  sdk/sdk.h             Vector2/3, Matrix4x4, WorldToScreen
  stealth/StealthyOpenProcess.*   HWBP + VEH (v5)
  stealth/handle_cleanup.*        sweeper de handles de thread órfãos
  stealth/xorstr.h                shim do XorStr.hpp que faltava
  features/esp.*        ActorLoop — leitura da cena + draw
  features/aim.*        seleção de alvo + SendInput
  features/detector.*   PlaceId/GameId/JobId + perfil por jogo
  menu/menu.*           menu tabbed
  overlay/overlay.*     janela + D3D11 + ImGui
  imgui/                v1.92.1-WIP vendorizado (upstream, verificado)
```

## Atualizar offsets

Tudo em `src/offsets.h`, dentro de `namespace rbx`. Cola o dump novo por cima, recompila.
Único offset cru fora do arquivo: fallback de nome em `features/esp.cpp`
(`Instance + 0x90`, layout antigo, só usado se o caminho novo falhar).

## Diff contra o original

| original | aqui |
|---|---|
| `OpenProcess(PROCESS_VM_READ)` | `StealthyOpenProcess::Execute` com fallback, `VM_READ\|QUERY_INFORMATION` |
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
| — | detector de jogo + aim assist + perfis por PlaceId |

## Limitações

- assume Roblox **fullscreen / borderless no monitor primário** — a matriz de projeção
  é mapeada direto no tamanho do overlay. Janela pequena desalinha ESP e aim.
- transparência por **color-key**: pixel preto é vazado.
- "Melhorar precisão do ponteiro" do Windows afeta `MOUSEEVENTF_MOVE` — desligar
  para o aim ter ganho constante entre sessões.
- `Live` protegido por Hyperion: leitura no cliente de produção tende a derrubar
  o processo. **Testar em Studio ou em VM.**

```bat
:: Hyperion mata leitura no cliente live — Studio/VM primeiro
```

## Análise do repositório original

`ANALISE.md` — scan completo, 12 bugs com arquivo:linha, verificação dos hashes do imgui.
