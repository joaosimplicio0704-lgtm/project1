#pragma once
#include <windows.h>
#include <tlhelp32.h>
#include <cstdint>
#include <optional>
#include <string>

#include "offsets.hpp"
#include "StealthyOpenProcess.h"

// Leitura externa de memória (ReadProcessMemory). Sem injeção, sem write.
class Mem {
public:
    Mem() = default;

    bool attach(const std::wstring& procName) {
        if (hProc_) CloseHandle(hProc_);
        hProc_ = nullptr; pid_ = 0; base_ = 0;

        PROCESSENTRY32W pe{}; pe.dwSize = sizeof(pe);
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snap == INVALID_HANDLE_VALUE) return false;
        bool found = false;
        if (Process32FirstW(snap, &pe)) {
            do {
                if (_wcsicmp(pe.szExeFile, procName.c_str()) == 0) {
                    pid_ = pe.th32ProcessID;
                    found = true;
                    break;
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
        if (!found) return false;

        hProc_ = StealthyOpenProcess::Execute(pid_, PROCESS_VM_READ | PROCESS_QUERY_INFORMATION);
        if (!hProc_) return false;
        base_ = moduleBase(procName);
        return base_ != 0;
    }

    bool isAttached() const { return hProc_ != nullptr; }
    DWORD pid() const { return pid_; }
    uintptr_t base() const { return base_; }

    template <typename T>
    bool read(uintptr_t addr, T& out) const {
        SIZE_T rd = 0;
        return ReadProcessMemory(hProc_, (LPCVOID)addr, &out, sizeof(T), &rd) && rd == sizeof(T);
    }

    template <typename T>
    std::optional<T> read(uintptr_t addr) const {
        T v{};
        return read(addr, v) ? std::optional<T>(v) : std::nullopt;
    }

    // lê um ponteiro (uintptr_t) em addr
    std::optional<uintptr_t> readPtr(uintptr_t addr) const { return read<uintptr_t>(addr); }

    // lê um TArray: dados em addr+Data, count em addr+Count
    template <typename T>
    bool readArray(uintptr_t arrayAddr, T* out, size_t maxCount) const {
        uintptr_t data = 0; size_t count = 0;
        if (!read(arrayAddr + off::kTArray_Data, data)) return false;
        if (!read(arrayAddr + off::kTArray_Count, count)) return false;
        if (count == 0 || count > maxCount) return false;
        SIZE_T rd = 0;
        return ReadProcessMemory(hProc_, (LPCVOID)data, out, count * sizeof(T), &rd) && rd == count * sizeof(T);
    }

private:
    uintptr_t moduleBase(const std::wstring& modName) const {
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid_);
        if (snap == INVALID_HANDLE_VALUE) return 0;
        MODULEENTRY32W me{}; me.dwSize = sizeof(me);
        uintptr_t base = 0;
        if (Module32FirstW(snap, &me)) {
            do {
                if (_wcsicmp(me.szModule, modName.c_str()) == 0) {
                    base = (uintptr_t)me.modBaseAddr;
                    break;
                }
            } while (Module32NextW(snap, &me));
        }
        CloseHandle(snap);
        return base;
    }

    HANDLE hProc_ = nullptr;
    DWORD pid_ = 0;
    uintptr_t base_ = 0;
};
