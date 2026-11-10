#include "speed.h"

#include <windows.h>

#include <algorithm>
#include <cmath>

#include "esp.h"
#include "../applog.h"
#include "../offsets.h"

namespace {
constexpr uint64_t kReapplyMs = 250;   // jogo reseta WalkSpeed? reescreve
}

void Speed::Restore(Memory& memory) {
    if (m_owned && m_humanoid && memory.CanWrite())
        memory.Write(m_humanoid + rbx::Humanoid::Walkspeed, m_original);

    if (m_jumpOwned && m_humanoid && memory.CanWrite())
        memory.Write(m_humanoid + rbx::Humanoid::JumpPower, m_originalJump);

    if (m_owned || m_jumpOwned)
        applog::Line("[speed] WalkSpeed/JumpPower restaurados (%.0f / %.0f)", m_original,
                     m_originalJump);

    m_owned = false;
    m_jumpOwned = false;
    m_humanoid = 0;
    m_lastWrite = 0;
    m_lastJump = 0;
}

void Speed::Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked) {
    const cfg::SpeedSettings& speed = settings.speed;

    // desligado / sem humanoid / menu aberto: devolve o valor original
    if (!speed.enabled || blocked || !local.Valid() || !local.humanoid || !memory.CanWrite()) {
        if (m_owned || m_jumpOwned)
            Restore(memory);
        return;
    }

    // personagem trocou (respawn): o humanoid antigo morreu junto
    if (m_humanoid && m_humanoid != local.humanoid) {
        m_owned = false;
        m_jumpOwned = false;
    }

    const uint64_t now = GetTickCount64();

    // ---- WalkSpeed ----
    if (!m_owned) {
        m_original = memory.ReadOr<float>(local.humanoid + rbx::Humanoid::Walkspeed, 16.f);
        m_humanoid = local.humanoid;
        m_owned = true;
        m_lastWrite = 0;
        applog::Line("[speed] WalkSpeed original %.1f", m_original);
    }

    if (!m_lastWrite || now - m_lastWrite >= kReapplyMs) {
        m_lastWrite = now;

        const float current = memory.ReadOr<float>(local.humanoid + rbx::Humanoid::Walkspeed, m_original);
        const float wanted = std::clamp(speed.walkSpeed, 1.f, 500.f);

        // se o valor atual nao e o que escrevemos, ou o jogo resetou, escreve
        if (std::fabs(current - wanted) > 0.5f) {
            if (memory.Write(local.humanoid + rbx::Humanoid::Walkspeed, wanted))
                ++m_writes;
        }
    }

    // ---- JumpPower (opcional) ----
    if (speed.jumpBoost) {
        if (!m_jumpOwned) {
            m_originalJump = memory.ReadOr<float>(local.humanoid + rbx::Humanoid::JumpPower, 50.f);
            m_jumpOwned = true;
            m_lastJump = 0;
        }

        if (!m_lastJump || now - m_lastJump >= kReapplyMs) {
            m_lastJump = now;

            const float current = memory.ReadOr<float>(local.humanoid + rbx::Humanoid::JumpPower,
                                                       m_originalJump);
            const float wanted = std::clamp(speed.jumpPower, 1.f, 500.f);
            if (std::fabs(current - wanted) > 0.5f)
                memory.Write(local.humanoid + rbx::Humanoid::JumpPower, wanted);
        }
    } else if (m_jumpOwned) {
        memory.Write(local.humanoid + rbx::Humanoid::JumpPower, m_originalJump);
        m_jumpOwned = false;
    }
}
