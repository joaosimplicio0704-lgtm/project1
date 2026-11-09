#pragma once
#include <cstdint>
#include <string>
#include <vector>

#include "../sdk/memory.h"

// ============================================================
// Leitor de memoria em tempo real.
//
// Expressao aceita:
//   base+0x8EB6960          offset a partir do modulo
//   base+0x8EB6960>0x1F8    cadeia: le o ponteiro e soma
//   0x7FF6A0001234          endereco absoluto
//
// Cada watch e relido no tick e mostra o valor do tipo escolhido.
// O dump hexadecimal marca em verde o byte que mudou desde o tick anterior.
// ============================================================

enum WatchType : int {
    kByte = 0,
    kInt32,
    kUInt32,
    kInt64,
    kFloat,
    kDouble,
    kPointer,
    kString
};

struct Watch {
    std::string expr;
    int         type = kInt32;
    uintptr_t   address = 0;
    char        value[96]{};
    bool        changed = false;
};

class MemView {
public:
    void Tick(const Memory& memory);
    void Draw(const Memory& memory);

private:
    void ReadWatch(const Memory& memory, Watch& watch);
    void DrawDump(const Memory& memory);

    std::vector<Watch> m_watches;
    char        m_input[96] = "base+0x8EB6960>0x1F8";
    int         m_inputType = kPointer;

    uintptr_t   m_dumpAddress = 0;
    int         m_dumpRows = 16;
    uint8_t     m_dump[16 * 16]{};
    uint8_t     m_dumpPrev[16 * 16]{};
    uintptr_t   m_dumpPrevAddress = 0;
    uint64_t    m_lastTick = 0;
};
