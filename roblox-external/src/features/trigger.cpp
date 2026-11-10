#include "trigger.h"

#include <windows.h>

#include "aim.h"

namespace {

void SendMouse(DWORD flag) {
    INPUT input{};
    input.type = INPUT_MOUSE;
    input.mi.dwFlags = flag;
    SendInput(1, &input, sizeof(INPUT));
}

bool ForegroundIsPid(DWORD pid) {
    const HWND foreground = GetForegroundWindow();
    if (!foreground)
        return false;

    DWORD owner = 0;
    GetWindowThreadProcessId(foreground, &owner);
    return owner == pid;
}

} // namespace

void Trigger::Press() {
    SendMouse(MOUSEEVENTF_LEFTDOWN);
    m_pressed = true;
}

void Trigger::Release() {
    if (!m_pressed)
        return;
    SendMouse(MOUSEEVENTF_LEFTUP);
    m_pressed = false;
}

void Trigger::Reset() {
    Release();
    m_releaseAt = 0;
    m_nextShotAt = 0;
    m_shotsLeft = 0;
    m_shots = 0;
}

void Trigger::Tick(const cfg::Settings& settings, const AimAssist& aim, bool blocked) {
    const cfg::TriggerSettings& fire = settings.fire;
    const uint64_t now = GetTickCount64();

    // solta o botao mesmo se desligar no meio do hold
    if (m_pressed && now >= m_releaseAt)
        Release();

    if (!fire.enabled || blocked) {
        Release();
        return;
    }

    if (!aim.HasTarget()) {
        m_shotsLeft = 0;
        return;
    }

    // portao: so atira com o crosshair em cima do osso
    if (aim.TargetError() > fire.maxErrorPx) {
        m_shotsLeft = 0;
        return;
    }

    // key 0 = "Nenhuma": so o modo automatico atira nesse caso
    const bool held = fire.key > 0 && (GetAsyncKeyState(fire.key) & 0x8000) != 0;

    // rajada = tiros por aperto; auto = mantem enquanto o portao estiver aberto
    if (fire.autoFire) {
        if (!m_pressed)
            m_shotsLeft = 1;
    } else if (held && !m_prevHeld) {
        m_shotsLeft = fire.burst < 1 ? 1 : fire.burst;
    } else if (!held) {
        m_shotsLeft = 0;
    }
    m_prevHeld = held;

    if (!fire.autoFire && !held)
        return;

    if (m_pressed || now < m_nextShotAt || m_shotsLeft <= 0)
        return;

    // cadencia: nunca mais rapido que minIntervalMs
    Press();
    --m_shotsLeft;
    ++m_shots;
    m_releaseAt = now + static_cast<uint64_t>(fire.holdMs < 1 ? 1 : fire.holdMs);
    m_nextShotAt = now + static_cast<uint64_t>(fire.minIntervalMs < 16 ? 16 : fire.minIntervalMs);
}
