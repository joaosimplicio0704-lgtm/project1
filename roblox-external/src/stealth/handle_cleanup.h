#pragma once
#include <windows.h>
#include <cstddef>

// ============================================================
// Handle cleanup — versao standalone do closehandle.cpp
//
// Varre a tabela de handles do proprio processo (NtQuerySystemInformation,
// SystemExtendedHandleInformation) e fecha handles de thread que ficaram
// com exit status "desconhecido" (NTSTATUS nao mapeado) — resto de threads
// efemeras tipo a do StealthyOpenProcess, TerminateThread e afins.
//
// Original dependia de Cheat/Globals.hpp e DynamicStub.hpp; aqui o flag de
// shutdown virou um std::atomic e o CreateThreadWithDynamicStub virou
// CreateThread direto.
// ============================================================

namespace HandleCleanup {

// uma passada; retorna quantos handles foram fechados
size_t Sweep();

// thread de monitoramento (2s de tick, para sozinha apos 3 varreduras vazias)
bool Start();
void Stop();

} // namespace HandleCleanup
