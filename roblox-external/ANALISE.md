# Análise — misery1x/Roblox-External

Escaneamento do repositório original (commit `898f98c`, 11/10/2026) antes de reusar o source.

## Veredito

Nada malicioso. Sem rede, sem persistência, sem injeção, sem carregamento remoto.
É um external de ESP simples e honesto: `OpenProcess` + `ReadProcessMemory` + overlay D3D11.

## Scan

| checagem | resultado |
|---|---|
| `http/https`, `socket`, `WinHTTP`, `InternetOpen`, `URLDownload` | zero ocorrências fora dos comentários do imgui |
| `ShellExecute`, `CreateProcess`, `WinExec` | zero |
| `VirtualAllocEx`, `WriteProcessMemory`, `CreateRemoteThread` | zero (não escreve em memória do processo alvo) |
| `SetWindowsHookEx`, `GetAsyncKeyState`, keylogger | zero |
| `RegSetValue*`, persistência, startup folder | zero |
| clipboard / webhook / discord / base64 | zero |
| binários commitados (`.exe`, `.dll`, `.bin`, `.dat`) | zero — 30 arquivos, todos texto |
| build hooks (`PreBuild`, `PostBuild`, `Exec`, `Nasm`) no `.vcxproj` | zero |
| `.vcxproj.user` | só `ShowAllFiles=true` |

Único item de rede é o `#pragma comment(lib, "winmm.lib")` e includes padrão do Windows SDK.

## imgui vendorizado — verificado contra upstream

Hash de cada arquivo comparado com os releases oficiais (`v1.92.1`, `v1.92.0`, `v1.91.9b`, `v1.91.5`):

- `imconfig.h`, `imstb_truetype.h`, `imstb_textedit.h`, `imstb_rectpack.h` → match exato com upstream
- os demais (`imgui.cpp`, `imgui.h`, `imgui_draw.cpp`, `imgui_widgets.cpp`, `imgui_tables.cpp`, `imgui_internal.h`) → **não é código injetado**, é um commit intermediário de master (`IMGUI_VERSION_NUM 19202`, "1.92.1 WIP"), entre v1.92.0 (19200) e v1.92.1 (19210). O diff contra v1.92.1 é só de rename interno (`DebugDrawIdConflictsId` → `DebugDrawIdConflicts`) e texto de comentário, exatamente o que aparece entre essas duas tags.

Conclusão: imgui legítimo, só desatualizado por algumas semanas.

## Bugs encontrados no original

| # | arquivo:linha | problema |
|---|---|---|
| 1 | `overlay/overlay.cpp:37` | `WS_EX_TRANSPARENT` fixo na criação e nunca removido — janela click-through permanente, menu ImGui nunca recebe mouse |
| 2 | `features/esp.cpp:367-368` | `WorldToScreen` com `960.0f / 540.0f` hardcoded: só acerta em 1080p fullscreen no monitor primário, ignora DPI |
| 3 | `overlay/overlay.cpp:96-100` | `Initialize()` retorna `true` sempre; `HRESULT` de `D3D11CreateDeviceAndSwapChain` não é checado → null `device` dereferenciado |
| 4 | `overlay/overlay.cpp:132` | `Present(0, DXGI_PRESENT_DO_NOT_WAIT)` sem pacing → um core a 100% |
| 5 | `sdk/memory.cpp:64` | `OpenProcess(PROCESS_VM_READ)` só, depois `TH32CS_SNAPMODULE`: snapshot de módulos exige `PROCESS_QUERY_INFORMATION` |
| 6 | `features/esp.cpp:114-215` | cache de filhos em `static unordered_map` keyed por endereço, TTL 1s, sem evicção — cresce a sessão inteira e guarda ponteiro morto depois de rejoin |
| 7 | `sdk/memory.cpp:78-86` | `ReadProcessMemory` sem checar retorno — primitive liberada devolve zero e vira entidade em (0,0) |
| 8 | `features/esp.cpp:337-345` | `names.push_back(player.name.c_str())` empilha ponteiro para `std::string` local; funciona só porque o draw acontece antes do return |
| 9 | `features/esp.cpp:355-380` | `WorldToScreen` duplicado (`Math::` e `ActorLoopClass::`), um com culling e outro sem — o render usa o sem |
| 10 | `features/esp.cpp:332,355` | `_mm_prefetch` em `draw_list`/matriz: ruído, nada a ganhar |
| 11 | `overlay/overlay.cpp:44` | color-key preto: qualquer pixel preto do UI desaparece |
| 12 | `sdk/offsets.h` | offsets absolutos de módulo, sem dumper, sem versão — param de funcionar a cada update do cliente |

## O que foi feito no port

Todos os 12 acima corrigidos — ver `README.md`, seção "diff contra o original".

Os offsets do `sdk/offsets.h` original (`FakeDataModelPointer 0x759FD28`, `VisualEnginePointer 0x72FE710`,
`LocalPlayer 0x130`, `ModelInstance 0x360`, `Primitive 0x148`, `Position 0x11C`, `viewmatrix 0x4B0`)
foram substituídos inteiros pelo dump `version-f0ea5da9412f4e35` que você mandou.
