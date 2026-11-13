#pragma once
// ============================================================
// STUB — dependencia ausente do closehandle.cpp
// Voce enviou closehandle.cpp mas nao enviou DynamicStub/DynamicStub.hpp.
// Este e um minimo pra compilar; implemente a thread com stub real aqui.
// ============================================================

#include <windows.h>

namespace DynamicStub {
// // FILL: implemente CreateThreadWithDynamicStub de acordo com o seu projeto.
// Funcao original esperada por closehandle.cpp:
//   HANDLE CreateThreadWithDynamicStub(LPTHREAD_START_ROUTINE, LPVOID, DWORD, LPVOID);
inline HANDLE CreateThreadWithDynamicStub(LPTHREAD_START_ROUTINE start, LPVOID param, DWORD flags, LPVOID extra) {
    // fallback simples: CreateThread normal
    return CreateThread(nullptr, 0, start, param, flags, nullptr);
}
} // namespace DynamicStub
