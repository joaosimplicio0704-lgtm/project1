#pragma once
#include <Windows.h>
#include <atomic>
#include <cstddef>
#include <memory>
#include <mutex>
#include <vector>

// ============================================================
// ThreadHandleMonitor — substitui closehandle.cpp
//
// So mexe em handles que voce registrou explicitamente.
// Nada de NtQuerySystemInformation, nada de CloseHandle por
// valor de snapshot, nada de TerminateThread, nada de stub
// de start address. Nada dispara na construcao.
// ============================================================

namespace ss {

    constexpr DWORD kReapTickMs = 250;
    constexpr DWORD kStopWaitMs = 3000;

    struct ReapedThread {
        DWORD threadId;
        DWORD exitCode;
    };

    class ThreadHandleMonitor {
    public:
        ThreadHandleMonitor();
        ~ThreadHandleMonitor();
        ThreadHandleMonitor(const ThreadHandleMonitor&) = delete;
        ThreadHandleMonitor& operator=(const ThreadHandleMonitor&) = delete;

        // liga a thread de varredura. opcional: reapNow() funciona sem ela.
        [[nodiscard]] bool start();

        // sinaliza e espera. nunca mata a thread; false = timeout.
        [[nodiscard]] bool stop(DWORD timeoutMs = kStopWaitMs) noexcept;

        // toma posse do handle (precisa THREAD_QUERY_LIMITED_INFORMATION).
        // se retornar false, o chamador continua dono e deve fechar.
        [[nodiscard]] bool track(HANDLE hThread);

        // varredura sincrona, util se voce ja tem seu proprio loop de tick.
        [[nodiscard]] std::size_t reapNow();

        [[nodiscard]] std::size_t reaped() const noexcept;
        [[nodiscard]] std::vector<ReapedThread> takeReaped();

    private:
        struct State {
            State();
            ~State();
            State(const State&) = delete;
            State& operator=(const State&) = delete;

            std::mutex                 lock;
            std::vector<HANDLE>        owned;
            std::vector<ReapedThread>  reaped;
            std::atomic<std::size_t>   reapedCount{ 0 };
            HANDLE                     stopEvent;
        };

        static DWORD WINAPI MonitorThread(LPVOID param);
        static std::size_t Reap(State& st);

        std::shared_ptr<State> state_;
        HANDLE                 monitorThread_ = nullptr;
        bool                   running_ = false;
    };

} // namespace ss
