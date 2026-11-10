#include "detector.h"

#include "../offsets.h"

namespace {
constexpr const char* kUnknown = "?";
}

void Detector::Reset() {
    m_info = GameInfo{};
    m_lastDataModel = 0;
    m_lastRead = 0;
}

void Detector::Tick(const Memory& memory, uintptr_t dataModel, int playerCount) {
    if (!dataModel) {
        if (m_info.valid)
            m_info = GameInfo{};
        return;
    }

    m_info.playerCount = playerCount;

    const uint64_t now = GetTickCount64();
    const bool rejoin = dataModel != m_lastDataModel;
    if (!rejoin && m_info.valid && now - m_lastRead < 1000)
        return;

    GameInfo info{};
    info.playerCount = playerCount;
    info.placeId = memory.ReadOr<uint64_t>(dataModel + rbx::DataModel::PlaceId, 0);
    info.gameId = memory.ReadOr<uint64_t>(dataModel + rbx::DataModel::GameId, 0);
    info.creatorId = memory.ReadOr<uint64_t>(dataModel + rbx::DataModel::CreatorId, 0);
    info.placeVersion = memory.ReadOr<int>(dataModel + rbx::DataModel::PlaceVersion, 0);

    const uintptr_t jobId = memory.ReadPtr(dataModel + rbx::DataModel::JobId);
    if (jobId) {
        info.jobId = memory.ReadString(jobId, 48);
        if (info.jobId.empty())
            info.jobId = kUnknown;
    } else {
        info.jobId = kUnknown;
    }

    info.valid = info.placeId != 0 || info.gameId != 0;

    m_info = std::move(info);
    m_lastDataModel = dataModel;
    m_lastRead = now;
}
