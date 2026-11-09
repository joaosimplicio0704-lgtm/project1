#include "StealthyOpenProcess.h"
#include "xorstr.h"

// ============================================================
// StealthyOpenProcess v5 — Hardware Breakpoint, zero CRT, thread-safe
//
// Cria thread suspensa em stub de kernel32, arma HWBP (DR0)
// no stub address, redireciona via VEH SINGLE_STEP para
// OpenProcess e ExitThread. Callstack inteira dentro de kernel32.
//
// Vantagens vs v4 (PAGE_GUARD):
//   - HWBP eh per-thread: threads alheias NAO consomem o breakpoint
//   - elimina race condition de re-guard (reGuardTid removido)
//   - nao altera protecao de pagina (zero VirtualProtect PAGE_GUARD)
//   - nenhum SINGLE_STEP "vazado" para outros handlers
//   - compativel com hooks de CPU TID-gated
//
// Nota: DR0 eh usado na thread criada por nos, que eh efemera
// (<5ms). Qualquer hook que use DRs em threads existentes so
// acontece durante init/shutdown do hook, sem conflito.
// ============================================================

namespace StealthyOpenProcess {

    // ============================================================
    // Tipos internos
    // ============================================================

    enum class Stage : int32_t
    {
        Idle = 0,
        WaitingStubA,
        WaitingStubB,
        Completed
    };

    struct HWBPContext
    {
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

    // ============================================================
    // Estado global (protegido por s_Lock)
    // ============================================================

    static CRITICAL_SECTION s_Lock;
    static bool             s_Initialized = false;
    static HWBPContext      s_Ctx;

    // ============================================================
    // CRT-free helpers
    // ============================================================

    static void ZeroCtx()
    {
        SecureZeroMemory(&s_Ctx, sizeof(s_Ctx));
    }

    // ============================================================
    // DR0 helpers — arma/desarma execution breakpoint no slot 0
    //
    // DR7 layout para slot 0:
    //   Bit 0:     L0  (local enable)
    //   Bits 16-17: R/W0 (00 = execute)
    //   Bits 18-19: LEN0 (00 = 1 byte)
    // ============================================================

    static void ArmDR0(CONTEXT* ctx, uintptr_t addr)
    {
        ctx->Dr0 = addr;
        ctx->Dr7 |= 1ULL;             // L0 = 1
        ctx->Dr7 &= ~(0xFULL << 16);  // R/W0 = 00, LEN0 = 00
    }

    static void DisarmDR0(CONTEXT* ctx)
    {
        ctx->Dr0 = 0;
        ctx->Dr7 &= ~1ULL;            // L0 = 0
    }

    // ============================================================
    // VEH Handler — HWBP dois estagios, TID-gated
    //
    // So trata EXCEPTION_SINGLE_STEP da nossa thread.
    // Qualquer outra excecao/thread -> EXCEPTION_CONTINUE_SEARCH.
    // ============================================================

    static LONG WINAPI VEHHandler(EXCEPTION_POINTERS* ep)
    {
        if (ep->ExceptionRecord->ExceptionCode != STATUS_SINGLE_STEP)
            return EXCEPTION_CONTINUE_SEARCH;

        const DWORD tid = GetCurrentThreadId();
        if (tid != s_Ctx.targetThreadId)
            return EXCEPTION_CONTINUE_SEARCH;

        const uintptr_t rip = (uintptr_t)ep->ContextRecord->Rip;

        // ---- Stage A: thread atingiu stubA -> redireciona para OpenProcess ----
        if (s_Ctx.stage == Stage::WaitingStubA && rip == s_Ctx.stubA)
        {
            // alinha RSP (ABI x64: 16-byte aligned antes do CALL)
            ep->ContextRecord->Rsp &= ~0xFull;
            ep->ContextRecord->Rsp -= 8;
            *(uintptr_t*)(ep->ContextRecord->Rsp) = s_Ctx.stubB;

            // OpenProcess(dwDesiredAccess, FALSE, dwProcessId)
            ep->ContextRecord->Rcx = (DWORD64)s_Ctx.desiredAccess;
            ep->ContextRecord->Rdx = (DWORD64)FALSE;
            ep->ContextRecord->R8 = (DWORD64)s_Ctx.processId;
            ep->ContextRecord->Rip = s_Ctx.pOpenProcess;

            // move DR0 para stubB (Stage B)
            ArmDR0(ep->ContextRecord, s_Ctx.stubB);

            // RF (Resume Flag): previne re-fire no novo RIP
            ep->ContextRecord->EFlags |= 0x10000;

            s_Ctx.stage = Stage::WaitingStubB;
            return EXCEPTION_CONTINUE_EXECUTION;
        }

        // ---- Stage B: OpenProcess retornou -> captura resultado, ExitThread ----
        if (s_Ctx.stage == Stage::WaitingStubB && rip == s_Ctx.stubB)
        {
            s_Ctx.resultHandle = (HANDLE)ep->ContextRecord->Rax;

            ep->ContextRecord->Rsp &= ~0xFull;
            ep->ContextRecord->Rsp -= 8;
            *(uintptr_t*)(ep->ContextRecord->Rsp) = 0;

            // ExitThread(0)
            ep->ContextRecord->Rcx = 0;
            ep->ContextRecord->Rip = s_Ctx.pExitThread;

            DisarmDR0(ep->ContextRecord);
            ep->ContextRecord->EFlags |= 0x10000; // RF

            s_Ctx.stage = Stage::Completed;
            return EXCEPTION_CONTINUE_EXECUTION;
        }

        // nao eh o nosso breakpoint esperado — passa para outros handlers
        return EXCEPTION_CONTINUE_SEARCH;
    }

