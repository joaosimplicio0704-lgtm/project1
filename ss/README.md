# ss

Versão limpa dos três arquivos enviados. Windows x64, C++17, MSVC.

| original | aqui |
| --- | --- |
| `StealthyOpenProcess.h` / `StealthyOpenProcess.cpp` | `ProcessHandle.h` / `ProcessHandle.cpp` |
| `closehandle.cpp` | `ThreadHandleMonitor.h` / `ThreadHandleMonitor.cpp` |

`demo.cpp` exercita os dois módulos. `CMakeLists.txt` monta biblioteca estática + demo.

## o que mudou

- `OpenProcess` chamado direto na thread que pede o handle. `GetLastError()` volta em `lastError()`, não se perde numa thread efêmera.
- `ProcessHandle` é RAII move-only: fecha uma vez, `release()` pra passar posse, `reset()` pra trocar.
- acesso padrão é `PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ`, não `PROCESS_ALL_ACCESS`. `read()` é só leitura, sem escrita e sem injeção. Leitura parcial vira `ERROR_PARTIAL_COPY`.
- sem VEH, sem DR0/HWBP, sem stubs em `kernel32`, sem `XorStr`, sem `CreateThread(CREATE_SUSPENDED)`, sem `TerminateThread`.
- o reaper só fecha handles registrados por você via `track()`. Nada de `NtQuerySystemInformation` + `CloseHandle` por valor de snapshot — o valor pode ser reutilizado entre enumerar e fechar, e aí você fecha um handle vivo de outra coisa.
- fim de thread decidido por `WaitForSingleObject(h, 0)`, não por `exitCode == STILL_ACTIVE` (259 também é exit code legítimo). Heurística de "exit status desconhecido" virou só log em `takeReaped()`, nunca critério pra fechar.
- `stop()` sinaliza um evento e espera. Se der timeout, devolve `false` e **não** mata a thread (`TerminateThread` com loader lock é deadlock certo). O `State` é `shared_ptr`, então a thread que sobrou não toca memória liberada.
- `start()` é opcional: `reapNow()` faz a varredura no seu próprio loop de tick. Nada dispara na construção.
- sem dependências de fora: nada de `Cheat/Globals.hpp`, `DynamicStub.hpp` ou `XorStr.hpp`.

## ownership

`track(h)` **toma posse** do handle. Se retornar `false`, você continua dono e deve chamar `CloseHandle(h)`. O handle precisa de `THREAD_QUERY_LIMITED_INFORMATION` (o que `CreateThread` já dá).

## build

```bat
cl /std:c++17 /EHsc /utf-8 /O2 /Fe:ss_demo.exe demo.cpp ProcessHandle.cpp ThreadHandleMonitor.cpp
```

ou

```bat
cmake -S . -B build && cmake --build build --config Release
```

Roda com `ss_demo.exe` (processo próprio) ou `ss_demo.exe <pid>`. Com pid externo só abre o handle; a leitura da base é feita apenas no próprio processo, porque ASLR entre processos não é garantido.

> não compilei aqui: o sandbox é Linux, sem toolchain Windows. os fontes passaram por checagem de sintaxe com um shim de `Windows.h`.
