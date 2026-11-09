#include "aim.h"

#include <windows.h>

#include <cmath>

#include "../features/esp.h"
#include "../imgui/imgui.h"

namespace {

constexpr ImU32 kFovColor = IM_COL32(255, 255, 255, 70);
constexpr ImU32 kTargetColor = IM_COL32(255, 80, 80, 220);

bool ForegroundIsPid(DWORD pid) {
    const HWND foreground = GetForegroundWindow();
    if (!foreground)
        return false;

    DWORD owner = 0;
    GetWindowThreadProcessId(foreground, &owner);
    return owner == pid;
}

void MoveMouse(int dx, int dy) {
    if (!dx && !dy)
        return;

    INPUT input{};
    input.type = INPUT_MOUSE;
    input.mi.dx = dx;
    input.mi.dy = dy;
    input.mi.dwFlags = MOUSEEVENTF_MOVE;
    SendInput(1, &input, sizeof(INPUT));
}

// ruido pequeno sem <random>
int Jitter(float amount) {
    if (amount <= 0.f)
        return 0;

    static uint32_t seed = 0x9E3779B9u;
    seed ^= seed << 13;
    seed ^= seed >> 17;
    seed ^= seed << 5;

    const float unit = static_cast<float>(seed & 0xFFFF) / 65535.f;
    return static_cast<int>((unit * 2.f - 1.f) * amount);
}

Vector3 BonePoint(const Target& target, int bone) {
    switch (bone) {
    case cfg::kRoot:
        return target.root;
    case cfg::kChest:
        return Vector3{
            target.head.x + (target.root.x - target.head.x) * 0.35f,
            target.head.y + (target.root.y - target.head.y) * 0.35f,
            target.head.z + (target.root.z - target.head.z) * 0.35f
        };
    case cfg::kHead:
    default:
        return target.head;
    }
}

} // namespace

void AimAssist::Reset() {
    m_hasTarget = false;
    m_targetError = 0.f;
    m_lockedPlayer = 0;
    m_accumX = 0.f;
    m_accumY = 0.f;
    m_lastDown = false;
}

void AimAssist::Tick(const cfg::Settings& settings, const SceneSnapshot& scene, unsigned long pid,
                     float width, float height, bool blocked) {
    m_hasTarget = false;

    const cfg::AimSettings& aim = settings.aim;

    if (width <= 0.f || height <= 0.f || !scene.attached) {
        m_accumX = m_accumY = 0.f;
        m_lockedPlayer = 0;
        return;
    }

    const float centerX = width * 0.5f;
    const float centerY = height * 0.5f;

    // ---- tecla: segurar ou toggle ----
    // key 0 = "Nenhuma": sem bind o modulo nunca arma sozinho
    const bool down = aim.key > 0 && (GetAsyncKeyState(aim.key) & 0x8000) != 0;
    if (aim.toggleMode && down && !m_lastDown)
        m_toggled = !m_toggled;
    m_lastDown = down;

    const bool active = aim.enabled && !blocked &&
                        (aim.toggleMode ? m_toggled : down) &&
                        (!aim.requireForeground || ForegroundIsPid(static_cast<DWORD>(pid)));

    if (!active) {
        m_lockedPlayer = 0;
        m_accumX = m_accumY = 0.f;
    }

    const float lead = aim.leadMs > 0.f ? aim.leadMs / 1000.f : 0.f;

    // ---- seleção: alvo travado tem prioridade; senão o mais perto do crosshair ----
    bool found = false, lockFound = false;
    float bestDistance = aim.fovPx;
    float lockDistance = aim.fovPx;
    Vector2 bestScreen{}, lockScreen{};
    uintptr_t bestPlayer = 0, lockPlayer = 0;
    Vector3 bestVelocity{}, lockVelocity{};

    for (const Target& target : scene.targets) {
        Vector3 point = BonePoint(target, aim.bone);
        if (lead > 0.f) {
            point.x += target.velocity.x * lead;
            point.y += target.velocity.y * lead;
            point.z += target.velocity.z * lead;
        }

        Vector2 screen{};
        if (!WorldToScreen(point, screen, scene.view, width, height))
            continue;

        const float dx = screen.x - centerX;
        const float dy = screen.y - centerY;
        const float distance = std::sqrt(dx * dx + dy * dy);

        if (distance > aim.fovPx)
            continue;

        if (active && m_lockedPlayer && target.player == m_lockedPlayer && !lockFound) {
            lockFound = true;
            lockDistance = distance;
            lockScreen = screen;
            lockPlayer = target.player;
            lockVelocity = target.velocity;
        }

        if (found && distance >= bestDistance)
            continue;

        found = true;
        bestDistance = distance;
        bestScreen = screen;
        bestPlayer = target.player;
        bestVelocity = target.velocity;
    }

    // alvo travado vale mesmo se outro ficou mais perto, desde que siga no FOV
    if (lockFound) {
        found = true;
        bestDistance = lockDistance;
        bestScreen = lockScreen;
        bestPlayer = lockPlayer;
        bestVelocity = lockVelocity;
    }

    if (!found) {
        m_lockedPlayer = 0;
        m_accumX = m_accumY = 0.f;
        return;
    }

    if (active)
        m_lockedPlayer = bestPlayer;

    m_hasTarget = true;
    m_targetX = bestScreen.x;
    m_targetY = bestScreen.y;
    m_targetError = bestDistance;

    if (!active) {
        m_accumX = m_accumY = 0.f;
        return;
    }

    // ---- delta ----
    const float errorX = bestScreen.x - centerX;
    const float errorY = bestScreen.y - centerY;

    if (std::fabs(errorX) <= aim.deadzonePx && std::fabs(errorY) <= aim.deadzonePx)
        return;

    const float gain = aim.strength / (aim.smoothing < 1.f ? 1.f : aim.smoothing);

    float stepX = errorX * gain + m_accumX;
    float stepY = errorY * gain + m_accumY;

    const float magnitude = std::sqrt(stepX * stepX + stepY * stepY);
    if (magnitude > aim.maxStepPx && magnitude > 0.f) {
        const float scale = aim.maxStepPx / magnitude;
        stepX *= scale;
        stepY *= scale;
    }

    int dx = static_cast<int>(stepX);
    int dy = static_cast<int>(stepY);

    m_accumX = stepX - static_cast<float>(dx);
    m_accumY = stepY - static_cast<float>(dy);

    dx += Jitter(aim.jitterPx);
    dy += Jitter(aim.jitterPx);

    MoveMouse(dx, dy);
}

void AimAssist::DrawFov(ImDrawList* list, const cfg::Settings& settings, float width, float height) const {
    if (!list || !settings.aim.enabled || !settings.aim.drawFov)
        return;

    const ImVec2 center(width * 0.5f, height * 0.5f);
    list->AddCircle(center, settings.aim.fovPx, kFovColor, 64, 1.0f);

    if (m_hasTarget)
        list->AddCircle(ImVec2(m_targetX, m_targetY), 6.f, kTargetColor, 12, 1.4f);
}
