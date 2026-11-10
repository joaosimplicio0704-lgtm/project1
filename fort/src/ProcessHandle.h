#pragma once

#include <windows.h>
#include <cstdint>

namespace ss {
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
        [[nodiscard]] DWORD lastError() const noexcept { return lastError_; }
        [[nodiscard]] DWORD pid() const noexcept { return pid_; }

        [[nodiscard]] HANDLE release() noexcept;
        void reset(HANDLE replacement = nullptr) noexcept;

        [[nodiscard]] bool read(std::uintptr_t address, void* dst, SIZE_T size,
                                SIZE_T* bytesRead = nullptr) const noexcept;

    private:
        HANDLE handle_ = nullptr;
        DWORD lastError_ = ERROR_SUCCESS;
        DWORD pid_ = 0;
    };

    [[nodiscard]] ProcessHandle OpenReadOnly(
        DWORD pid, DWORD desiredAccess = kDefaultAccess) noexcept;
}
