#include "StealthyOpenProcess.h"

// ============================================================
// StealthyOpenProcess v5 — Hardware Breakpoint, zero CRT, thread-safe
// Cria thread suspensa em stub de kernel32, armaz HWBP (DR0) no endereco do stub,
// redireciona via VEH SINGLE_STEP para OpenProcess e ExitThread.
// Callstack inteira dentro de kernel32.
// ============================================================

namespace StealthyOpenProcess {

    enum class Stage : int { Idle = 0, WaitingStubA, WaitingStubB, Completed };

    struct HWBPContext {
        volatile Stage  stage;
        DWORD           targetThreadId;
        uintptr_t       stubA;
        uintptr_t       stubB;
        DWORD           desiredAccess;
        DWORD           processId;
        uintptr_t       pOpenProcess;
        uintptr_t       pExitThread;
        HANDLE          resultHandle;
        PVOID           vehHandle;
    };

    static CRITICAL_SECTION s_Lock;
    static bool             s_Initialized = false;
    static HWBPContext      s_Ctx;

    static void ZeroCtx() { SecureZeroMemory(&s_Ctx, sizeof(s_Ctx)); }

    static void ArmDR0(CONTEXT* ctx, uintptr_t addr) {
        ctx->Dr0 = addr;
        ctx->Dr7 |= 1ULL;
        ctx->Dr7 &= ~(0xFULL << 16);
    }

    static void DisarmDR0(CONTEXT* ctx) {
        ctx->Dr0 = 0;
        ctx->Dr7 &= ~1ULL;
    }

    static __declspec(noinline) LONG WINAPI VEHHandler(EXCEPTION_POINTERS* ep) {
        if (ep->ExceptionRecord->ExceptionCode != STATUS_SINGLE_STEP)
            return EXCEPTION_CONTINUE_SEARCH;

        DWORD tid = GetCurrentThreadId();
        if (tid != s_Ctx.targetThreadId)
            return EXCEPTION_CONTINUE_SEARCH;

        uintptr_t rip = (uintptr_t)ep->ContextRecord->Rip;

        if (s_Ctx.stage == Stage::WaitingStubA && rip == s_Ctx.stubA) {
            ep->ContextRecord->Rsp &= ~0xFull;
            ep->ContextRecord->Rsp -= 8;
            *(uintptr_t*)(ep->ContextRecord->Rsp) = s_Ctx.stubB;

            ep->ContextRecord->Rcx = (DWORD64)s_Ctx.desiredAccess;
            ep->ContextRecord->Rdx = (DWORD64)FALSE;
            ep->ContextRecord->R8  = (DWORD64)s_Ctx.processId;
            ep->ContextRecord->Rip = s_Ctx.pOpenProcess;

            ArmDR0(ep->ContextRecord, s_Ctx.stubB);
            ep->ContextRecord->EFlags |= 0x10000;

            s_Ctx.stage = Stage::WaitingStubB;
            return EXCEPTION_CONTINUE_EXECUTION;
        }

        if (s_Ctx.stage == Stage::WaitingStubB && rip == s_Ctx.stubB) {
            s_Ctx.resultHandle = (HANDLE)ep->ContextRecord->Rax;

            ep->ContextRecord->Rsp &= ~0xFull;
            ep->ContextRecord->Rsp -= 8;
            *(uintptr_t*)(ep->ContextRecord->Rsp) = 0;

            ep->ContextRecord->Rcx = 0;
            ep->ContextRecord->Rip = s_Ctx.pExitThread;

            DisarmDR0(ep->ContextRecord);
            ep->ContextRecord->EFlags |= 0x10000;

            s_Ctx.stage = Stage::Completed;
            return EXCEPTION_CONTINUE_EXECUTION;
        }

        return EXCEPTION_CONTINUE_SEARCH;
    }

    static bool TryPair(HMODULE hK32, const char* nameA, const char* nameB,
                        uintptr_t& outA, uintptr_t& outB) {
        void* pA = GetProcAddress(hK32, nameA);
        void* pB = GetProcAddress(hK32, nameB);
        if (!pA || !pB) return false;
        if (pA == pB) return false;

        MEMORY_BASIC_INFORMATION mbiA, mbiB;
        SecureZeroMemory(&mbiA, sizeof(mbiA));
        SecureZeroMemory(&mbiB, sizeof(mbiB));
        if (!VirtualQuery(pA, &mbiA, sizeof(mbiA))) return false;
        if (!VirtualQuery(pB, &mbiB, sizeof(mbiB))) return false;

        DWORD execMask = PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE;
        if (!(mbiA.Protect & execMask) || !(mbiB.Protect & execMask)) return false;

        outA = (uintptr_t)pA;
        outB = (uintptr_t)pB;
        return true;
    }

