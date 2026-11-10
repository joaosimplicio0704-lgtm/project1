#include "ProcessHandle.h"
#include "ThreadHandleMonitor.h"
#include <cstdint>
#include <cstdio>
#include <cwchar>

namespace {

    DWORD WINAPI Worker(LPVOID)
    {
        ::Sleep(200);
        return 0x1234;
    }

} // namespace

int wmain(int argc, wchar_t** argv)
{
    DWORD pid = ::GetCurrentProcessId();
    if (argc > 1) pid = static_cast<DWORD>(std::wcstoul(argv[1], nullptr, 10));

    ss::ProcessHandle ph = ss::OpenReadOnly(pid);
    if (!ph) {
        std::wprintf(L"OpenProcess(%lu) falhou: GetLastError=%lu\n", pid, ph.lastError());
        return 1;
    }
    std::wprintf(L"handle ok: pid=%lu handle=%p\n", pid, ph.get());

    // so le a base do proprio processo: ASLR de outro pid nao e garantido.
    if (pid == ::GetCurrentProcessId()) {
        const auto base = reinterpret_cast<std::uintptr_t>(::GetModuleHandleW(nullptr));
        unsigned char mz[2] = {};
        SIZE_T got = 0;
        if (ph.read(base, mz, sizeof(mz), &got)) {
            std::wprintf(L"base %p: %c%c\n", reinterpret_cast<void*>(base), mz[0], mz[1]);
        } else {
            std::wprintf(L"leitura falhou: GetLastError=%lu (%zu/%zu bytes)\n",
                         ::GetLastError(), got, sizeof(mz));
        }
    }

    ss::ThreadHandleMonitor monitor;
    if (!monitor.start()) {
        std::wprintf(L"start() falhou\n");
        return 2;
    }

    DWORD tid = 0;
    HANDLE h = ::CreateThread(nullptr, 0, &Worker, nullptr, 0, &tid);
    if (!h) {
        std::wprintf(L"CreateThread falhou: %lu\n", ::GetLastError());
        (void)monitor.stop();
        return 3;
    }

    if (!monitor.track(h)) {
        std::wprintf(L"track() recusou o handle de thread\n");
        ::CloseHandle(h);
        (void)monitor.stop();
        return 4;
    }
    std::wprintf(L"thread %lu registrada, posse passada ao monitor\n", tid);

    for (int i = 0; i < 20 && monitor.reaped() == 0; ++i) ::Sleep(50);

    for (const auto& r : monitor.takeReaped()) {
        std::wprintf(L"reaped tid=%lu exit=0x%08lX\n", r.threadId, r.exitCode);
    }

    if (!monitor.stop()) std::wprintf(L"stop() deu timeout; a thread nao foi morta\n");
    return 0;
}
