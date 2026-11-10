#pragma once
#include <Windows.h>

// StealthyOpenProcess v5 (adaptado sem dependencia externa de XorStr)
// Abre handle de processo com callstack dentro do kernel32 via HWBP+VEH,
// tornando a chamada mais opaca a scanners que monitoram OpenProcess direto.
namespace StealthyOpenProcess {

    bool   Initialize();
    void   Shutdown();
    HANDLE Execute(DWORD dwProcessId, DWORD dwDesiredAccess = PROCESS_ALL_ACCESS);

} // namespace StealthyOpenProcess
