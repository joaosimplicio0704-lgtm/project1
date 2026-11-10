#include "ProcessHandle.h"

namespace ss {
    ProcessHandle::ProcessHandle(DWORD pid, DWORD desiredAccess, DWORD* outError) noexcept
        : pid_(pid) {
        handle_ = ::OpenProcess(desiredAccess, FALSE, pid);
        if (!handle_) lastError_ = ::GetLastError();
        if (outError) *outError = lastError_;
    }

    ProcessHandle::ProcessHandle(ProcessHandle&& other) noexcept
        : handle_(other.release()), lastError_(other.lastError_), pid_(other.pid_) {
    }

    ProcessHandle& ProcessHandle::operator=(ProcessHandle&& other) noexcept {
        if (this != &other) {
            reset(other.release());
            lastError_ = other.lastError_;
            pid_ = other.pid_;
        }
        return *this;
    }

    HANDLE ProcessHandle::release() noexcept {
        HANDLE handle = handle_;
        handle_ = nullptr;
        return handle;
    }

    void ProcessHandle::reset(HANDLE replacement) noexcept {
        if (handle_) ::CloseHandle(handle_);
        handle_ = replacement;
    }

    bool ProcessHandle::read(std::uintptr_t address, void* dst, SIZE_T size,
                             SIZE_T* bytesRead) const noexcept {
        if (!valid() || !dst || size == 0) {
            ::SetLastError(ERROR_INVALID_PARAMETER);
            if (bytesRead) *bytesRead = 0;
            return false;
        }

        SIZE_T got = 0;
        if (!::ReadProcessMemory(handle_, reinterpret_cast<LPCVOID>(address),
                                 dst, size, &got)) {
            if (bytesRead) *bytesRead = got;
            return false;
        }

        if (bytesRead) *bytesRead = got;
        if (got != size) {
            ::SetLastError(ERROR_PARTIAL_COPY);
            return false;
        }
        return true;
    }

    ProcessHandle OpenReadOnly(DWORD pid, DWORD desiredAccess) noexcept {
        return ProcessHandle(pid, desiredAccess);
    }
}
