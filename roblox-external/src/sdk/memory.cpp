#include "memory.h"

#include <tlhelp32.h>

#include "../stealth/StealthyOpenProcess.h"
#include "../offsets.h"

namespace {

// szExeFile/szModule sao WCHAR; o nome que a gente usa e ASCII
bool SameExe(const WCHAR* exe, const char* name) {
    char buffer[MAX_PATH]{};
    WideCharToMultiByte(CP_ACP, 0, exe, -1, buffer, MAX_PATH - 1, nullptr, nullptr);
    return _stricmp(buffer, name) == 0;
}

} // namespace

bool Memory::IsUserAddress(uintptr_t address, size_t size) {
    if (!address || address < 0x10000)
        return false;
    if (address + size < address) // overflow
        return false;
    return (address + size) < 0x00007FFFFFFFFFFFULL;
}

DWORD Memory::FindPid(const char* process_name) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE)
        return 0;

    PROCESSENTRY32 entry{};
    entry.dwSize = sizeof(entry);

    DWORD pid = 0;
    if (Process32First(snapshot, &entry)) {
        do {
            if (SameExe(entry.szExeFile, process_name)) {
                pid = entry.th32ProcessID;
                break;
            }
        } while (Process32Next(snapshot, &entry));
    }

    CloseHandle(snapshot);
    return pid;
}

bool Memory::Attach(const char* process_name, bool stealth, bool write) {
    std::lock_guard<std::mutex> lock(m_guard);

    // limpa estado anterior sem re-lock (Detach pega o mutex)
    if (m_handle) {
        CloseHandle(m_handle);
        m_handle = nullptr;
    }
    m_base = 0;
    m_baseSize = 0;
    m_canWrite = false;
    m_pid = 0;

    m_pid = FindPid(process_name);
    if (!m_pid)
        return false;

    DWORD access = PROCESS_VM_READ | PROCESS_QUERY_INFORMATION;
    if (write)
        access |= PROCESS_VM_WRITE | PROCESS_VM_OPERATION;

    if (stealth)
        m_handle = StealthyOpenProcess::Execute(m_pid, access);
    if (!m_handle)
        m_handle = OpenProcess(access, FALSE, m_pid);
    if (!m_handle) {
        m_pid = 0;
        return false;
    }

    // SNAPMODULE precisa de QUERY_INFORMATION alem de VM_READ
    HANDLE modules = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, m_pid);
    if (modules != INVALID_HANDLE_VALUE) {
        MODULEENTRY32 entry{};
        entry.dwSize = sizeof(entry);

        if (Module32First(modules, &entry)) {
            do {
                if (SameExe(entry.szModule, process_name)) {
                    m_base = reinterpret_cast<uintptr_t>(entry.modBaseAddr);
                    m_baseSize = entry.modBaseSize;
                    break;
                }
            } while (Module32Next(modules, &entry));
        }
        CloseHandle(modules);
    }

    if (!m_base) {
        if (m_handle) {
            CloseHandle(m_handle);
            m_handle = nullptr;
        }
        m_pid = 0;
        m_baseSize = 0;
        return false;
    }

    m_canWrite = write;
    return true;
}

void Memory::Detach() {
    std::lock_guard<std::mutex> lock(m_guard);

    m_base = 0;
    m_baseSize = 0;
    m_canWrite = false;
    m_pid = 0;

    if (m_handle) {
        CloseHandle(m_handle);
        m_handle = nullptr;
    }
}

bool Memory::Ready() const {
    std::lock_guard<std::mutex> lock(m_guard);
    return m_handle != nullptr && m_base != 0;
}

bool Memory::Alive() const {
    std::lock_guard<std::mutex> lock(m_guard);
    if (!m_handle)
        return false;
    return WaitForSingleObject(m_handle, 0) == WAIT_TIMEOUT;
}

uintptr_t Memory::Base() const {
    std::lock_guard<std::mutex> lock(m_guard);
    return m_base;
}

size_t Memory::BaseSize() const {
    std::lock_guard<std::mutex> lock(m_guard);
    return m_baseSize;
}

bool Memory::CanWrite() const {
    std::lock_guard<std::mutex> lock(m_guard);
    return m_canWrite;
}

bool Memory::Read(uintptr_t address, void* out, size_t size) const {
    if (!out || !size || !IsUserAddress(address, size))
        return false;

    std::lock_guard<std::mutex> lock(m_guard);
    if (!m_handle)
        return false;

    SIZE_T read = 0;
    if (!ReadProcessMemory(m_handle, reinterpret_cast<LPCVOID>(address), out, size, &read))
        return false;
    return read == size;
}

bool Memory::Write(uintptr_t address, const void* data, size_t size) const {
    if (!data || !size || !IsUserAddress(address, size))
        return false;

    std::lock_guard<std::mutex> lock(m_guard);
    if (!m_handle || !m_canWrite)
        return false;

    SIZE_T written = 0;
    if (!WriteProcessMemory(m_handle, reinterpret_cast<LPVOID>(address), data, size, &written))
        return false;
    return written == size;
}

std::string Memory::ReadString(uintptr_t string_address, size_t max_length) const {
    if (!string_address || max_length == 0)
        return {};

    int length = ReadOr<int>(string_address + rbx::Misc::StringLength, 0);
    if (length <= 0 || static_cast<size_t>(length) > max_length)
        length = static_cast<int>(max_length > 255 ? 255 : max_length);
    if (length > 255)
        length = 255;

    uintptr_t text = string_address;
    if (length >= 16) {
        text = ReadPtr(string_address); // std::string em heap
        if (!text)
            return {};
    }

    char buffer[256]{};
    if (!Read(text, buffer, static_cast<size_t>(length)))
        return {};

    buffer[length] = '\0';
    return std::string(buffer);
}
