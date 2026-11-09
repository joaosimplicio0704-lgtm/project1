#include "handle_cleanup.h"

#include <atomic>
#include <new>

namespace HandleCleanup {

static std::atomic<bool> s_Stop{ false };
static HANDLE            s_Thread = nullptr;

// ============================================================
// Heuristica: exit code que nao parece saida normal de thread
// (0, STILL_ACTIVE, AV, Ctrl-C, fatal app exit ficam de fora)
// ============================================================
static inline bool IsLikelyUnknownExitStatus(DWORD code)
{
    if (code == 0 || code == 259 /* STILL_ACTIVE */) return false;

    switch (code)
    {
    case 0xC0000005: // STATUS_ACCESS_VIOLATION
    case 0xC000013A: // STATUS_CONTROL_C_EXIT
    case 0x40000015: // STATUS_FATAL_APP_EXIT
        return false;
    }
    return (code & 0xFFFF0000u) != 0;
}

struct SystemHandleEntry
{
    PVOID     Object;
    ULONG_PTR UniqueProcessId;
    ULONG_PTR HandleValue;
    ULONG     GrantedAccess;
    USHORT    CreatorBackTraceIndex;
    USHORT    ObjectTypeIndex;
    ULONG     HandleAttributes;
    ULONG     Reserved;
};

struct SystemHandleInformation
{
    ULONG_PTR        NumberOfHandles;
    ULONG_PTR        Reserved;
    SystemHandleEntry Handles[1];
};

size_t Sweep()
{
    typedef LONG(NTAPI* NtQuerySystemInformation_t)(ULONG, PVOID, ULONG, PULONG);

    const ULONG SystemExtendedHandleInformationClass = 64;
    const LONG  StatusInfoLengthMismatch = (LONG)0xC0000004;

    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    if (!ntdll) return 0;

    auto NtQuerySystemInformation =
        reinterpret_cast<NtQuerySystemInformation_t>(GetProcAddress(ntdll, "NtQuerySystemInformation"));
    if (!NtQuerySystemInformation) return 0;

    const DWORD selfPid = GetCurrentProcessId();
    HANDLE self = GetCurrentProcess();

    size_t closed = 0;
    ULONG bufSize = 1u << 20;
    BYTE* buffer = nullptr;

    for (;;) {
        delete[] buffer;
        buffer = new (std::nothrow) BYTE[bufSize];
        if (!buffer) return closed;

        ULONG needed = 0;
        LONG status = NtQuerySystemInformation(SystemExtendedHandleInformationClass, buffer, bufSize, &needed);

        if (status == StatusInfoLengthMismatch) {
            bufSize = (needed > bufSize) ? needed : (bufSize << 1);
            continue;
        }
        if (status < 0) {
            delete[] buffer;
            return closed;
        }
        break;
    }

    auto info = reinterpret_cast<SystemHandleInformation*>(buffer);

    for (ULONG_PTR i = 0; i < info->NumberOfHandles; ++i) {
        const auto& entry = info->Handles[i];
        if ((DWORD)(ULONG_PTR)entry.UniqueProcessId != (DWORD)selfPid)
            continue;

        HANDLE source = (HANDLE)(ULONG_PTR)entry.HandleValue;
        HANDLE dup = nullptr;

        if (!DuplicateHandle(self, source, self, &dup, THREAD_QUERY_LIMITED_INFORMATION, FALSE, 0)) {
            if (!DuplicateHandle(self, source, self, &dup, 0, FALSE, DUPLICATE_SAME_ACCESS))
                continue;
        }

        const DWORD tid = GetThreadId(dup);
        if (tid == 0) {
            CloseHandle(dup);
            continue;
        }

        DWORD exitCode = 0;
        if (!GetExitCodeThread(dup, &exitCode)) {
            CloseHandle(dup);
            continue;
        }

        CloseHandle(dup);

        if (!IsLikelyUnknownExitStatus(exitCode))
            continue;

        DWORD flags = 0;
        if (GetHandleInformation(source, &flags) && (flags & HANDLE_FLAG_PROTECT_FROM_CLOSE)) {
            SetHandleInformation(source, HANDLE_FLAG_PROTECT_FROM_CLOSE, 0);
        }

        if (CloseHandle(source))
            ++closed;
    }

    delete[] buffer;
    return closed;
}

// ============================================================
// Thread que monitora e fecha continuamente handles "Unknown"
// ============================================================
static DWORD WINAPI MonitorThread(LPVOID)
{
    int emptyChecks = 0;

    while (!s_Stop.load(std::memory_order_relaxed)) {
        const size_t count = Sweep();

        if (count == 0) {
            // 3 varreduras vazias seguidas (~20s) e a thread se aposenta
            if (++emptyChecks >= 3)
                break;
            Sleep(10000);
        } else {
            emptyChecks = 0;
            Sleep(500);
        }
    }

    return 0;
}

bool Start()
{
    if (s_Thread)
        return true;

    s_Stop.store(false);
    s_Thread = CreateThread(nullptr, 0, MonitorThread, nullptr, 0, nullptr);
    return s_Thread != nullptr;
}

void Stop()
{
    if (!s_Thread)
        return;

    s_Stop.store(true);

    if (WaitForSingleObject(s_Thread, 3000) == WAIT_TIMEOUT)
        TerminateThread(s_Thread, 0);

    CloseHandle(s_Thread);
    s_Thread = nullptr;
}

} // namespace HandleCleanup
