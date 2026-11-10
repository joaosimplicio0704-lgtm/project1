#include "ThreadHandleMonitor.h"
#include <algorithm>
#include <utility>

namespace ss {

    ThreadHandleMonitor::State::State()
        : stopEvent(::CreateEventW(nullptr, TRUE, FALSE, nullptr))
    {
    }

    // State vive enquanto a thread de varredura tiver referencia a ele.
    // Sem isso, um stop() com timeout deixaria a thread tocar memoria morta.
    ThreadHandleMonitor::State::~State()
    {
        std::lock_guard<std::mutex> g(lock);
        for (HANDLE h : owned) {
            if (h) ::CloseHandle(h);
        }
        owned.clear();
        if (stopEvent) {
            ::CloseHandle(stopEvent);
            stopEvent = nullptr;
        }
    }

    std::size_t ThreadHandleMonitor::Reap(State& st)
    {
        std::size_t count = 0;
        std::lock_guard<std::mutex> g(st.lock);

        for (HANDLE& h : st.owned) {
            if (!h) continue;

            DWORD w = ::WaitForSingleObject(h, 0);
            if (w == WAIT_TIMEOUT) continue;    // ainda rodando

            if (w == WAIT_FAILED) {
                // ja fechado por outrem: descarta. erro transiente: tenta de novo.
                if (::GetLastError() == ERROR_INVALID_HANDLE) h = nullptr;
                continue;
            }
            if (w != WAIT_OBJECT_0) continue;

            // quem decide que terminou e o wait, nao exitCode == STILL_ACTIVE:
            // 259 tambem e um exit code legitimo.
            DWORD tid = ::GetThreadId(h);
            DWORD code = 0;
            if (!::GetExitCodeThread(h, &code)) code = ::GetLastError();

            // handle nosso, segurado desde track(): o valor nao pode ser
            // reutilizado por outra objeto antes deste CloseHandle.
            ::CloseHandle(h);
            h = nullptr;

            st.reaped.push_back(ReapedThread{ tid, code });
            st.reapedCount.fetch_add(1);
            ++count;
        }

        st.owned.erase(std::remove(st.owned.begin(), st.owned.end(), nullptr),
                       st.owned.end());
        return count;
    }

    DWORD WINAPI ThreadHandleMonitor::MonitorThread(LPVOID param)
    {
        auto holder = std::unique_ptr<std::shared_ptr<State>>(
            static_cast<std::shared_ptr<State>*>(param));
        std::shared_ptr<State> st = *holder;

        for (;;) {
            DWORD w = ::WaitForSingleObject(st->stopEvent, kReapTickMs);
            if (w == WAIT_OBJECT_0) break;
            Reap(*st);
        }
        Reap(*st);   // ultima passada depois do sinal de parada
        return 0;
    }

    ThreadHandleMonitor::ThreadHandleMonitor()
        : state_(std::make_shared<State>())
    {
    }

    ThreadHandleMonitor::~ThreadHandleMonitor()
    {
        if (!stop(kStopWaitMs)) {
            // timeout raro: o evento ja esta sinalizado, a thread sai no
            // proximo tick e ainda possui a propria copia do State.
            // fecha so o handle de thread, sem TerminateThread.
            ::CloseHandle(monitorThread_);
            monitorThread_ = nullptr;
            running_ = false;
        }
        state_.reset();
    }

    bool ThreadHandleMonitor::start()
    {
        if (running_) return true;
        if (!state_ || !state_->stopEvent) return false;

        auto holder = std::make_unique<std::shared_ptr<State>>(state_);
        HANDLE h = ::CreateThread(nullptr, 0, &MonitorThread, holder.get(), 0, nullptr);
        if (!h) return false;

        holder.release();          // a thread e dona da referencia agora
        monitorThread_ = h;
        running_ = true;
        return true;
    }

    bool ThreadHandleMonitor::stop(DWORD timeoutMs) noexcept
    {
        if (!running_ || !monitorThread_) return true;

        ::SetEvent(state_->stopEvent);
        if (::WaitForSingleObject(monitorThread_, timeoutMs) != WAIT_OBJECT_0) {
            return false;
        }

        ::CloseHandle(monitorThread_);
        monitorThread_ = nullptr;
        running_ = false;
        return true;
    }

    bool ThreadHandleMonitor::track(HANDLE hThread)
    {
        if (!state_ || !hThread || hThread == INVALID_HANDLE_VALUE) return false;
        if (::GetThreadId(hThread) == 0) return false;   // nao e handle de thread

        std::lock_guard<std::mutex> g(state_->lock);
        state_->owned.push_back(hThread);
        return true;
    }

    std::size_t ThreadHandleMonitor::reapNow()
    {
        return state_ ? Reap(*state_) : 0;
    }

    std::size_t ThreadHandleMonitor::reaped() const noexcept
    {
        return state_ ? state_->reapedCount.load() : 0;
    }

    std::vector<ReapedThread> ThreadHandleMonitor::takeReaped()
    {
        std::vector<ReapedThread> out;
        if (!state_) return out;

        std::lock_guard<std::mutex> g(state_->lock);
        out.swap(state_->reaped);
        return out;
    }

} // namespace ss
