#pragma once

#include <windows.h>

namespace StealthyOpenProcess {
    inline constexpr DWORD kReadOnlyAccess = PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ;

    bool Initialize();
    void Shutdown();
    HANDLE Execute(DWORD processId, DWORD desiredAccess = kReadOnlyAccess) noexcept;
    DWORD LastError() noexcept;
}
