#pragma once
#include <windows.h>
#include <cstdint>
#include <string>
#include <vector>

#include "sdk.h"

// Read-only handle. Ninguem escreve em memoria do jogo por aqui.
class Memory {
public:
    Memory() = default;
    ~Memory() { Detach(); }

    Memory(const Memory&) = delete;
    Memory& operator=(const Memory&) = delete;

    // process_name = "RobloxPlayerBeta.exe". stealth = abre o handle via
    // StealthyOpenProcess (callstack dentro de kernel32); fallback automatico
    // para OpenProcess se o truque falhar.
    // write = abre com PROCESS_VM_WRITE|VM_OPERATION (usado pelo voo).
    // sem isso o handle e estritamente read-only.
    bool Attach(const char* process_name, bool stealth = true, bool write = false);
    void Detach();

    bool Alive() const;
    bool Ready() const { return m_handle != nullptr && m_base != 0; }

    uintptr_t Base() const { return m_base; }
    size_t BaseSize() const { return m_baseSize; }
    bool CanWrite() const { return m_canWrite; }
    DWORD Pid() const { return m_pid; }
    HANDLE Handle() const { return m_handle; }

    bool Read(uintptr_t address, void* out, size_t size) const;
    bool Write(uintptr_t address, const void* data, size_t size) const;

    template <typename T>
    bool Write(uintptr_t address, const T& value) const { return Write(address, &value, sizeof(T)); }

    template <typename T>
    bool Read(uintptr_t address, T& out) const { return Read(address, &out, sizeof(T)); }

    template <typename T>
    T ReadOr(uintptr_t address, T fallback = T{}) const {
        T value{};
        return Read(address, value) ? value : fallback;
    }

    uintptr_t ReadPtr(uintptr_t address) const { return ReadOr<uintptr_t>(address, 0); }

    // le uma cadeia de ponteiros: Resolve(base, a, b, c) = *(*(*(base+a))+b)+c ... final lido como ptr
    uintptr_t Resolve(uintptr_t base, std::initializer_list<uintptr_t> chain) const;

    // std::string do MSVC/rust: len em +0x10, heap ptr em +0 quando len >= 16
    std::string ReadString(uintptr_t string_address, size_t max_length = 128) const;

    static DWORD FindPid(const char* process_name);

private:
    static bool IsUserAddress(uintptr_t address, size_t size);

    HANDLE m_handle = nullptr;
    DWORD m_pid = 0;
    uintptr_t m_base = 0;
    size_t m_baseSize = 0;
    bool m_canWrite = false;
};
