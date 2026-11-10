#pragma once
#include <Windows.h>
#include <cstdint>

// ============================================================
// ProcessHandle — substitui StealthyOpenProcess.h/.cpp
//
// OpenProcess direto na thread chamadora. Sem VEH, sem HWBP,
// sem stubs, sem XOR de strings. GetLastError sobrevive.
// RAII move-only: o handle fecha uma unica vez.
// ============================================================

namespace ss {

    // acesso minimo: info basica + leitura. nada de PROCESS_ALL_ACCESS.
    constexpr DWORD kDefaultAccess = PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ;

    class ProcessHandle {
    public:
        ProcessHandle() noexcept = default;
        ProcessHandle(DWORD pid, DWORD desiredAccess, DWORD* outError = nullptr) noexcept;
        ~ProcessHandle() noexcept { reset(); }

        ProcessHandle(ProcessHandle&& other) noexcept;
        ProcessHandle& operator=(ProcessHandle&& other) noexcept;
        ProcessHandle(const ProcessHandle&) = delete;
        ProcessHandle& operator=(const ProcessHandle&) = delete;

        [[nodiscard]] bool valid() const noexcept { return handle_ != nullptr; }
        explicit operator bool() const noexcept { return valid(); }
        [[nodiscard]] HANDLE get() const noexcept { return handle_; }
        [[nodiscard]] DWORD  lastError() const noexcept { return lastError_; }
        [[nodiscard]] DWORD  pid() const noexcept { return pid_; }

        // abre mao da posse. o chamador passa a ser dono do handle.
        [[nodiscard]] HANDLE release() noexcept;
        void reset(HANDLE replacement = nullptr) noexcept;

        // leitura somente. nunca escreve na memoria do alvo.
        [[nodiscard]] bool read(std::uintptr_t address, void* dst, SIZE_T size,
                                SIZE_T* bytesRead = nullptr) const noexcept;

    private:
        HANDLE handle_ = nullptr;
        DWORD  lastError_ = ERROR_SUCCESS;
        DWORD  pid_ = 0;
    };

    [[nodiscard]] ProcessHandle OpenReadOnly(
        DWORD pid, DWORD desiredAccess = kDefaultAccess) noexcept;

} // namespace ss
