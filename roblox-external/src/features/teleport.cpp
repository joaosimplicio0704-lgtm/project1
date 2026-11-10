#include "teleport.h"

#include <windows.h>

#include <algorithm>
#include <cmath>

#include "esp.h"
#include "../applog.h"
#include "../offsets.h"
#include "../sdk/mathx.h"

namespace {

// onde parar: ao lado do alvo, nao dentro dele
Vector3 OffsetFrom(const Vector3& target, float offset) {
    return Vector3{ target.x + offset, target.y + 1.f, target.z + offset };
}

} // namespace

void Teleport::Cancel() {
    m_stepping = false;
    m_lastWrite = 0;
}

void Teleport::BeginStepping(const cfg::TeleportSettings& settings, const Vector3& from,
                             const Vector3& target) {
    m_from = from;
    m_target = target;
    m_stepping = true;
    m_lastWrite = 0;

    applog::Line("[tp] indo de (%.0f, %.0f, %.0f) para (%.0f, %.0f, %.0f), %.0f studs/s",
                 from.x, from.y, from.z, target.x, target.y, target.z,
                 settings.stepStuds * static_cast<float>(settings.writeHz));
}

bool Teleport::SaveReturn(const LocalState& local) {
    if (!local.Valid() || !local.position.NonZero())
        return false;

    m_return = local.position;
    m_haveReturn = true;
    return true;
}

bool Teleport::GoToPoint(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                         const Vector3& target) {
    if (!memory.CanWrite() || !local.primitive || !target.Finite())
        return false;

    // lembra de onde sai pra "Voltar" (nao sobrescreve se Return() chamou)
    if (local.position.NonZero())
        SaveReturn(local);

    const Vector3 destination = OffsetFrom(target, settings.teleport.offsetStuds);

    if (settings.teleport.smooth) {
        BeginStepping(settings.teleport, local.position.NonZero() ? local.position : destination,
                      destination);
        return true;
    }

    if (!memory.Write(local.primitive + rbx::Primitive::Position, destination))
        return false;

    const Vector3 zero{};
    memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, zero);
    ++m_writes;

    applog::Line("[tp] teleporte instantaneo (%.0f, %.0f, %.0f)", destination.x, destination.y,
                 destination.z);
    return true;
}

bool Teleport::GoToPlayer(const cfg::Settings& settings, Memory& memory, const LocalState& local,
                          const SceneSnapshot& scene) {
    if (!m_selected)
        return false;

    for (const Target& target : scene.targets) {
        if (target.player != m_selected)
            continue;

        Vector3 spot = target.root;
        if (spot.NonZero())
            return GoToPoint(settings, memory, local, spot);

        return false;
    }

    return false;
}

bool Teleport::Return(const cfg::Settings& settings, Memory& memory, const LocalState& local) {
    if (!m_haveReturn)
        return false;

    const Vector3 back = m_return;
    m_haveReturn = false;
    return GoToPoint(settings, memory, local, back);
}

void Teleport::Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked) {
    if (!m_stepping)
        return;

    if (blocked || !memory.CanWrite() || !local.primitive) {
        Cancel();
        return;
    }

    const cfg::TeleportSettings& tp = settings.teleport;
    const int hz = std::clamp(tp.writeHz, 20, 250);
    const uint64_t now = GetTickCount64();

    if (m_lastWrite && now - m_lastWrite < 1000ULL / static_cast<uint64_t>(hz))
        return;

    m_lastWrite = now;

    // anda no maximo stepStuds por write: pro servidor isso e movimento rapido
    Vector3 next = local.position.NonZero() ? local.position : m_from;
    const bool arrived = mathx::Approach(next, m_target, std::max(0.5f, tp.stepStuds), 2.f);

    if (!next.Finite()) {
        Cancel();
        return;
    }

    if (memory.Write(local.primitive + rbx::Primitive::Position, next)) {
        ++m_writes;

        // velocidade coerente com o passo: posicao "andando" e nao "teleportando"
        const float speed = std::max(0.5f, tp.stepStuds) * static_cast<float>(hz);
        Vector3 dir{ m_target.x - next.x, m_target.y - next.y, m_target.z - next.z };
        const float len = dir.Length();
        if (len > 0.001f) {
            dir.x = dir.x / len * speed;
            dir.y = dir.y / len * speed;
            dir.z = dir.z / len * speed;
            memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, dir);
        }
    }

    if (arrived) {
        const Vector3 zero{};
        memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, zero);
        applog::Line("[tp] chegou (%d writes)", m_writes);
        m_stepping = false;
        m_writes = 0;
    }
}