    static bool FindStubPair(HMODULE hK32, uintptr_t& outA, uintptr_t& outB) {
        if (TryPair(hK32, "GetProfileIntA", "lstrcpyW", outA, outB)) return true;
        if (TryPair(hK32, "GetProfileStringA", "lstrcatA", outA, outB)) return true;
        if (TryPair(hK32, "WriteProfileStringA", "GetPrivateProfileIntA", outA, outB)) return true;
        if (TryPair(hK32, "GetProfileIntW", "lstrcpyA", outA, outB)) return true;
        if (TryPair(hK32, "GetLocaleInfoA", "IsDBCSLeadByte", outA, outB)) return true;
        if (TryPair(hK32, "GetDateFormatA", "GetTimeFormatA", outA, outB)) return true;
        if (TryPair(hK32, "CompareStringA", "LCMapStringA", outA, outB)) return true;
        if (TryPair(hK32, "GetSystemDefaultLangID", "GetOEMCP", outA, outB)) return true;
        return false;
    }

    bool Initialize() {
        if (s_Initialized) return true;
        InitializeCriticalSection(&s_Lock);
        ZeroCtx();
        s_Initialized = true;
        return true;
    }

    void Shutdown() {
        if (!s_Initialized) return;
        EnterCriticalSection(&s_Lock);
        if (s_Ctx.vehHandle) {
            s_Ctx.stage = Stage::Idle;
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            s_Ctx.vehHandle = nullptr;
        }
        ZeroCtx();
        LeaveCriticalSection(&s_Lock);
        DeleteCriticalSection(&s_Lock);
        s_Initialized = false;
    }

    __declspec(noinline) HANDLE Execute(DWORD dwProcessId, DWORD dwDesiredAccess) {
        if (!s_Initialized) Initialize();
        EnterCriticalSection(&s_Lock);

        HMODULE hK32 = GetModuleHandleA("kernel32.dll");
        if (!hK32) { LeaveCriticalSection(&s_Lock); return nullptr; }

        uintptr_t stubA = 0, stubB = 0;
        if (!FindStubPair(hK32, stubA, stubB)) { LeaveCriticalSection(&s_Lock); return nullptr; }

        void* pOpenProcess = (void*)GetProcAddress(hK32, "OpenProcess");
        void* pExitThread  = (void*)GetProcAddress(hK32, "ExitThread");
        if (!pOpenProcess || !pExitThread) { LeaveCriticalSection(&s_Lock); return nullptr; }

        ZeroCtx();
        s_Ctx.stubA = stubA;
        s_Ctx.stubB = stubB;
        s_Ctx.desiredAccess = dwDesiredAccess;
        s_Ctx.processId = dwProcessId;
        s_Ctx.pOpenProcess = (uintptr_t)pOpenProcess;
        s_Ctx.pExitThread = (uintptr_t)pExitThread;
        s_Ctx.stage = Stage::Idle;

        s_Ctx.vehHandle = AddVectoredExceptionHandler(TRUE, VEHHandler);
        if (!s_Ctx.vehHandle) { ZeroCtx(); LeaveCriticalSection(&s_Lock); return nullptr; }

        DWORD threadId = 0;
        HANDLE hThread = CreateThread(
            nullptr, 0,
            (LPTHREAD_START_ROUTINE)stubA,
            nullptr, CREATE_SUSPENDED, &threadId);

        if (!hThread) {
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            ZeroCtx(); LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        s_Ctx.targetThreadId = threadId;

        CONTEXT ctx;
        SecureZeroMemory(&ctx, sizeof(ctx));
        ctx.ContextFlags = CONTEXT_DEBUG_REGISTERS;
        if (!GetThreadContext(hThread, &ctx)) {
            TerminateThread(hThread, 0); CloseHandle(hThread);
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            ZeroCtx(); LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        ArmDR0(&ctx, stubA);
        if (!SetThreadContext(hThread, &ctx)) {
            TerminateThread(hThread, 0); CloseHandle(hThread);
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            ZeroCtx(); LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        s_Ctx.stage = Stage::WaitingStubA;
        ResumeThread(hThread);

        DWORD wait = WaitForSingleObject(hThread, 5000);
        if (wait == WAIT_TIMEOUT) {
            wait = WaitForSingleObject(hThread, 5000);
            if (wait == WAIT_TIMEOUT) {
                TerminateThread(hThread, 0);
                WaitForSingleObject(hThread, 2000);
            }
        }

        CloseHandle(hThread);

        Stage finalStage = s_Ctx.stage;
        HANDLE result = nullptr;
        if (finalStage == Stage::Completed) {
            result = s_Ctx.resultHandle;
        } else {
            if (s_Ctx.resultHandle) { CloseHandle(s_Ctx.resultHandle); s_Ctx.resultHandle = nullptr; }
        }

        s_Ctx.stage = Stage::Idle;
        RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
        s_Ctx.vehHandle = nullptr;

        ZeroCtx();
        LeaveCriticalSection(&s_Lock);
        return result;
    }

} // namespace StealthyOpenProcess
