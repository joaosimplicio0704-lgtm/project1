#include "memory.h"

#include <tlhelp32.h>

namespace {

// compara szExeFile (WCHAR) com o nome ASCII que a gente usa
bool SameExe(const WCHAR* exe, const char* name) {
    char buffer[MAX_PATH]{};
    WideCharToMultiByte(CP_ACP, 0, exe, -1, buffer, MAX_PATH - 1, nullptr, nullptr);
    return _stricmp(buffer, name) == 0;
}

} // namespace

#include "../stealth/StealthyOpenProcess.h"
#include "../offsets.h"

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

bool Memory::Attach(const char* process_name, bool stealth) {
    Detach();

    m_pid = FindPid(process_name);
    if (!m_pid)
        return false;

    const DWORD access = PROCESS_VM_READ | PROCESS_QUERY_INFORMATION;

    if (stealth) {
        m_handle = StealthyOpenProcess::Execute(m_pid, access);
    }
    if (!m_handle) {
        m_handle = OpenProcess(access, FALSE, m_pid);
    }
    if (!m_handle) {
        m_pid = 0;
        return false;
    }

    // SNAPMODULE precisa de QUERY_INFORMATION alem de VM_READ.
    HANDLE modules = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, m_pid);
    if (modules != INVALID_HANDLE_VALUE) {
        MODULEENTRY32 entry{};
        entry.dwSize = sizeof(entry);

        if (Module32First(modules, &entry)) {
            do {
                if (SameExe(entry.szModule, process_name)) {
                    m_base = reinterpret_cast<uintptr_t>(entry.modBaseAddr);
                    break;
                }
            } while (Module32Next(modules, &entry));
        }
        CloseHandle(modules);
    }

    if (!m_base) {
        Detach();
        return false;
    }
    return true;
}

void Memory::Detach() {
    if (m_handle) {
        CloseHandle(m_handle);
        m_handle = nullptr;
    }
    m_pid = 0;
    m_base = 0;
}

bool Memory::Alive() const {
    if (!m_handle)
        return false;
    return WaitForSingleObject(m_handle, 0) == WAIT_TIMEOUT;
}

bool Memory::Read(uintptr_t address, void* out, size_t size) const {
    if (!m_handle || !out || !size)
        return false;
    if (!IsUserAddress(address, size))
        return false;

    SIZE_T read = 0;
    if (!ReadProcessMemory(m_handle, reinterpret_cast<LPCVOID>(address), out, size, &read))
        return false;
    return read == size;
}

uintptr_t Memory::Resolve(uintptr_t base, std::initializer_list<uintptr_t> chain) const {
    uintptr_t current = base;
    for (uintptr_t offset : chain) {
        current = ReadPtr(current + offset);
        if (!current)
            return 0;
    }
    return current;
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
