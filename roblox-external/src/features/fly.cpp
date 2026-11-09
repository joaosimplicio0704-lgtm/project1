#include "fly.h"

#include <windows.h>

#include <cmath>

#include "../features/esp.h"
#include "../offsets.h"

namespace {

bool Down(int vk) {
    return vk > 0 && (GetAsyncKeyState(vk) & 0x8000) != 0;
}

} // namespace

void Fly::Reset() {
    m_active = false;
    m_toggled = false;
    m_prevDown = false;
    m_lastTick = 0;
}

void Fly::Tick(const cfg::Settings& settings, Memory& memory, const LocalState& local, bool blocked) {
    const cfg::FlySettings& fly = settings.fly;

    if (!fly.enabled || blocked || !local.Valid() || !local.primitive) {
        m_active = false;
        return;
    }

    // handle ainda sem VM_WRITE — o leitor reabre no proximo ciclo
    if (!memory.CanWrite()) {
        m_active = false;
        return;
    }

    const bool down = Down(fly.key);
    if (fly.toggleMode && down && !m_prevDown)
        m_toggled = !m_toggled;
    m_prevDown = down;

    const bool held = fly.toggleMode ? m_toggled : down;
    if (!held) {
        m_active = false;
        m_lastTick = GetTickCount64();
        return;
    }

    const uint64_t now = GetTickCount64();
    const float dt = m_lastTick
        ? static_cast<float>(now - m_lastTick) / 1000.f
        : static_cast<float>(settings.tickMs) / 1000.f;
    m_lastTick = now;
    m_active = true;

    if (dt <= 0.f || dt > 0.25f)
        return;

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

    if (moveForward == 0.f && moveRight == 0.f && moveUp == 0.f)
        return;

    const float step = fly.speed * dt;

    Vector3 next = local.position;
    next.x += (forward.x * moveForward + right.x * moveRight) * step;
    next.y += (forward.y * moveForward + right.y * moveRight) * step + moveUp * step;
    next.z += (forward.z * moveForward + right.z * moveRight) * step;

    if (!next.Finite())
        return;

    memory.Write(local.primitive + rbx::Primitive::Position, next);

    if (fly.zeroVelocity) {
        const Vector3 zero{};
        memory.Write(local.primitive + rbx::Primitive::AssemblyLinearVelocity, zero);
    }
}
