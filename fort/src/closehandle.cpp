#include "closehandle.h"

namespace HandleCleanup {
    void FinishOwnedThread(HANDLE thread, DWORD timeoutMs) noexcept {
        if (!thread || thread == INVALID_HANDLE_VALUE) return;

        const DWORD wait = ::WaitForSingleObject(thread, timeoutMs);
        if (wait != WAIT_OBJECT_0) {
            // This routine is intentionally restricted to our own ephemeral
            // OpenProcess thread, which owns no locks and performs no CRT work.
            ::TerminateThread(thread, ERROR_OPERATION_ABORTED);
            ::WaitForSingleObject(thread, 2000);
        }
        ::CloseHandle(thread);
    }
}