    // ============================================================
    // Busca par de stubs em kernel32 (executable, enderecos distintos)
    //
    // Com HWBP nao precisam estar em paginas diferentes.
    // Os stubs nunca executam — o breakpoint dispara ANTES.
    // ============================================================

    static bool TryPair(HMODULE hK32,
        const char* nameA, const char* nameB,
        uintptr_t& outA, uintptr_t& outB)
    {
        void* pA = (void*)GetProcAddress(hK32, nameA);
        void* pB = (void*)GetProcAddress(hK32, nameB);
        if (!pA || !pB)   return false;
        if (pA == pB)     return false;

        MEMORY_BASIC_INFORMATION mbiA{}, mbiB{};

        if (!VirtualQuery(pA, &mbiA, sizeof(mbiA))) return false;
        if (!VirtualQuery(pB, &mbiB, sizeof(mbiB))) return false;

        const DWORD execMask = PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE;
        if (!(mbiA.Protect & execMask) || !(mbiB.Protect & execMask))
            return false;

        outA = (uintptr_t)pA;
        outB = (uintptr_t)pB;
        return true;
    }

    static bool FindStubPair(HMODULE hK32, uintptr_t& outA, uintptr_t& outB)
    {
        // pares de funcoes nao sensiveis em kernel32,
        // mais comuns/estaveis primeiro, fallback para locales.

        if (TryPair(hK32, XorStr("GetProfileIntA"), XorStr("lstrcpyW"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("GetProfileStringA"), XorStr("lstrcatA"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("WriteProfileStringA"), XorStr("GetPrivateProfileIntA"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("GetProfileIntW"), XorStr("lstrcpyA"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("GetLocaleInfoA"), XorStr("IsDBCSLeadByte"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("GetDateFormatA"), XorStr("GetTimeFormatA"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("CompareStringA"), XorStr("LCMapStringA"), outA, outB)) return true;
        if (TryPair(hK32, XorStr("GetSystemDefaultLangID"), XorStr("GetOEMCP"), outA, outB)) return true;

        return false;
    }

    // ============================================================
    // Initialize / Shutdown
    // ============================================================

    bool Initialize()
    {
        if (s_Initialized) return true;
        InitializeCriticalSection(&s_Lock);
        ZeroCtx();
        s_Initialized = true;
        return true;
    }

    void Shutdown()
    {
        if (!s_Initialized) return;

        EnterCriticalSection(&s_Lock);

        if (s_Ctx.vehHandle)
        {
            s_Ctx.stage = Stage::Idle;
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            s_Ctx.vehHandle = nullptr;
        }

        ZeroCtx();
        LeaveCriticalSection(&s_Lock);

        DeleteCriticalSection(&s_Lock);
        s_Initialized = false;
    }

    // ============================================================
    // Execute — abre handle para processo alvo
    //
    // Thread-safe: chamadas concorrentes serializadas por
    // CRITICAL_SECTION. Cada chamada cria uma thread efemera
    // com HWBP proprio — sem interferencia com threads alheias.
    // ============================================================

    HANDLE Execute(DWORD dwProcessId, DWORD dwDesiredAccess)
    {
        if (!s_Initialized)
            Initialize();

        EnterCriticalSection(&s_Lock);

        // ---- resolve kernel32 ----
        HMODULE hK32 = xorstr("kernel32.dll").use([](const char* s) {
            return GetModuleHandleA(s);
            });

        if (!hK32)
        {
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        // ---- par de stubs ----
        uintptr_t stubA = 0, stubB = 0;
        if (!FindStubPair(hK32, stubA, stubB))
        {
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        // ---- resolve APIs ----
        void* pOpenProcess = xorstr("OpenProcess").use([&](const char* s) -> void* {
            return (void*)GetProcAddress(hK32, s);
            });
        void* pExitThread = xorstr("ExitThread").use([&](const char* s) -> void* {
            return (void*)GetProcAddress(hK32, s);
            });

        if (!pOpenProcess || !pExitThread)
        {
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        // ---- contexto ----
        ZeroCtx();
        s_Ctx.stubA = stubA;
        s_Ctx.stubB = stubB;
        s_Ctx.desiredAccess = dwDesiredAccess;
        s_Ctx.processId = dwProcessId;
        s_Ctx.pOpenProcess = (uintptr_t)pOpenProcess;
        s_Ctx.pExitThread = (uintptr_t)pExitThread;
        s_Ctx.stage = Stage::Idle;

        // ---- registra VEH (prioridade maxima) ----
        s_Ctx.vehHandle = AddVectoredExceptionHandler(TRUE, VEHHandler);
        if (!s_Ctx.vehHandle)
        {
            ZeroCtx();
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        // ---- cria thread suspensa no stub de kernel32 ----
        DWORD threadId = 0;
        HANDLE hThread = CreateThread(
            nullptr, 0,
            (LPTHREAD_START_ROUTINE)stubA,
            nullptr,
            CREATE_SUSPENDED,
            &threadId);

        if (!hThread)
        {
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            s_Ctx.vehHandle = nullptr;
            ZeroCtx();
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        s_Ctx.targetThreadId = threadId;

        // ---- arma HWBP (DR0) na thread suspensa ----
        // DR0 = stubA, tipo = execucao, tamanho = 1 byte.
        // Thread nova tem DRs zerados — sem conflito com hooks ja instalados.
        CONTEXT ctx;
        SecureZeroMemory(&ctx, sizeof(ctx));
        ctx.ContextFlags = CONTEXT_DEBUG_REGISTERS;

        if (!GetThreadContext(hThread, &ctx))
        {
            TerminateThread(hThread, 0);
            CloseHandle(hThread);
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            s_Ctx.vehHandle = nullptr;
            ZeroCtx();
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        ArmDR0(&ctx, stubA);

        if (!SetThreadContext(hThread, &ctx))
        {
            TerminateThread(hThread, 0);
            CloseHandle(hThread);
            RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
            s_Ctx.vehHandle = nullptr;
            ZeroCtx();
            LeaveCriticalSection(&s_Lock);
            return nullptr;
        }

        // ---- resume e espera ----
        s_Ctx.stage = Stage::WaitingStubA;
        ResumeThread(hThread);

        // OpenProcess eh quase instantaneo — 2s ja eh folga.
        if (WaitForSingleObject(hThread, 2000) == WAIT_TIMEOUT)
        {
            if (WaitForSingleObject(hThread, 1000) == WAIT_TIMEOUT)
            {
                // thread travou. DRs morrem junto com a thread.
                TerminateThread(hThread, 0);
                WaitForSingleObject(hThread, 1000);
            }
        }

        // ---- thread morta — seguro limpar tudo ----
        CloseHandle(hThread);

        HANDLE result = nullptr;

        if (s_Ctx.stage == Stage::Completed)
        {
            result = s_Ctx.resultHandle;
        }
        else if (s_Ctx.resultHandle)
        {
            CloseHandle(s_Ctx.resultHandle);
        }

        // ---- remove VEH ----
        s_Ctx.stage = Stage::Idle;
        RemoveVectoredExceptionHandler(s_Ctx.vehHandle);
        s_Ctx.vehHandle = nullptr;

        ZeroCtx();
        LeaveCriticalSection(&s_Lock);
        return result;
    }

} // namespace StealthyOpenProcess
