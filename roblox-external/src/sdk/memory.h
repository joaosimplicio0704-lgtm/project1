#pragma once
#include <windows.h>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include "sdk.h"

// Read-only por padrão. O voo pede write=True e aí o handle ganha
// VM_WRITE|VM_OPERATION. Toda operação é serializada por mutex porque o
// leitor roda em thread própria e o voo escreve na thread de render.
class Memory {
public:
    Memory() = default;
    ~Memory() { Detach(); }

    Memory(const Memory&) = delete;
    Memory& operator=(const Memory&) = delete;

    bool Attach(const char* process_name, bool stealth = true, bool write = false);
    void Detach();

    bool Alive() const;
    bool Ready() const;

    uintptr_t Base() const;
    size_t BaseSize() const;
    bool CanWrite() const;
    DWORD Pid() const { return m_pid; }
    HANDLE Handle() const { return m_handle; }

    bool Read(uintptr_t address, void* out, size_t size) const;
    bool Write(uintptr_t address, const void* data, size_t size) const;

    template <typename T>
    bool Read(uintptr_t address, T& out) const { return Read(address, &out, sizeof(T)); }

    template <typename T>
    bool Write(uintptr_t address, const T& value) const { return Write(address, &value, sizeof(T)); }

    template <typename T>
    T ReadOr(uintptr_t address, T fallback = T{}) const {
        T value{};
        return Read(address, value) ? value : fallback;
    }

    uintptr_t ReadPtr(uintptr_t address) const { return ReadOr<uintptr_t>(address, 0); }
    std::string ReadString(uintptr_t string_address, size_t max_length = 128) const;

    static DWORD FindPid(const char* process_name);

private:
    static bool IsUserAddress(uintptr_t address, size_t size);

    mutable std::mutex m_guard;
    HANDLE    m_handle = nullptr;
    DWORD     m_pid = 0;
    uintptr_t m_base = 0;
    size_t    m_baseSize = 0;
    bool      m_canWrite = false;
};
