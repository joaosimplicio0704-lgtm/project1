#pragma once
#include <windows.h>

// ============================================================
// StealthyOpenProcess v5
//   - zero CRT
//   - thread-safe (CRITICAL_SECTION)
//   - HWBP (DR0) per-thread — sem race condition com threads alheias
//   - VEH SINGLE_STEP TID-gated — nao interfere com outros handlers
//   - callstack da abertura de handle inteira dentro de kernel32
//
// Adaptado: a API original abria com PROCESS_ALL_ACCESS. Aqui o default e
// read-only, porque nada no projeto escreve em memoria do jogo.
// ============================================================

namespace StealthyOpenProcess {

// abertura default: leitura + query (o que o resto do tool precisa)
inline constexpr DWORD kDefaultAccess = PROCESS_VM_READ | PROCESS_QUERY_INFORMATION;

bool   Initialize();
void   Shutdown();
HANDLE Execute(DWORD dwProcessId, DWORD dwDesiredAccess = kDefaultAccess);

} // namespace StealthyOpenProcess
