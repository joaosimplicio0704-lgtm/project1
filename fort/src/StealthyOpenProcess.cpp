#include "StealthyOpenProcess.h"

#include "closehandle.h"

#include <cstdint>

// Adapted from the supplied v5 HWBP/VEH implementation. The missing XorStr
// dependency is removed, access defaults to read-only, and every owned thread
// is finished before its VEH and context are torn down.
namespace StealthyOpenProcess {
    static_assert(sizeof(void*) == 8, "StealthyOpenProcess requires Windows x64");

    enum class Stage : int {
        Idle = 0,
        WaitingStubA,
        WaitingStubB,
        Completed
    };

    struct HWBPContext {
        volatile Stage stage;
        DWORD targetThreadId;
        std::uintptr_t stubA;
        std::uintptr_t stubB;
        DWORD desiredAccess;
        DWORD processId;
        std::uintptr_t openProcess;
        std::uintptr_t exitThread;
        HANDLE resultHandle;
        DWORD resultError;
        PVOID vehHandle;
    };

    static CRITICAL_SECTION s_lock;
    static bool s_initialized = false;
    static HWBPContext s_context;
    static DWORD s_lastError = ERROR_SUCCESS;

    static void ZeroContext() noexcept {
        ::SecureZeroMemory(&s_context, sizeof(s_context));
    }

    static void ArmDR0(CONTEXT* context, std::uintptr_t address) noexcept {
        context->Dr0 = address;
        context->Dr7 |= 1ULL;
        context->Dr7 &= ~(0xFULL << 16);
    }

    static void DisarmDR0(CONTEXT* context) noexcept {
        context->Dr0 = 0;
        context->Dr7 &= ~1ULL;
    }

    static __declspec(noinline) LONG WINAPI VectoredHandler(EXCEPTION_POINTERS* exception) {
        if (exception->ExceptionRecord->ExceptionCode != STATUS_SINGLE_STEP) {
            return EXCEPTION_CONTINUE_SEARCH;
        }
        if (::GetCurrentThreadId() != s_context.targetThreadId) {
            return EXCEPTION_CONTINUE_SEARCH;
        }

        CONTEXT* context = exception->ContextRecord;
        const std::uintptr_t rip = static_cast<std::uintptr_t>(context->Rip);

        if (s_context.stage == Stage::WaitingStubA && rip == s_context.stubA) {
            // At an x64 function entry RSP % 16 must be 8. The synthetic return
            // address sends OpenProcess back to stubB, where stage B captures it.
            context->Rsp &= ~0xFULL;
            context->Rsp -= 8;
            *reinterpret_cast<std::uintptr_t*>(context->Rsp) = s_context.stubB;

            context->Rcx = static_cast<DWORD64>(s_context.desiredAccess);
            context->Rdx = static_cast<DWORD64>(FALSE);
            context->R8 = static_cast<DWORD64>(s_context.processId);
            context->Rip = s_context.openProcess;

            ArmDR0(context, s_context.stubB);
            context->EFlags |= 0x10000;
            s_context.stage = Stage::WaitingStubB;
            return EXCEPTION_CONTINUE_EXECUTION;
        }

        if (s_context.stage == Stage::WaitingStubB && rip == s_context.stubB) {
            s_context.resultHandle = reinterpret_cast<HANDLE>(context->Rax);
            s_context.resultError = s_context.resultHandle ? ERROR_SUCCESS : ::GetLastError();

            context->Rsp &= ~0xFULL;
            context->Rsp -= 8;
            *reinterpret_cast<std::uintptr_t*>(context->Rsp) = 0;

            context->Rcx = 0;
            context->Rip = s_context.exitThread;
            DisarmDR0(context);
            context->EFlags |= 0x10000;
            s_context.stage = Stage::Completed;
            return EXCEPTION_CONTINUE_EXECUTION;
        }

        return EXCEPTION_CONTINUE_SEARCH;
    }

    static bool TryPair(HMODULE kernel32, const char* nameA, const char* nameB,
                        std::uintptr_t& outputA, std::uintptr_t& outputB) noexcept {
        void* addressA = reinterpret_cast<void*>(::GetProcAddress(kernel32, nameA));
        void* addressB = reinterpret_cast<void*>(::GetProcAddress(kernel32, nameB));
        if (!addressA || !addressB || addressA == addressB) return false;

        MEMORY_BASIC_INFORMATION informationA{};
        MEMORY_BASIC_INFORMATION informationB{};
        if (!::VirtualQuery(addressA, &informationA, sizeof(informationA)) ||
            !::VirtualQuery(addressB, &informationB, sizeof(informationB))) {
            return false;
        }

        constexpr DWORD executableMask = PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE;
        if (!(informationA.Protect & executableMask) || !(informationB.Protect & executableMask)) {
            return false;
        }

        outputA = reinterpret_cast<std::uintptr_t>(addressA);
        outputB = reinterpret_cast<std::uintptr_t>(addressB);
        return true;
    }

