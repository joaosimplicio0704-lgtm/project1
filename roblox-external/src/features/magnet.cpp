#include "magnet.h"

#include <windows.h>

#include <cmath>

#include "../applog.h"
#include "esp.h"
#include "../offsets.h"

namespace {

// onde o item para, relativo ao personagem: na frente e um pouco pra cima
Vector3 PlaceNear(const Vector3& player, const Vector3& item, float pullDistance) {
    Vector3 dir{ item.x - player.x, 0.f, item.z - player.z };
    const float len = std::sqrt(dir.x * dir.x + dir.z * dir.z);
    if (len > 0.001f) {
        dir.x /= len;
        dir.z /= len;
    } else {
        dir.x = 1.f;
        dir.z = 0.f;
    }

    return Vector3{
        player.x + dir.x * pullDistance,
        player.y + 1.5f,
        player.z + dir.z * pullDistance
    };
}

} // namespace

void Magnet::Reset() {
    m_lastPull = 0;
    m_pulled = 0;
    m_refused = 0;
    m_lastRefuseLog = 0;
}

bool Magnet::PullOne(Memory& memory, const LocalState& local, const PartMark& part,
                     const cfg::MagnetSettings& magnet) {
    if (!part.primitive || !memory.CanWrite() || !local.position.NonZero())
        return false;

    // nao puxa pedaco do proprio personagem por acidente
    if (part.primitive == local.primitive)
        return false;

    if (part.distance > magnet.range)
        return false;

    const Vector3 target = PlaceNear(local.position, part.position, magnet.pullDistance);

    if (!memory.Write(part.primitive + rbx::Primitive::Position, target)) {
        ++m_refused;
        return false;
    }

    ++m_pulled;
    return true;
}

void Magnet::PullOnce(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                      const SceneSnapshot& scene) {
    if (!memory.CanWrite() || !local.Valid())
        return;

    const int budget = settings.magnet.perSecond < 1 ? 1 : settings.magnet.perSecond;

    int done = 0;
    for (const PartMark& part : scene.parts) {
        if (done >= budget)
            break;
        if (part.primitive && part.distance <= settings.magnet.range) {
            if (PullOne(memory, local, part, settings.magnet))
                ++done;
        }
    }
}

void Magnet::Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                  const SceneSnapshot& scene, bool blocked) {
    const cfg::MagnetSettings& magnet = settings.magnet;

    if (!magnet.enabled || blocked || !memory.CanWrite() || !local.Valid())
        return;

    if (scene.parts.empty())
        return;

    // orcamento por tempo: 10/s por default em vez de 250 writes por segundo
    const uint64_t now = GetTickCount64();
    const uint64_t interval = 1000ULL / static_cast<uint64_t>(magnet.perSecond < 1 ? 1 : magnet.perSecond);
    if (m_lastPull && now - m_lastPull < interval)
        return;
    m_lastPull = now;

    // puxa o item mais perto primeiro: e o que voce esta vendo
    const PartMark* best = nullptr;
    for (const PartMark& part : scene.parts) {
        if (!part.primitive || part.distance > magnet.range)
            continue;
        if (!best || part.distance < best->distance)
            best = &part;
    }

    if (!best)
        return;

    if (!PullOne(memory, local, *best, magnet) && m_refused > 0 && now - m_lastRefuseLog > 5000) {
        m_lastRefuseLog = now;
        applog::Line("[magnet] %d itens puxados, %d recusados (item ancorado ou do servidor)",
                     m_pulled, m_refused);
    }
}

bool Magnet::TeleportToNearest(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                               const SceneSnapshot& scene) {
    if (!memory.CanWrite() || !local.Valid() || !local.primitive)
        return false;

    const PartMark* best = nullptr;
    for (const PartMark& part : scene.parts) {
        if (part.distance > settings.magnet.range)
            continue;
        if (!best || part.distance < best->distance)
            best = &part;
    }

    if (!best)
        return false;

    // leva o personagem ate o item (esse write o cliente sempre manda)
    const Vector3 target{ best->position.x, best->position.y + 2.f, best->position.z };
    if (!memory.Write(local.primitive + rbx::Primitive::Position, target))
        return false;

    const Vector3 zero{};
    memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, zero);

    applog::Line("[magnet] teleporte ate '%s' (%.0f studs)", best->name.c_str(), best->distance);
    return true;
}
