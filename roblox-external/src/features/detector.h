#pragma once
#include <cstdint>
#include <string>

#include "../sdk/memory.h"

// ============================================================
// Detector de jogo — le identidade do DataModel
//   PlaceId / GameId / CreatorId / PlaceVersion / JobId
// ============================================================

struct GameInfo {
    bool     valid = false;
    uint64_t placeId = 0;
    uint64_t gameId = 0;
    uint64_t creatorId = 0;
    int      placeVersion = 0;
    std::string jobId;
    int      playerCount = 0;
};

class Detector {
public:
    // chamar uma vez por tick; releitura real a cada 1s
    void Tick(const Memory& memory, uintptr_t dataModel, int playerCount);

    const GameInfo& Info() const { return m_info; }

    void Reset();

private:
    GameInfo m_info{};
    uintptr_t m_lastDataModel = 0;
    uint64_t  m_lastRead = 0;
};