    static bool FindStubPair(HMODULE kernel32, std::uintptr_t& outputA,
                             std::uintptr_t& outputB) noexcept {
        if (TryPair(kernel32, "GetProfileIntA", "lstrcpyW", outputA, outputB)) return true;
        if (TryPair(kernel32, "GetProfileStringA", "lstrcatA", outputA, outputB)) return true;
        if (TryPair(kernel32, "WriteProfileStringA", "GetPrivateProfileIntA", outputA, outputB)) return true;
        if (TryPair(kernel32, "GetProfileIntW", "lstrcpyA", outputA, outputB)) return true;
        if (TryPair(kernel32, "GetLocaleInfoA", "IsDBCSLeadByte", outputA, outputB)) return true;
        if (TryPair(kernel32, "GetDateFormatA", "GetTimeFormatA", outputA, outputB)) return true;
        if (TryPair(kernel32, "CompareStringA", "LCMapStringA", outputA, outputB)) return true;
        return TryPair(kernel32, "GetSystemDefaultLangID", "GetOEMCP", outputA, outputB);
    }

    bool Initialize() {
        if (s_initialized) return true;
        ::InitializeCriticalSection(&s_lock);
        ZeroContext();
        s_lastError = ERROR_SUCCESS;
        s_initialized = true;
        return true;
    }

    void Shutdown() {
        if (!s_initialized) return;
        ::EnterCriticalSection(&s_lock);
        if (s_context.vehHandle) {
            s_context.stage = Stage::Idle;
            ::RemoveVectoredExceptionHandler(s_context.vehHandle);
            s_context.vehHandle = nullptr;
        }
        ZeroContext();
        ::LeaveCriticalSection(&s_lock);
        ::DeleteCriticalSection(&s_lock);
        s_lastError = ERROR_SUCCESS;
        s_initialized = false;
    }

    DWORD LastError() noexcept {
        return s_lastError;
    }

    static HANDLE FailLocked(DWORD error) noexcept {
        if (s_context.vehHandle) {
            ::RemoveVectoredExceptionHandler(s_context.vehHandle);
            s_context.vehHandle = nullptr;
        }
        ZeroContext();
        s_lastError = error;
        ::LeaveCriticalSection(&s_lock);
        return nullptr;
    }

    __declspec(noinline) HANDLE Execute(DWORD processId, DWORD desiredAccess) noexcept {
        if (!s_initialized) Initialize();
        ::EnterCriticalSection(&s_lock);
        ZeroContext();
        s_lastError = ERROR_SUCCESS;

        HMODULE kernel32 = ::GetModuleHandleA("kernel32.dll");
        if (!kernel32) return FailLocked(ERROR_MOD_NOT_FOUND);

        std::uintptr_t stubA = 0;
        std::uintptr_t stubB = 0;
        if (!FindStubPair(kernel32, stubA, stubB)) return FailLocked(ERROR_PROC_NOT_FOUND);

        void* openProcess = reinterpret_cast<void*>(::GetProcAddress(kernel32, "OpenProcess"));
        void* exitThread = reinterpret_cast<void*>(::GetProcAddress(kernel32, "ExitThread"));
        if (!openProcess || !exitThread) return FailLocked(::GetLastError());

        s_context.stubA = stubA;
        s_context.stubB = stubB;
        s_context.desiredAccess = desiredAccess;
        s_context.processId = processId;
        s_context.openProcess = reinterpret_cast<std::uintptr_t>(openProcess);
        s_context.exitThread = reinterpret_cast<std::uintptr_t>(exitThread);
        s_context.stage = Stage::Idle;

        s_context.vehHandle = ::AddVectoredExceptionHandler(TRUE, VectoredHandler);
        if (!s_context.vehHandle) return FailLocked(::GetLastError());

        DWORD threadId = 0;
        HANDLE thread = ::CreateThread(nullptr, 0,
            reinterpret_cast<LPTHREAD_START_ROUTINE>(stubA), nullptr, CREATE_SUSPENDED, &threadId);
        if (!thread) return FailLocked(::GetLastError());
        s_context.targetThreadId = threadId;

        CONTEXT context{};
        context.ContextFlags = CONTEXT_DEBUG_REGISTERS;
        if (!::GetThreadContext(thread, &context)) {
            const DWORD error = ::GetLastError();
            HandleCleanup::FinishOwnedThread(thread, 0);
            return FailLocked(error);
        }

        ArmDR0(&context, stubA);
        if (!::SetThreadContext(thread, &context)) {
            const DWORD error = ::GetLastError();
            HandleCleanup::FinishOwnedThread(thread, 0);
            return FailLocked(error);
        }

        s_context.stage = Stage::WaitingStubA;
        if (::ResumeThread(thread) == static_cast<DWORD>(-1)) {
            const DWORD error = ::GetLastError();
            HandleCleanup::FinishOwnedThread(thread, 0);
            return FailLocked(error);
        }

        HandleCleanup::FinishOwnedThread(thread, 10000);
        const Stage finalStage = s_context.stage;
        HANDLE result = nullptr;
        DWORD resultError = s_context.resultError;

        if (finalStage == Stage::Completed) {
            result = s_context.resultHandle;
        } else {
            if (s_context.resultHandle) ::CloseHandle(s_context.resultHandle);
            resultError = resultError == ERROR_SUCCESS ? ERROR_TIMEOUT : resultError;
        }

        if (s_context.vehHandle) {
            s_context.stage = Stage::Idle;
            ::RemoveVectoredExceptionHandler(s_context.vehHandle);
            s_context.vehHandle = nullptr;
        }
        ZeroContext();
        s_lastError = result ? ERROR_SUCCESS : resultError;
        ::LeaveCriticalSection(&s_lock);
        return result;
    }
}
