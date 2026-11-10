#pragma once
#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "../sdk/memory.h"

class Esp;

// ============================================================
// Leitor de memoria.
//
// 1) Automatico: resolve a cadeia do jogador sozinho e mostra os valores
//    ao vivo. Nenhum endereco, nenhum comando.
// 2) Varredura: acha endereco a partir de um valor, em thread propria
//    (a UI continua respondendo) com progresso e cancelamento.
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
    MemView() = default;
    ~MemView() { Stop(); }

    MemView(const MemView&) = delete;
    MemView& operator=(const MemView&) = delete;

    void Tick(const Memory& memory);
    void Draw(const Memory& memory, const Esp& esp);

    void Stop();

private:
    void DrawAuto(const Esp& esp);
    void DrawScanner(const Memory& memory);
    void DrawWatches(const Memory& memory);
    void DrawDump();

    void ReadWatch(const Memory& memory, Watch& watch);
    void ScanStart(const Memory& memory);
    void ScanFilter(const Memory& memory);
    void ScanReset();
    void ScanWorker(const Memory* memory, int type, double value, uintptr_t begin, uintptr_t end);

    // manual
    std::vector<Watch> m_watches;
    char        m_input[96] = "base+0x8EB6960>0x1F8";
    int         m_inputType = kPointer;

    // varredura (thread)
    std::thread            m_scanThread;
    std::atomic<bool>      m_scanRunning{ false };
    std::atomic<bool>      m_scanCancel{ false };
    std::atomic<int>       m_scanDone{ 0 };
    std::atomic<int>       m_scanTotal{ 0 };
    std::mutex             m_scanMutex;
    std::vector<uintptr_t> m_scanPending;   // preenchido pela thread
    bool                   m_scanPendingValid = false;
    std::vector<uintptr_t> m_scan;
    int                    m_scanType = kScanFloat;
    char                   m_scanValue[32] = "100";
    char                   m_scanStatus[96]{};

    // dump
    uintptr_t   m_dumpAddress = 0;
    int         m_dumpRows = 16;
    uint8_t     m_dump[16 * 32]{};
    uint8_t     m_dumpPrev[16 * 32]{};
    uintptr_t   m_dumpPrevAddress = 0;
    uint64_t    m_lastTick = 0;
};
