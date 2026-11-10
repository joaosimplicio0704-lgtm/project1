#pragma once

#include <windows.h>

namespace HandleCleanup {
    // Only for threads created and owned by StealthyOpenProcess. Never scans or
    // closes arbitrary process handles. A stuck ephemeral thread is terminated
    // before its handle is closed so the VEH can be removed safely.
    void FinishOwnedThread(HANDLE thread, DWORD timeoutMs) noexcept;
}
