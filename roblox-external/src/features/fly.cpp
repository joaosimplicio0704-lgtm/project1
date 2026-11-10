#include "fly.h"

#include <windows.h>

#include <cmath>

#include "../features/esp.h"
#include "../applog.h"
#include "../offsets.h"
#include "../sdk/mathx.h"

namespace {

// acima disso o passo viraria teleporte (frame travado, menu arrastando)
constexpr float kMaxStepDt = 0.05f;    // 50 ms
constexpr float kResyncStuds = 40.f;   // divergencia = "o jogo me moveu"

bool Down(int vk) {
    return vk > 0 && (GetAsyncKeyState(vk) & 0x8000) != 0;
}

float Dist(const Vector3& a, const Vector3& b) {
    const float dx = a.x - b.x;
    const float dy = a.y - b.y;
    const float dz = a.z - b.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

} // namespace

bool Fly::SetAnchored(Memory& memory, uintptr_t primitive, bool anchored) {
    if (!primitive || !memory.CanWrite())
        return false;

    uint8_t flags = 0;
    if (!memory.Read(primitive + rbx::Primitive::Flags, flags))
        return false;

    const uint8_t bit = static_cast<uint8_t>(rbx::PrimitiveFlags::Anchored);
    const uint8_t next = anchored ? static_cast<uint8_t>(flags | bit)
                                  : static_cast<uint8_t>(flags & ~bit);
    if (next == flags)
        return true;

    if (!memory.Write(primitive + rbx::Primitive::Flags, next))
        return false;

    m_anchored = anchored;
    m_anchorPrimitive = primitive;
    applog::Line("[voo] Anchored %s (flags 0x%02X -> 0x%02X)", anchored ? "on" : "off", flags, next);
    return true;
}

void Fly::Reset() {
    m_active = false;
    m_hovering = false;
    m_toggled = false;
    m_prevDown = false;
    m_havePos = false;
    m_wasActive = false;
    m_pos = Vector3{};
    m_primitive = 0;
    m_lastTick = 0;
    m_writeOk = false;
    m_writeFails = 0;
    m_anchored = false;
    m_anchorPrimitive = 0;
    m_reverting = false;
    m_revertSince = 0;
}

void Fly::Stop(Memory& memory) {
    // solta o voo: zera a velocidade uma vez pra nao continuar planando
    if (m_wasActive && m_primitive && memory.CanWrite()) {
        const Vector3 zero{};
        memory.Write(m_primitive + rbx::Primitive::AssemblyLinearVelocity, zero);
    }

    // e devolve o Anchored, senao o personagem fica travado no ar pra sempre
    if (m_anchored && m_anchorPrimitive)
        SetAnchored(memory, m_anchorPrimitive, false);

    m_wasActive = false;
    m_active = false;
    m_hovering = false;
    m_havePos = false;
    m_writeOk = false;
}

void Fly::Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked) {
    const cfg::FlySettings& fly = settings.fly;

    // dt sempre medido, inclusive quando desligado (evita passo gigante
    // no primeiro tick depois de religar)
    const uint64_t now = GetTickCount64();
    const float rawDt = m_lastTick ? static_cast<float>(now - m_lastTick) / 1000.f : 0.004f;
    m_lastTick = now;
    const float dt = mathx::ClampDt(rawDt, kMaxStepDt);

    const bool down = Down(fly.key);
    if (fly.toggleMode && down && !m_prevDown)
        m_toggled = !m_toggled;
    m_prevDown = down;

    const bool engaged = fly.enabled && !blocked && (fly.toggleMode ? m_toggled : down);

    if (!engaged || !local.Valid() || !local.primitive) {
        Stop(memory);
        return;
    }

    // handle ainda sem VM_WRITE — o leitor reabre no proximo ciclo
    if (!memory.CanWrite()) {
        m_active = false;
        m_hovering = false;
        m_havePos = false;
        return;
    }

    // personagem trocou (respawn) ou morreu: recomeca da posicao real
    const bool respawn = !m_havePos || m_primitive != local.primitive || local.health <= 0.f;
    const bool divergent = !respawn && Dist(m_pos, local.position) > kResyncStuds;

    if (respawn || divergent) {
        m_pos = local.position;
        m_primitive = local.primitive;
        m_havePos = true;
    }

    if (!m_pos.Finite()) {
        m_havePos = false;
        return;
    }

    // modo Ancorar: alguns jogos/personagens revertem a posicao no mesmo tick.
    // Com o bit Anchored ligado o motor para de brigar e o write fica.
    if (fly.anchor && !m_anchored)
        SetAnchored(memory, local.primitive, true);
    else if (!fly.anchor && m_anchored)
        SetAnchored(memory, m_anchorPrimitive, false);

    // o jogo esta revertendo? (drift grande e persistente enquanto devia andar)
    const float drift = Dist(m_pos, local.position);
    if (drift > 25.f) {
        if (!m_revertSince)
            m_revertSince = now;
        else if (now - m_revertSince > 700 && !m_reverting) {
            m_reverting = true;
            applog::Line("[voo] o jogo esta revertendo a posicao (drift %.0f studs) — use Ancorar", drift);
        }
    } else {
        m_revertSince = 0;
        m_reverting = false;
    }

    const float* r = local.cameraRotation;   // 3x3 row-major da CFrame da camera

    // Roblox: LookVector = -(coluna 3), RightVector = coluna 1
    const Vector3 forward{ -r[2], -r[5], -r[8] };
    const Vector3 right{ r[0], r[3], r[6] };

    float moveForward = 0.f, moveRight = 0.f, moveUp = 0.f;
    if (Down('W')) moveForward += 1.f;
    if (Down('S')) moveForward -= 1.f;
    if (Down('D')) moveRight += 1.f;
    if (Down('A')) moveRight -= 1.f;
    if (Down(VK_SPACE)) moveUp += 1.f;
    if (Down(VK_CONTROL)) moveUp -= 1.f;

    Vector3 dir{
        forward.x * moveForward + right.x * moveRight,
        forward.y * moveForward + right.y * moveRight,
        forward.z * moveForward + right.z * moveRight
    };
    dir.y += moveUp;   // sobe/desce no eixo do mundo

    const float len = std::sqrt(dir.x * dir.x + dir.y * dir.y + dir.z * dir.z);
    const bool moving = len > 0.001f && std::isfinite(len);

    if (!moving) {
        if (!fly.hoverOnIdle) {
            // deixa cair de proposito: nao escreve nada e devolve a gravidade
            m_active = true;
            m_hovering = false;
            m_wasActive = false;
            m_havePos = false;
            return;
        }

        // pairado: nao escreve posicao (nada a mover), so mata a velocidade
        // pra gravidade nao acumular; a posicao real vira a referencia
        if (fly.zeroVelocity) {
            const Vector3 zero{};
            m_writeOk = memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, zero);
            memory.Write(local.primitive + rbx::Primitive::AssemblyAngularVelocity, zero);
        }

        m_pos = local.position;
        m_active = true;
        m_hovering = true;
        m_wasActive = true;
        return;
    }

    dir.x /= len;
    dir.y /= len;
    dir.z /= len;

    const Vector3 next = mathx::FlyStep(m_pos, dir, fly.speed, dt);

    if (!next.Finite())
        return;

    const bool wrote = memory.Write(local.primitive + rbx::Primitive::Position, next);
    m_writeOk = wrote;
    if (!wrote) {
        ++m_writeFails;
        if (m_writeFails == 1)
            applog::Line("[voo] write recusado em 0x%llX (handle sem VM_WRITE? Hyperion reabriu read-only)",
                      static_cast<unsigned long long>(local.primitive));
    } else {
        m_writeFails = 0;
    }

    if (fly.zeroVelocity) {
        const Vector3 zero{};
        memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, zero);
        memory.Write(local.primitive + rbx::Primitive::AssemblyAngularVelocity, zero);
    }

    m_pos = next;
    m_active = true;
    m_hovering = false;
    m_wasActive = true;
}
