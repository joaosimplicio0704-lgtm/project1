#pragma once
#include <cstdint>
#include <string>
#include <vector>

#include "../sdk/memory.h"

class Esp;

// ============================================================
// Leitor de memoria.
//
// 1) Automatico: resolve a cadeia do jogador sozinho e mostra os valores
//    ao vivo. Nenhum endereco, nenhum comando — abre a aba e esta la.
// 2) Varredura: acha endereco a partir de um valor (primeiro scan +
//    filtro), no range do modulo.
// 3) Manual: watch por expressao + hexdump.
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

enum ScanType : int {
    kScanInt32 = 0,
    kScanFloat,
    kScanInt64
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
    void Draw(const Memory& memory, const Esp& esp);

private:
    void DrawAuto(const Esp& esp);
    void DrawScanner(const Memory& memory);
    void DrawWatches(const Memory& memory);
    void DrawDump();

    void ReadWatch(const Memory& memory, Watch& watch);
    void ScanStart(const Memory& memory);
    void ScanFilter(const Memory& memory);
    void ScanReset();

    // automatico
    uintptr_t m_autoTick = 0;

    // manual
    std::vector<Watch> m_watches;
    char        m_input[96] = "base+0x8EB6960>0x1F8";
    int         m_inputType = kPointer;

    // varredura
    int         m_scanType = kScanFloat;
    char        m_scanValue[32] = "100";
    std::vector<uintptr_t> m_scan;
    char        m_scanStatus[96]{};
    bool        m_scanTruncated = false;

    // dump
    uintptr_t   m_dumpAddress = 0;
    int         m_dumpRows = 16;
    uint8_t     m_dump[16 * 32]{};
    uint8_t     m_dumpPrev[16 * 32]{};
    uintptr_t   m_dumpPrevAddress = 0;
    uint64_t    m_lastTick = 0;
};
